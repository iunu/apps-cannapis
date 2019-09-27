class VendorJob < ApplicationJob
  queue_as :default

  def perform(ctx, integration)
    raise 'Missing arguments for job' unless ctx && integration

    vendor_module = "#{integration.vendor.camelize}Service::#{ctx[:attributes][:action_type].capitalize}".constantize
    vendor_module.new(ctx, integration).call
  end
end
