class ScheduledJob < ApplicationJob
  class SchedulerError < StandardError
    attr_reader :original

    def initialize(message = nil, original: nil)
      @original = original
      super(message)
    end
  end

  class RetryableError < SchedulerError; end
  class TooManyRetriesError < SchedulerError; end

  queue_as :default

  def perform
    return if tasks.empty?

    tasks.each do |task|
      run_task(task)

    rescue RetryableError => e
      Rails.logger.warn("Task #{task.id} failed (attempt ##{task.attempts + 1}) with retryable error, rescheduling...")
      report_rescheduled(task, e.original)
      task.reschedule!

    rescue TooManyRetriesError => e
      report_failed(task, e.original)

    rescue StandardError => e
      report_failed(task, e)
    end
  end

  protected

  def run_task(task)
    context = build_context(task)
    vendor_module(task).call(context, task.integration, task)
  end

  def tasks
    @tasks ||= begin
                 now = DateTime.now
                 beginning_of_hour = now.beginning_of_hour
                 end_of_hour       = now.end_of_hour

                 Scheduler.where(run_on: beginning_of_hour..end_of_hour)
               end
  end

  def build_context(task)
    {
      id: nil,
      attributes: nil,
      relationships: {
        batch: {
          data: {
            id: task.batch_id
          }
        },
        facility: {
          data: {
            id: task.facility_id
          }
        }
      }
    }.with_indifferent_access
  end

  def vendor_module(task)
    "#{task.integration.vendor.camelize}Service::Batch".constantize
  end

  def report_rescheduled(task, error)
    mailer(task, error).report_reschedule_email.deliver_now
  end

  def report_failed(task, error)
    mailer(task, error).report_failure_email.deliver_now
  end

  def mailer(task, error)
    NotificationMailer.with(task: task, error: error)
  end
end
