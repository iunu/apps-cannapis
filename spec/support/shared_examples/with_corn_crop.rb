RSpec.shared_examples 'with corn crop' do
  let(:transaction_type) { :some_tx_type }
  let(:transaction) { stub_model Transaction, type: transaction_type, success: false }
  let(:batch) { double(:batch, crop: 'Corn', zone: zone) }
  let(:zone) { double(:zone, attributes: { name: nil }) }

  before do
    allow_any_instance_of(described_class)
      .to receive(:get_transaction)
      .and_return transaction

    allow_any_instance_of(described_class)
      .to receive(:get_batch)
      .and_return batch
  end

  it { is_expected.to be_nil }
end
