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

      if ref_time.hour >= integration.eod.hour
        execute_job(integration)
        next
      end

      if integration.vendor_module.run_now?(@ctx, integration)
        schedule_job(integration, ref_time)
        flush_job_queue(integration, ref_time)
        next
      end

      schedule_job(integration, ref_time)
      next
    end
  end

  # Executes any pending jobs belonging to the *same* batch and facility
  #
  # If a job requires processing of *related*, batches that must happen
  # in the handler (see Metrc::Package::Start)
  def flush_job_queue(integration, ref_time)
    tasks = existing_jobs(integration, ref_time)
    TaskRunner.run(*tasks)
  end

  def execute_job(integration)
    VendorJob.perform_later(@ctx, integration)
  end

  def schedule_job(integration, ref_time)
    exists = existing_jobs(integration, ref_time)

    return if exists.size.positive?

    later = ref_time.at_beginning_of_day + integration.eod.hour.hours

    Scheduler.create(
      integration: integration,
      facility_id: facility_id,
      batch_id: batch_id,
      run_on: later.utc
    )
  end

  def existing_jobs(integration, ref_time)
    Scheduler.where(
      integration: integration,
      facility_id: facility_id,
      batch_id: batch_id,
      run_on: ref_time.at_beginning_of_day..ref_time.at_end_of_day
    )
  end

  def facility_id
    @facility_id ||= @ctx.dig('relationships', 'facility', 'data', 'id')
  end

  def batch_id
    @batch_id ||= @ctx.dig('relationships', 'batch', 'data', 'id')
  end
end
