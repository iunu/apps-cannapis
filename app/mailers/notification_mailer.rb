class NotificationMailer < ApplicationMailer
  def setup
    @task = params[:task]
    @integration = @task.integration
    @account = @integration.account.client.current_user
    @error = params[:error]
    @action = @task.action_name
  end

  def report_failure_email
    setup

    mail(
      to: recipient,
      subject: "[Artemis -> #{@integration.vendor_name}] Task failed: #{@action} for user #{@account.id}"
    )
  end

  def report_reschedule_email
    setup

    @attempt = @task.attempt

    mail(
      to: recipient,
      subject: "[Artemis -> #{@integration.vendor_name}] Task rescheduled (attempt #{@attempt}): #{@action} for user #{@account.id}"
    )
  end

  def recipient
    ENV.fetch('NOTIFICATION_RECIPIENT')
  end
end
