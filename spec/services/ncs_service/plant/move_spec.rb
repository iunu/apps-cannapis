require 'rails_helper'

RSpec.describe NcsService::Plant::Move do
  let(:account) { create(:account) }
  let(:integration) { create(:integration, :ncs_vendor, account: account) }
  let(:ctx) do
    {
      id: 3000,
      relationships: {
        batch: { data: { id: 2002 } },
        facility: { data: { id: 1568 } }
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

  describe '#call' do
    subject { described_class.call(ctx, integration) }

    let(:ctx) do
      {
        id: 3000,
        relationships: {
          batch: { data: { id: 2002 } },
          facility: { data: { id: 1568 } }
        },
        attributes: {},
        completion_id: 1001
      }.with_indifferent_access
    end

    before do
      expect_any_instance_of(described_class)
        .to receive(:get_transaction)
        .and_return(transaction)

      expect_any_instance_of(described_class)
        .to receive(:get_batch)
        .and_return(batch)
    end

    context 'with an old successful transaction' do
      let(:transaction) { create(:transaction, :successful, :move, account: account, integration: integration) }
      let(:zone) { double(:zone, attributes: { name: nil }) }
      let(:batch) { double(:batch, crop: 'Cannabis', zone: zone) }

      it { is_expected.to eq(transaction) }
    end

    context 'with corn crop' do
      include_examples 'with corn crop'
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
        expect(next_step).to be :change_growth_phase
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
      it 'returns the change_plant_growth_phases step' do
        next_step = subject.send :next_step, 'vegetative', 'flowering'
        expect(next_step).to be :change_growth_phase
      end
    end

    describe 'for an unkonwn zone and a new unkonwn zone' do
      it 'returns the default move step' do
        next_step = subject.send :next_step, 'drying', 'dispatch'
        expect(next_step).to be :change_growth_phase
      end
    end
  end

  describe '#normalized_growth_phase' do
    let(:sub_stage) { double(:sub_stage, name: 'clone') }
    let(:zone) { double(:zone, sub_stage: sub_stage)  }
    let(:batch) { double(:batch, zone: zone) }
    let(:service) { described_class.new(ctx, integration) }
    let(:params) { [] }

    subject { service.send(:normalized_growth_phase, *params) }

    context 'with default value' do
      before do
        expect(service)
          .to receive(:batch)
          .and_return(batch)
      end

      it { is_expected.to eq('Clone') }
    end

    context 'when sub_stage is vegetative' do
      let(:params) { ['vegetative'] }
      it { is_expected.to eq('Vegetative') }
    end

    context 'when sub_stage is flowering' do
      let(:params) { ['flowering'] }
      it { is_expected.to eq('Flowering') }
    end

    context 'when sub_stage is something unexpected' do
      let(:params) { ['growing'] }
      it { is_expected.to eq('Clone') }
    end
  end
end
