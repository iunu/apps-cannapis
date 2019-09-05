require 'rails_helper'

RSpec.describe MetrcService do
  describe.skip '#start_batch' do
    let(:seed) do
      account = Account.create(name: 'Jon Snow',
                               artemis_id: 123,
                               access_token: 'abc-123',
                               refresh_token: 'abc-123',
                               access_token_expires_in: Time.current + 1.day,
                               access_token_created_at: Time.current)
      integration = Integration.create(account_id: account.id,
                                       facility_id: 456,
                                       state: :ca,
                                       vendor: :metrc,
                                       vendor_id: '123-ABC',
                                       key: 'ABC-123',
                                       secret: 'DEF-456')
      ctx = ActionController::Parameters.new(relationships: {
                                              facility: {
                                                data: {
                                                  id: 456
                                                }
                                              }
                                            })
      ctx.permit!
      described_class.new ctx, integration
    end

    it 'validates that the batch crop is cannabis' do
    end
  end
end
