class ScheduledJob < ApplicationJob
  queue_as :default

  def perform
    tasks = get_tasks
    return if tasks.empty?

    TaskRunner.run(*tasks)
  end

  protected

  def get_tasks
    now = DateTime.now
    beginning_of_hour = now.beginning_of_hour
    end_of_hour       = now.end_of_hour

    Scheduler.where(run_on: beginning_of_hour..end_of_hour)
  end
end
