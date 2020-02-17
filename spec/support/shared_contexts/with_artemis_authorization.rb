# frozen_string_literal: true

RSpec.shared_context 'with artemis authorization' do
  def load_token
    JSON.parse(File.read('spec/support/token_store/artemis_token.json')).symbolize_keys
  rescue Errno::ENOENT
    raise 'Token file not found. You must run "rake artemis:authorize" to generate a token'
  end

  let(:token) { load_token }

  let(:artemis_id) { 1673 }
  let!(:account) do
    create(
      :account_with_no_tokens,
      artemis_id: artemis_id,
      **token.slice(:access_token, :refresh_token),
      access_token_expires_in: token[:expires_at],
      access_token_created_at: Time.now.to_i
    )
  end
end
