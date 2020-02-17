require 'rails_helper'

RSpec.describe('completion: move', type: :request) do
  include_context 'with completion payload' do
    let(:action_type) { 'move' }
  end

  xcontext 'POST /v1/webhook', 'pending changes for "resources"' do
    let(:call) { post('/v1/webhook', params: { data: completion_payload }, headers: headers) }
    subject { response }

    context 'successfully' do
      before do
        expect(Scheduler)
          .to receive(:create) do |**args|
            expect(args[:integration].id).to eq(integration.id)
            expect(args[:facility_id].to_i).to eq(facility_id)
            expect(args[:batch_id].to_i).to eq(batch_id)
          end

        call
      end
      it { is_expected.to be_no_content }
    end
  end
end
