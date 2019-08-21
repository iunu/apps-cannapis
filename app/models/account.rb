class Account < ApplicationRecord
  def refresh_token_if_needed # rubocop:disable Metrics/AbcSize
    return unless client.oauth_token.expired?

    new_token = client.refresh
    expires_in = (new_token.to_hash[:expires_at].to_i - new_token.to_hash['created_at'].to_i)
    update(access_token: new_token.to_hash[:access_token],
           refresh_token: new_token.to_hash[:refresh_token],
           access_token_expires_in: expires_in,
           access_token_created_at: Time.zone.now)
  end

  def client
    ArtemisApi::Client.new(access_token, refresh_token, access_token_expires_in, access_token_created_at)
  end
end
