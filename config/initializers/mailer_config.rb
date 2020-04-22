if ENV['SEND_MAILS']
  ActionMailer::Base.smtp_settings = {
    :port           => ENV['SMTP_PORT'],
    :address        => ENV['SMTP_ADDRESS'],
    :user_name      => ENV['SMTP_USER_NAME'],
    :password       => ENV['SMTP_PASSWORD'],
    :domain         => 'ar-apps-metrc-staging.herokuapp.com',
    :authentication => :login,
    enable_starttls_auto: true
  }
  ActionMailer::Base.delivery_method = :smtp

elsif ENV['MAILTRAP_API_TOKEN'].present?

  require 'rest-client'
  require 'json'

  response = RestClient::Resource.new("https://mailtrap.io/api/v1/inboxes.json?api_token=#{ENV['MAILTRAP_API_TOKEN']}").get

  first_inbox = JSON.parse(response)[0]

  ActionMailer::Base.delivery_method = :smtp
  ActionMailer::Base.smtp_settings = {
    :user_name => first_inbox['username'],
    :password => first_inbox['password'],
    :address => first_inbox['domain'],
    :domain => first_inbox['domain'],
    :port => first_inbox['smtp_ports'][0],
    :authentication => :plain
  }
end
