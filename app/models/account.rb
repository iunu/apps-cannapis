class Account < ApplicationRecord
  has_many :integrations, dependent: :destroy
  has_many :transactions, dependent: :destroy

  def client
    @client ||= ArtemisApi::Client.new(
      access_token: access_token,
      refresh_token: refresh_token,
      expires_at: access_token_expires_in,
      on_token_refreshed: Proc.new do |client, new_token|
        update(access_token: new_token.token,
          refresh_token: new_token.refresh_token,
          access_token_expires_in: new_token.expires_at.to_i,
          access_token_created_at: Time.zone.now)
      end,
      on_token_failed: Proc.new do |client, bad_token|
        sleep 5
        self.reload
        client.set_oauth_token_from_parts(
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: access_token_expires_in
        )
      end
    )
  end
end
