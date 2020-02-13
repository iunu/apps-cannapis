# frozen_string_literal: true

namespace :artemis do
  TOKEN_PATH = 'spec/support/token_store/artemis_token.json'

  desc 'Authorize with Artemis API'
  task authorize: :environment do
    redirect = 'urn:ietf:wg:oauth:2.0:oob'
    url = oauth_client.auth_code.authorize_url(redirect_uri: redirect)

    `open "#{url}"`

    puts 'Paste the code and press enter:'
    code = STDIN.gets.strip

    token = oauth_client.auth_code.get_token(code, redirect_uri: redirect)
    account = AuthorizationService.create(token)

    File.open(TOKEN_PATH, 'w') do |file|
      file.write(token.to_hash.slice(:access_token, :expires_at, :refresh_token).to_json)
    end

    puts "Account created in #{Rails.env} DB: artemis_id: #{account.artemis_id}"
    puts "Token written to #{TOKEN_PATH}"
  end

  def oauth_client
    OAuth2::Client.new(ENV['ARTEMIS_OAUTH_APP_ID'], ENV['ARTEMIS_OAUTH_APP_SECRET'], site: ENV['ARTEMIS_BASE_URI'])
  end
end
