require 'rails_helper'

RSpec.describe MetrcService::Move do
  let(:account) { create(:account) }
  let(:integration) { create(:integration, account: account) }
  let(:ctx) do
    {
      id: 3000,
      relationships: {
        batch: {
          data: {
            id: 2002
          }
        },
        facility: {
          data: {
            id: 1568
          }
        }
      },
      attributes: {
        options: {
          tracking_barcode: '1A4FF01000000220000010',
          note_content: 'And the only prescription is moar cow bell'
        }
      },
      completion_id: 1001
    }.with_indifferent_access
  end

  context '#call' do
    let(:ctx) do
      {
        id: 3000,
        relationships: {
          batch: {
            data: {
              id: 2002
            }
          },
          facility: {
            data: {
              id: 1568
            }
          }
        },
        attributes: {},
        completion_id: 1001
      }.with_indifferent_access
    end
    subject { described_class.new(ctx, integration) }


    describe 'on an old successful transaction' do
      let(:transaction) { create(:transaction, :successful, :move, account: account, integration: integration) }
      let(:zone) { double(:zone, attributes: { name: nil }) }
      let(:batch) { double(:batch, crop: 'Cannabis', zone: zone) }

      it 'returns the transaction' do
        allow(subject).to receive(:get_transaction).and_return transaction
        allow(subject).to receive(:get_batch).and_return batch
        expect(subject.call).to eq transaction
      end
    end

    describe 'with corn crop' do
      let(:transaction) { create(:transaction, :unsuccessful, :move, account: account, integration: integration) }
      let(:zone) { double(:zone, attributes: { name: nil }) }
      let(:batch) { double(:batch, crop: 'Corn', zone: zone) }

      it 'returns nil' do
        allow(subject).to receive(:get_transaction).and_return transaction
        allow(subject).to receive(:get_batch).and_return batch
        expect(subject.call).to be_nil
      end
    end
  end
end
