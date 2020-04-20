namespace :notifier do
  task test: :environment do
    user = OpenStruct.new
    dummy_client = OpenStruct.new(current_user: user)
    account = Account.new 

    account.define_singleton_method(:client) do
      dummy_client
    end

    integration = Integration.new(account: account, vendor: 'test')
    task = Scheduler.new(integration: integration)
    task.current_action = 'test'

    error = StandardError.new('this is a test')

    NotificationMailer
      .with(task: task, error: error)
      .report_failure_email
      .deliver_now
  end
end
