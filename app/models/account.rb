class Account < ApplicationRecord
  has_many :integrations, dependent: :destroy
  has_many :transactions, dependent: :destroy

  def refresh_token_if_needed
    return unless client&.oauth_token&.expired?

    new_token = client.refresh
    update(access_token: new_token.token,
           refresh_token: new_token.refresh_token,
           access_token_expires_in: new_token.expires_at.to_i,
           access_token_created_at: Time.zone.now)
  end

  def client
    @client ||= ArtemisApi::Client.new(access_token: access_token,
                                       refresh_token: refresh_token,
                                       expires_at: access_token_expires_in)
  end
end
