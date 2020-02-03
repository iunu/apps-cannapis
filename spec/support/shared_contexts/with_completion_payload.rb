# frozen_string_literal: true

RSpec.shared_context('with completion payload') do
  def build_completion_payload(id, action_type:, facility_id: 1123, batch_id: 5813)
    {
      id: id,
      type: 'completions',
      relationships: {
        batch: {
          data: { id: batch_id }
        },
        facility: {
          data: { id: facility_id }
        }
      },
      attributes: {
        action_type: action_type
      }
    }
  end

  let(:facility_id) { 1123 }
  let(:batch_id) { 5813 }
  let(:completion_id) { 5589 }
  let(:headers) { { 'ACCEPT' => 'application/json' } }
  let(:action_type) { raise 'specify an action_type' }
  let(:completion_payload) { build_completion_payload(completion_id, action_type: action_type, facility_id: facility_id) }
  let!(:integration) { create(:integration, facility_id: facility_id) }
end
