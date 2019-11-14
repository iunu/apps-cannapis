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

  context '#next_step' do
    subject { described_class.new(ctx, integration) }

    describe 'for no zones' do
      it 'returns the default move step' do
        next_step = subject.send :next_step
        expect(next_step).to be :change_growth_phase
      end
    end

    describe 'for a previous clone zone and a new vegetative zone' do
      it 'returns the default move step' do
        next_step = subject.send :next_step, 'clone', 'vegetative'
        expect(next_step).to be :change_growth_phase
      end
    end

    describe 'for a previous clone zone and a new clone zone' do
      it 'returns the move_plant_batches step' do
        next_step = subject.send :next_step, 'clone', 'clone'
        expect(next_step).to be :move_plant_batches
      end
    end

    describe 'for a previous vegetative zone and a new vegetative zone' do
      it 'returns the move_plants step' do
        next_step = subject.send :next_step, 'vegetative', 'vegetative'
        expect(next_step).to be :move_plants
      end
    end

    describe 'for a previous flowering zone and a new flowering zone' do
      it 'returns the move_plants step' do
        next_step = subject.send :next_step, 'flowering', 'flowering'
        expect(next_step).to be :move_plants
      end
    end

    describe 'for a previous vegetative zone and a new flowering zone' do
      it 'returns the change_growth_phases step' do
        next_step = subject.send :next_step, 'vegetative', 'flowering'
        expect(next_step).to be :change_growth_phases
      end
    end

    describe 'for an unkonwn zone and a new unkonwn zone' do
      it 'returns the default move step' do
        next_step = subject.send :next_step, 'drying', 'dispatch'
        expect(next_step).to be :change_growth_phase
      end
    end
  end

  describe '#normalize_growth_phase' do
    subject { described_class.new(ctx, integration) }

    it 'returns clone when the zone is not defined' do
      growth_phase = subject.send :normalize_growth_phase
      expect(growth_phase).to eq 'clone'
    end

    it 'returns vegetative when the zone is vegetative' do
      growth_phase = subject.send :normalize_growth_phase, 'vegetative'
      expect(growth_phase).to eq 'vegetative'
    end

    it 'returns flowering when the zone is flowering' do
      growth_phase = subject.send :normalize_growth_phase, 'flowering'
      expect(growth_phase).to eq 'flowering'
    end

    it 'returns clone as the default growth phase' do
      growth_phase = subject.send :normalize_growth_phase, 'growing'
      expect(growth_phase).to eq 'clone'
    end
  end
end
