class VendorJob < ApplicationJob
  queue_as :default

  def perform(ctx, integration)
    raise 'Missing arguments for job' unless ctx && integration

    integration.vendor_module.perform_action(ctx, integration)
  end
end
