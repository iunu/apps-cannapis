# frozen_string_literal: true

class TaskRunner
  def self.run(*tasks)
    tasks.each do |task|
      new(task).run
    end
  end

  def initialize(task)
    @task = task
  end

  def run
    vendor_module.call(build_context, @task.integration, @task)
  rescue Cannapi::RetryableError => e
    Rails.logger.warn("Task #{@task.id} failed (attempt ##{@task.attempts + 1}) with retryable error, rescheduling...")
    report_rescheduled(e.original)
    @task.reschedule!
  rescue Cannapi::TooManyRetriesError => e
    report_failed(e.original)
  rescue StandardError => e
    report_failed(e)
  end

  def build_context
    {
      id: nil,
      attributes: nil,
      relationships: {
        batch: { data: { id: @task.batch_id } },
        facility: { data: { id: @task.facility_id } }
      }
    }.with_indifferent_access
  end

  def vendor_module
    "#{@task.integration.vendor.camelize}Service::Batch".constantize
  end

  def report_rescheduled(error)
    mailer(error).report_reschedule_email.deliver_now
  end

  def report_failed(error)
    mailer(error).report_failure_email.deliver_now
  end

  def mailer(error)
    NotificationMailer.with(task: @task, error: error)
  end
end
