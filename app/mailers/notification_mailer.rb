class NotificationMailer < ApplicationMailer
  def report_failure_email
    @integration = params[:integration]
    @account = @integration.account.client.current_user
    @error = params[:error]
    @action = params[:action]

    mail(
      to: recipient,
      subject: "[Artemis -> #{@integration.vendor_name}] Error processing #{@action} for user #{@account.id}"
    )
  end

  def recipient
    ENV.fetch('NOTIFICATION_RECIPIENT')
  end
end
