class VendorJob < ApplicationJob
  queue_as :default

  def perform(ctx, integration)
    raise 'Missing arguments for job' unless ctx && integration

    vendor_module = "#{integration.vendor.camelize}Service"
    # TODO: Kill me before I breed
    klass = case ctx[:attributes][:action_type]
            when 'start' then 'Batch'
            when 'move', 'discard' then 'Batch'
              # if ctx[:attributes][:options] && ctx[:attributes][:options][:prefix]
              #   'Plants'
              # else
              #   'Batch'
              # end
            when 'harvest' then 'Plants'
            else 'Unsupported'
            end

    vendor_object = "#{vendor_module}::#{klass}".constantize.new(ctx, integration)
    vendor_object.send ctx[:attributes][:action_type]
  end
end
