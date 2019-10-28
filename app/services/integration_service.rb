class IntegrationService < ApplicationService
  def initialize(params)
    @ctx = params.to_h
  end

  def call
    # Look up for active integrations
    integrations = Integration.active.where(facility_id: @ctx['relationships']['facility']['data']['id'])

    raise 'No integrations for this facility' unless integrations.size.positive?

    integrations.each do |integration|
      VendorJob.perform_later(@ctx, integration)
    end
  end
end
