class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('NOTIFICATION_SENDER')
  layout 'mailer'
end
