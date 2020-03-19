# Preview all emails at http://localhost:3000/rails/mailers/notification_mailer
class NotificationMailerPreview < ActionMailer::Preview
  def report_reschedule_email
    task = FactoryBot.build(:task, attempts: 2)
    client = task.integration.account.client

    def client.current_user
      OpenStruct.new(id: 12345, full_name: 'John Smith', email: 'js@smithcorp.com')
    end

    error = StandardError.new('Something went wrong while doing something important')

    NotificationMailer
      .with(task: task, error: error)
      .report_reschedule_email
  end

  def report_failure_email
    task = FactoryBot.build(:task)
    client = task.integration.account.client

    def client.current_user
      OpenStruct.new(id: 12345, full_name: 'John Smith', email: 'js@smithcorp.com')
    end

    error = StandardError.new('Something went wrong while doing something important')

    NotificationMailer
      .with(task: task, error: error)
      .report_failure_email
  end
end
