class AuthorizationService < ApplicationService
  def self.create(token) # rubocop:disable Metrics/AbcSize
    @token     = token
    token_hash = @token.to_hash
    expires_in = (token_hash[:expires_at].to_i - token_hash[:created_at].to_i)
    user       = fetch_user

    account = Account.find_or_create_by(artemis_id: user[:id])
    account.update(name: user[:full_name],
                   access_token: token_hash[:access_token],
                   refresh_token: token_hash[:refresh_token],
                   access_token_expires_in: expires_in,
                   access_token_created_at: Time.zone.now)

    account
  end

  private_class_method def self.fetch_user
    response = @token.get("#{ENV['ARTEMIS_BASE_URI']}/api/v3/user")
    JSON.parse(response.body)['data']['attributes'].with_indifferent_access
  end
end
