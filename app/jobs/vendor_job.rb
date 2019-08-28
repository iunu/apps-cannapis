class VendorJob < ApplicationJob
  queue_as :default

  def perform(ctx, integration)
    vendor_service = "#{integration.vendor.camelize}Service".constantize.new(ctx, integration)
    vendor_service.send "#{ctx[:attributes][:action_type]}_batch"
  end
end
