require 'rails_helper'

RSpec.describe Account, type: :model do
  subject { create(:account) }

  it { should have_many(:integrations) }
  it { should have_many(:transactions) }

  describe '#client' do
    subject { create(:account, :no_tokens) }

    it 'raises an exception when no tokens are passed' do
      expect { subject.client }.to raise_exception(ArgumentError)
    end
  end

  describe '#refresh_token_if_needed' do
    context 'with an unexpired token' do
      it 'raises an exception when no tokens are passed' do
        expect(subject.refresh_token_if_needed).to be_nil
      end
    end

    context 'with an expired token' do
      subject { create(:account, :expired_token) }
      let(:expected_response) do
        {
          access_token: Faker::Alphanumeric.unique.alphanumeric(number: 290),
          token_type: 'Bearer',
          expires_in: 7200,
          refresh_token: Faker::Alphanumeric.unique.alphanumeric(number: 45),
          scope: 'default',
          created_at: Time.now.utc
        }
      end

      before do
        stub_request(:post, "#{ENV['ARTEMIS_BASE_URI']}/oauth/token")
          .with(
            body: {
              'client_id': ENV['ARTEMIS_OAUTH_APP_ID'],
              'client_secret': ENV['ARTEMIS_OAUTH_APP_SECRET'],
              'grant_type': 'refresh_token',
              'refresh_token': subject.refresh_token
            },
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded'
            }
          )
          .to_return(
            status: 200,
            headers: {
              'Content-Type': 'application/json; charset=utf-8'
            },
            body: expected_response.to_json
          )
      end

      it 'it refreshes the token' do
        expect(subject.refresh_token_if_needed).to eq(true)
        expect(subject.access_token).to eq(expected_response[:access_token])
        expect(subject.refresh_token).to eq(expected_response[:refresh_token])
      end
    end
  end
end
