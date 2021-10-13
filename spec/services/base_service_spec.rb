require 'rails_helper'

RSpec.describe BaseService do
  let(:ctx) do
    {
      id: 3000,
      relationships: {
        batch: { data: { id: 2002 } },
        facility: { data: { id: 1568 } }
      },
      completion_id: 1001
    }.with_indifferent_access
  end

  let(:account) { create(:account) }
  let(:integration) { create(:integration, account: account) }
  let(:task) { create(:task, integration: integration) }
  let(:instance) { described_class::Lookup.new(ctx, integration) }

  context 'when completion is removed' do
    let(:completion) { double(:completion, id: 2, status: 'removed') }

    before do
      allow(instance)
        .to receive(:completion)
        .and_return(completion)
    end

    subject { instance.send(:perform_action) }

    it 'calls remove_transaction' do
      expect_any_instance_of(MetrcService::Lookup).to receive(:remove_transaction)
      expect { subject }.not_to raise_error
    end
  end
end
