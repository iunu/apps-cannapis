class IntegrationService < ApplicationService
  def initialize(params)
    @ctx = params.to_h
  end

  def call
    facility_id = @ctx.dig('relationships', 'facility', 'data', 'id')
    # Look up for active integrations
    integrations = Integration.active.where(facility_id: facility_id)

    raise 'No integrations for this facility' unless integrations.size.positive?

    integrations.each do |integration|
      now = Time.now.getlocal(integration.timezone)

      if now.hour >= integration.eod.hour
        VendorJob.perform_later(@ctx, integration)
      else
        batch_id = @ctx.dig('relationships', 'batch', 'data', 'id')
        later = now.at_beginning_of_day + integration.eod.hour.hours

        exists = Scheduler.where(facility_id: facility_id, batch_id: batch_id, run_on: now.at_beginning_of_day..now.at_end_of_day)

        next if exists.size.positive?

        Scheduler.create(integration: integration,
                         facility_id: facility_id,
                         batch_id: batch_id,
                         run_on: later.utc)
      end
    end
  end
end
