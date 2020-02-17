class ScheduledJob < ApplicationJob
  queue_as :default

  def perform
    now = DateTime.now
    beginning_of_hour = now.beginning_of_hour
    end_of_hour       = now.end_of_hour

    tasks = Scheduler.where(run_on: beginning_of_hour..end_of_hour)

    return unless tasks.size.positive?

    tasks.each do |task|
      vendor_module = "#{task.integration.vendor.camelize}Service::Batch".constantize
      ctx = {
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
      vendor_module.call(ctx, task.integration, task)
    end
  end
end
