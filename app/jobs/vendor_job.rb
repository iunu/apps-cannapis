class VendorJob < ApplicationJob
  queue_as :default

  def perform(ctx, integration)
    raise 'Missing arguments for job' unless ctx && integration

    @ctx = ctx
    @integration = integration

    batch_handler
      .module_for_completion(completion)
      .call(@ctx, @integration)
  end

  def batch
    @batch ||= begin
                 facility_id = @ctx.dig('relationships', 'facility', 'data', 'id')
                 batch_id = @ctx.dig('relationships', 'batch', 'data', 'id')

                 @integration
                   .account
                   .client
                   .facility(facility_id)
                   .batch(batch_id, include: 'zone,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone')
               end
  end

  def completion
    @completion ||= batch.completion(@ctx['id'])
  end

  def batch_handler
    klass = "#{@integration.vendor.camelize}Service::Batch".constantize
    klass.new(@ctx, @integration)
  end
end
