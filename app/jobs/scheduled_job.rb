class ScheduledJob < ApplicationJob
  queue_as :default

  def perform
    tasks = find_tasks
    return if tasks.empty?

    TaskRunner.run(*tasks)
  rescue Cannapi::TaskError => e
    Rails.logger.error("Scheduled job failed: #{e.message}")
  end

  protected

  def find_tasks
    now = DateTime.now
    beginning_of_hour = now.beginning_of_hour
    end_of_hour       = now.end_of_hour

    Scheduler.where(run_on: beginning_of_hour..end_of_hour, attempts: 0..2)
  end
end
