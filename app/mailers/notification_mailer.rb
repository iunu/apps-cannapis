class NotificationMailer < ApplicationMailer
  def setup
    @task = params[:task]
    @integration = @task.integration
    @account = @integration.account.client.current_user
    @error = params[:error]
  end

  def report_failure_email
    setup

    mail(
      to: recipient,
      subject: "[Artemis -> #{@integration.vendor_name}] Failed for user #{@account.id}"
    )
  end

  def report_reschedule_email
    setup

    @attempts = @task.attempts

    mail(
      to: recipient,
      subject: "[Artemis -> #{@integration.vendor_name}] Task rescheduled (attempts #{@attempts}) for user #{@account.id}"
    )
  end

  def recipient
    ENV.fetch('NOTIFICATION_RECIPIENT')
  end
end
