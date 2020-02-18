class ScheduledJob < ApplicationJob
  class RetryableError < StandardError; end
  class TooManyRetriesError < StandardError; end

  queue_as :default

  def perform
    return if tasks.empty?

    tasks.each do |task|
      run_task(task)

    rescue RetryableError
      Rails.logger.warn("Task #{task.id} failed (attempt ##{task.attempts + 1}) with retryable error, rescheduling...")
      task.reschedule!

    rescue TooManyRetriesError
      report_error
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

  def report_error(task)
    # trigger mailer
  end
end
