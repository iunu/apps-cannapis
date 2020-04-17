# frozen_string_literal: true

class TaskRunner
  def self.run(*tasks)
    runners = tasks.map do |task|
      new(task).tap(&:run)
    end

    raise Cannapi::TaskError, 'one or more tasks failed; notifications sent' \
      unless runners.all?(&:success?)

    runners.map(&:result)
  end

  attr_accessor :result
  delegate :success?, to: :result, allow_nil: true

  def initialize(task)
    @task = task
  end

  def run
    # Refresh OAuth token
    account = @task.integration.account
    account.refresh_token_if_needed

    @result = vendor_module.call(build_context, @task.integration, nil, @task)
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
      attributes: {},
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
