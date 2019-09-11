class VendorJob < ApplicationJob
  queue_as :default

  def perform(ctx, integration)
    raise 'Missing arguments for job' unless ctx && integration

    vendor_module = "#{integration.vendor.camelize}Service"
    klass = case ctx[:attributes][:action_type]
            when 'start', 'move', 'discard' then 'Batch'
            when 'move_plants', 'destroy', 'harvest', 'manicure', 'secondary_harvest' then 'Plants'
            else 'Unsupported'
            end

    vendor_object = "#{vendor_module}::#{klass}".constantize.new(ctx, integration)
    vendor_object.send ctx[:attributes][:action_type]
  end
end
