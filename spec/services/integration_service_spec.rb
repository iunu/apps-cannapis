require 'rails_helper'

RSpec.describe IntegrationService, sidekiq: :fake do
  describe 'when there is no integration' do
    let(:subject) do
      params = ActionController::Parameters.new(relationships: {
                                                  facility: {
                                                    data: {
                                                      id: 123
                                                    }
                                                  }
                                                })
      params.permit!
      described_class.new(params)
    end

    it 'raises an exception' do
      expect {
        subject.call
      }.to raise_error 'No integrations for this facility'
    end
  end

  describe 'when the integration is not active' do
    let(:subject) do
      account = Account.create(name: 'Jon Snow',
                               artemis_id: 123,
                               access_token: 'abc-123',
                               refresh_token: 'abc-123',
                               access_token_expires_in: Time.current + 1.day,
                               access_token_created_at: Time.current)
      Integration.create(account_id: account.id,
                         facility_id: 456,
                         state: :ca,
                         vendor: :metrc,
                         vendor_id: '123-ABC',
                         key: 'ABC-123',
                         secret: 'DEF-456',
                         deleted_at: Time.current)
      params = ActionController::Parameters.new(relationships: {
                                                  facility: {
                                                    data: {
                                                      id: 456
                                                    }
                                                  }
                                                })
      params.permit!
      described_class.new(params)
    end

    it 'raises an exception' do
      expect {
        subject.call
      }.to raise_error 'No integrations for this facility'
    end
  end

  describe 'when the integration is active' do
    let(:subject) do
      account = Account.create(name: 'Jon Snow',
                               artemis_id: 123,
                               access_token: 'abc-123',
                               refresh_token: 'abc-123',
                               access_token_expires_in: Time.current + 1.day,
                               access_token_created_at: Time.current)
      Integration.create(account_id: account.id,
                         facility_id: 456,
                         state: :ca,
                         vendor: :metrc,
                         vendor_id: '123-ABC',
                         key: 'ABC-123',
                         secret: 'DEF-456')
      params = ActionController::Parameters.new(relationships: {
                                                  facility: {
                                                    data: {
                                                      id: 456
                                                    }
                                                  }
                                                })
      params.permit!
      described_class.new(params)
    end

    it 'enques the job and does not raises an exception' do
      expect {
        subject.call
      }.not_to raise_error
    end
  end
end
