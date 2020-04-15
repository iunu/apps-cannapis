require 'rails_helper'

RSpec.describe MetrcService::Plant::Move do
  let(:account) { create(:account) }
  let(:integration) { create(:integration, account: account, state: 'md') }
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

  context '#call' do
    include_context 'with synced data' do
      let(:facility_id) { 2 }
      let(:batch_id) { 81 }
    end

    let(:transaction) { create(:transaction, :unsuccessful, :move, account: account, integration: integration) }

    subject { described_class.call(ctx, integration) }

    let(:ctx) do
      {
        id: 3000,
        relationships: {
          batch: { data: { id: batch_id } },
          facility: { data: { id: facility_id } }
        },
        attributes: {
          start_time: '2020-04-15'
        },
        completion_id: 1001
      }.with_indifferent_access
    end

    before do
      expect_any_instance_of(described_class)
        .to receive(:get_transaction)
        .and_return(transaction)
    end

    describe 'on an old successful transaction' do
      before do
        expect_any_instance_of(described_class)
          .to receive(:get_batch)
          .and_return(batch)
      end
      let(:transaction) { create(:transaction, :successful, :move, account: account, integration: integration) }
      let(:zone) { double(:zone, attributes: { name: nil }) }
      let(:batch) { double(:batch, crop: 'Cannabis', zone: zone) }

      it { is_expected.to eq(transaction) }
    end

    describe 'with corn crop' do
      include_examples 'with corn crop'
    end

    describe 'moving to vegetative substage' do
      let(:seeding_unit_id) { 7 }
      before do
        stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

        stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}/batches/#{batch_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}/batches/#{batch_id}/items?filter[seeding_unit_id]=#{seeding_unit_id}&include=barcodes,seeding_unit")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/items"))

        stub_request(:post, 'https://sandbox-api-md.metrc.com/plantbatches/v1/changegrowthphase?licenseNumber=LIC-0001')
          .with(body: expected_payload.to_json)
          .to_return(status: 200)
      end

      let(:expected_payload) do
        [{
          Name: 'abcdef123',
          Count: 2,
          StartingTag: 'abcdef124',
          GrowthPhase: 'Vegetative',
          NewLocation: 'Mother Room',
          GrowthDate: '2020-04-15',
          PatientLicenseNumber: nil
        }]
      end

      it { is_expected.to be_success }
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
      it 'returns the change_plant_growth_phases step' do
        next_step = subject.send :next_step, 'vegetative', 'flowering'
        expect(next_step).to be :change_plant_growth_phases
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
