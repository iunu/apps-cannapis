class IntegrationService < ApplicationService
  def initialize(params)
    @ctx = params.to_h
  end

  def call
    # Look up for active integrations
    integrations = Integration.active.where(facility_id: facility_id)
    raise 'No integrations for this facility' unless integrations.size.positive?

    integrations.each do |integration|
      ref_time = Time.now.getlocal(integration.timezone)

      if integration.vendor_module.run_now?(@ctx, integration, ref_time)
        execute_job(integration)
      else
        schedule_job(integration, ref_time)
      end
    end
  end

  def execute_job(integration)
    VendorJob.perform_later(@ctx, integration)
  end

  def schedule_job(integration, ref_time)
    exists = Scheduler.where(
      facility_id: facility_id,
      batch_id: batch_id,
      run_on: ref_time.at_beginning_of_day..ref_time.at_end_of_day
    )

    return if exists.size.positive?

    later = ref_time.at_beginning_of_day + integration.eod.hour.hours

    Scheduler.create(
      integration: integration,
      facility_id: facility_id,
      batch_id: batch_id,
      run_on: later.utc
    )
  end

  def facility_id
    @facility_id ||= @ctx.dig('relationships', 'facility', 'data', 'id')
  end

  def batch_id
    @batch_id ||= @ctx.dig('relationships', 'batch', 'data', 'id')
  end
end
