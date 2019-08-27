require 'ostruct'

class IntegrationService < ApplicationService
  attr_reader :ctx

  def initialize(params)
    @ctx = JSON.parse(params.to_json, object_class: OpenStruct)
  end

  def call
    # Look up for active integrations
    integrations = Integration.active.where(facility_id: @ctx.relationships.facility.data.id)

    return unless integrations.size.positive?

    integrations.each do |integration|
      vendor_job = "#{integration.vendor.camelize}Job".constantize
      vendor_job.send "perform_#{@ctx[:attributes][:action_type]}_batch", @ctx, integration
    end
  end
end
