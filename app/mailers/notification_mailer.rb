class NotificationMailer < ApplicationMailer
  def setup
    @integration = params[:integration]
    @account = @integration.account.client.current_user
    @error = params[:error]
    @action = params[:action]
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

    @attempt = params[:attempt]

    mail(
      to: recipient,
      subject: "[Artemis -> #{@integration.vendor_name}] Task rescheduled (attempt #{@attempt}): #{@action} for user #{@account.id}"
    )
  end

  def recipient
    ENV.fetch('NOTIFICATION_RECIPIENT')
  end
end
