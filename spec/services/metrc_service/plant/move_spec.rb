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
          start_time: '2020-04-15',
          options: {
            quantity: '2'
          }
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
      let(:sub_stage) { double(:sub_stage, name: 'clone', attributes: { 'name': 'clone' }) }
      let(:zone) { double(:zone, sub_stage: sub_stage)  }
      let(:batch) { double(:batch, crop: 'Cannabis', zone: zone) }

      it { is_expected.to eq(transaction) }
    end

    describe 'with corn crop' do
      include_examples 'with corn crop' do
        let(:sub_stage) { double(:sub_stage, name: 'clone', attributes: { 'name': 'clone' }) }
        let(:zone) { double(:zone, crop: 'Corn', sub_stage: sub_stage)  }
      end
    end

    describe 'moving to vegetative substage' do
      let(:seeding_unit_id) { 7 }
      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}/items?filter[seeding_unit_id]=#{seeding_unit_id}&include=barcodes,seeding_unit")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/items"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter%5Baction_type%5D=generate&filter%5Bparent_id%5D=3000")
          .to_return(body: { data: [] }.to_json)

        expect_any_instance_of(MetrcService::Resource::WetWeight)
          .not_to receive(:harvest_plants)

        stub_request(:post, 'https://sandbox-api-md.metrc.com/plantbatches/v1/changegrowthphase?licenseNumber=LIC-0001')
          .with(body: expected_payload.to_json)
          .to_return(status: 200)
      end

      let(:expected_payload) do
        [{
          Name: 'ABCDEF1234567890ABCDEF01',
          Count: 2,
          StartingTag: nil,
          GrowthPhase: 'Vegetative',
          NewLocation: 'Mother Room',
          GrowthDate: '2020-04-15',
          PatientLicenseNumber: nil
        }]
      end

      it { is_expected.to be_success }
    end

    describe 'moving to flower substage' do
      let(:batch_id) { 82 }
      let(:seeding_unit_id) { 7 }
      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}/items?filter[seeding_unit_id]=#{seeding_unit_id}&include=barcodes,seeding_unit")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/items"))

        stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}/completions?filter%5Baction_type%5D=generate&filter%5Bparent_id%5D=3000")
          .to_return(body: { data: [] }.to_json)

        expect_any_instance_of(MetrcService::Resource::WetWeight)
          .not_to receive(:harvest_plants)

        stub_request(:post, 'https://sandbox-api-md.metrc.com/plantbatches/v1/changegrowthphase?licenseNumber=LIC-0001')
          .with(body: expected_payload.to_json)
          .to_return(status: 200)
      end

      let(:expected_payload) do
        [{
          Name: 'ABCDEF1234567890ABCDEF01',
          Count: 2,
          StartingTag: 'ABCDEF1234567890ABCDEF01',
          GrowthPhase: 'Flowering',
          NewLocation: 'F4 - Outside',
          GrowthDate: '2020-04-15',
          PatientLicenseNumber: nil
        }]
      end

      it { is_expected.to be_success }
    end

    describe 'moving and generating wet_weight' do
      let(:batch_id) { 84 }
      let(:seeding_unit_id) { 7 }
      let(:completion_id) { 432 }

      let(:ctx) do
        {
          id: completion_id,
          relationships: {
            batch: { data: { id: batch_id } },
            facility: { data: { id: facility_id } }
          },
          attributes: {
            start_time: '2020-04-15',
            options: {
              zone_id: 28,
              quantity: 2,
              resources: [{
                resource_unit_id: 17,
                generated_quantity: 5
              },{
                resource_unit_id: 18,
                generated_quantity: 0.5
              }],
              zone_name: 'F3 - Inside',
              sub_zone_id: nil,
              seeding_unit_id: 7
            }
          },
          completion_id: completion_id
        }.with_indifferent_access
      end

      let(:completion_fixtures) { JSON.parse(load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/completions")) }

      before do
        @stubs = []

        stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

        stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}/batches/#{batch_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}/batches/#{batch_id}/items?filter[seeding_unit_id]=#{seeding_unit_id}&include=barcodes,seeding_unit")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/items"))

        generate_completions = completion_fixtures['data'].select do |completion|
          completion['attributes'].slice('parent_id', 'action_type').values == [completion_id, 'generate']
        end

        stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}/completions?filter%5Baction_type%5D=generate&filter%5Bparent_id%5D=432")
          .to_return(body: { data: generate_completions }.to_json)

        stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}/resource_units?include=crop_variety")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/resource_units"))

        stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}/completions?filter%5Bcrop_batch_ids%5D%5B0%5D=#{batch_id}")
          .to_return(body: completion_fixtures.to_json)

        stub_request(:post, 'https://sandbox-api-md.metrc.com/plantbatches/v1/changegrowthphase?licenseNumber=LIC-0001')
          .with(body: expected_payload.to_json)
          .to_return(status: 200)

        @stubs << stub_request(:post, 'https://sandbox-api-md.metrc.com/plants/v1/harvestplants?licenseNumber=LIC-0001')
          .with(
            body: [{
              DryingLocation: 'F3 - Inside',
              PatientLicenseNumber: nil,
              ActualDate: '2020-04-15',
              Plant: 'ABCDEF1234567890ABCDEF02',
              Weight: 2.5,
              UnitOfWeight: 'Grams',
              HarvestName: 'Apr18-5th-Ele-Can'
            },{
              DryingLocation: 'F3 - Inside',
              PatientLicenseNumber: nil,
              ActualDate: '2020-04-15',
              Plant: 'ABCDEF1234567890ABCDEF03',
              Weight: 2.5,
              UnitOfWeight: 'Grams',
              HarvestName: 'Apr18-5th-Ele-Can'
            }].to_json,
          )
          .to_return(status: 200, body: '', headers: {})

        stub_request(:get, 'https://sandbox-api-md.metrc.com/harvests/v1/active?licenseNumber=LIC-0001')
          .to_return(status: 200, body: '[{"Id":123,"Name":"Some-Other-Harvest","HarvestType":"Product","SourceStrainCount":0},{"Id":234,"Name":"Apr18-5th-Ele-Can","HarvestType":"WholePlant","SourceStrainCount":0}]')

        stub_request(:get, 'https://sandbox-api-md.metrc.com/harvests/v1/waste/types')
          .to_return(status: 200, body: [{ Name: 'Wet Waste' }].to_json, headers: {})

        @stubs << stub_request(:post, 'https://sandbox-api-md.metrc.com/harvests/v1/removewaste?licenseNumber=LIC-0001')
          .with(
            body: [{ Id: 234, WasteType: 'Wet Waste', UnitOfWeight: 'Grams', WasteWeight: 0.5, ActualDate: '2020-04-15' }].to_json,
          )
          .to_return(status: 200, body: '', headers: {})
      end

      let(:expected_payload) do
        [{
          Name: 'ABCDEF1234567890ABCDEF01',
          Count: 2,
          StartingTag: 'ABCDEF1234567890ABCDEF02',
          GrowthPhase: 'Flowering',
          NewLocation: 'F3 - Inside',
          GrowthDate: '2020-04-15',
          PatientLicenseNumber: nil
        }]
      end

      it { is_expected.to be_success }

      after do
        @stubs.each do |stub|
          expect(stub).to have_been_requested
        end
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
        expect(next_step).to be :move_plant_batches
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
        expect(next_step).to be :move_plant_batches
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
