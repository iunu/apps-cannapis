# frozen_string_literal: true

RSpec.shared_context 'with metrc integration' do
  let!(:integration) do
    create(:integration_with_metrc_creds, facility_id: facility_id, account: account)
  end
end
