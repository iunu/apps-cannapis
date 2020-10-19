require 'rails_helper'

RSpec.describe MetrcService::Plant::Move do
  let(:account) { create(:account) }
  let(:integration) { create(:integration, account: account, state: 'md') }
  let(:ctx) do
    {
      id: 3000,
      relationships: {
        batch: { data: { id: 84 } },
        facility: { data: { id: 2 } }
      },
      attributes: {
        options: {
          tracking_barcode: '1A4FF01000000220000010',
          note_content: 'And the only prescription is moar cow bell',
          zone_name: 'Flowering'
        }
      },
      completion_id: 1001
    }.with_indifferent_access
  end

  describe '#call' do
    include_context 'with synced data' do
      let(:facility_id) { 2 }
      let(:batch_id) { 81 }
    end
    let(:transaction) { create(:transaction, :unsuccessful, :move, account: account, integration: integration) }
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

    subject { described_class.call(ctx, integration) }

    before do
      expect_any_instance_of(described_class)
        .to receive(:get_transaction)
        .and_return(transaction)
    end

    describe 'on an old successful transaction' do
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

    describe 'moving to vegetative phase' do
      let(:seeding_unit_id) { 7 }
      let(:previous_move) { create(:transaction, :successful, :move, account: account, integration: integration, batch_id: batch_id) }
      let(:expected_payload) do
        [{
          Name: 'ABCDEF1234567890ABCDEF01',
          Location: 'Mother Room',
          MoveDate: '2020-04-15'
        }]
      end

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}/items?filter[seeding_unit_id]=#{seeding_unit_id}&include=barcodes,seeding_unit")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/items"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/3000?include=action_result,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/3000'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/#{previous_move.completion_id}?include=action_result,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/3000'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter%5Baction_type%5D=generate&filter%5Bparent_id%5D=3000")
          .to_return(body: { data: [] }.to_json)

        stub_request(:put, 'https://sandbox-api-md.metrc.com/plantbatches/v1/moveplantbatches?licenseNumber=LIC-0001')
          .with(body: expected_payload.to_json)
          .to_return(status: 200)
      end

      it 'is successful' do
        expect_any_instance_of(MetrcService::Resource::WetWeight)
          .not_to receive(:harvest_plants)

        expect(subject).to be_success
      end
    end

    describe 'moving to flower phase' do
      let(:batch_id) { 82 }
      let(:seeding_unit_id) { 7 }
      let(:previous_move) { create(:transaction, :successful, :move, account: account, integration: integration, batch_id: batch_id) }
      let(:expected_payload) do
        [{
          Name: 'ABCDEF1234567890ABCDEF01',
          Location: 'F4 - Outside',
          MoveDate: '2020-04-15'
        }]
      end

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}/items?filter[seeding_unit_id]=#{seeding_unit_id}&include=barcodes,seeding_unit")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/items"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/3000?include=action_result,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/3000'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/#{previous_move.completion_id}?include=action_result,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/3000'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter%5Baction_type%5D=generate&filter%5Bparent_id%5D=3000")
          .to_return(body: { data: [] }.to_json)

        stub_request(:put, 'https://sandbox-api-md.metrc.com/plantbatches/v1/moveplantbatches?licenseNumber=LIC-0001')
          .with(body: expected_payload.to_json)
          .to_return(status: 200)
      end

      it 'is successful' do
        expect_any_instance_of(MetrcService::Resource::WetWeight)
          .not_to receive(:harvest_plants)

        expect(subject).to be_success
      end
    end
  end

  describe '#next_step' do
    let(:facility_id) { 2 }
    let(:batch_id) { 84 }
    let(:service) { described_class.new(ctx, integration) }
    let(:first_move) { nil }
    let(:second_move) { nil }
    subject { service.send :next_step, first_move, second_move }

    before do
      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
        .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
        .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/3000?include=action_result,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
        .to_return(body: load_response_json('api/completions/3000'))
    end

    context 'with no completions' do
      it 'returns the default move step' do
        expect(subject).to be :change_growth_phase
      end
    end

    context 'with an unsopported growth phase' do
      let(:first_move) do
        response = create_response('api/completions/762428-no-substage-no-seeding')
        artemis_client.process_response(response, 'completions')
      end
      let(:second_move) do
        response = create_response('api/completions/762429-no-substage-no-seeding')
        artemis_client.process_response(response, 'completions')
      end

      it 'returns the default move step' do
        expect(subject).to be :change_growth_phase
      end
    end

    context 'with no previous moves' do
      let(:second_move) do
        response = create_response('api/completions/762429-no-seeding')
        artemis_client.process_response(response, 'completions')
      end

      it 'returns the default move step' do
        expect(subject).to be :change_growth_phase
      end
    end

    context 'when a batch is moved from clone to clone and there\'s no barcodes' do
      let(:first_move) do
        response = create_response('api/completions/762428-no-seeding')
        artemis_client.process_response(response, 'completions')
      end
      let(:second_move) do
        response = create_response('api/completions/762429-no-seeding')
        artemis_client.process_response(response, 'completions')
      end

      it 'returns the move plant batches' do
        expect(subject).to be :move_plant_batches
      end
    end

    context 'with a previous flowering zone to a new flowering zone, and with barcodes' do
      let(:first_move) do
        response = create_response('api/completions/762428-flowering-preprinted')
        artemis_client.process_response(response, 'completions')
      end
      let(:second_move) do
        response = create_response('api/completions/762429-flowering-preprinted')
        artemis_client.process_response(response, 'completions')
      end

      it 'returns the change_plants_growth_phase step' do
        expect(subject).to be :change_plants_growth_phases
      end
    end

    context 'with a previous vegetative zone to a new vegetative zone, and with no previous barcode' do
      let(:first_move) do
        response = create_response('api/completions/762428-vegetative-no-seeding')
        artemis_client.process_response(response, 'completions')
      end
      let(:second_move) do
        response = create_response('api/completions/762429-vegetative-preprinted')
        artemis_client.process_response(response, 'completions')
      end

      it 'returns the change_growth_phase step' do
        expect(subject).to be :change_growth_phase
      end
    end

    context 'with a previous flowering zone to a new flowering zone, and with no previous barcode' do
      let(:first_move) do
        response = create_response('api/completions/762428-flowering-no-seeding')
        artemis_client.process_response(response, 'completions')
      end
      let(:second_move) do
        response = create_response('api/completions/762429-flowering-preprinted')
        artemis_client.process_response(response, 'completions')
      end

      it 'returns the change_growth_phase step' do
        expect(subject).to be :change_growth_phase
      end
    end

    context 'with a previous flowering zone to a new dry zone, and with barcodes' do
      let(:first_move) do
        response = create_response('api/completions/762428-flowering-preprinted')
        artemis_client.process_response(response, 'completions')
      end
      let(:second_move) do
        response = create_response('api/completions/762429-drying-preprinted')
        artemis_client.process_response(response, 'completions')
      end
      it 'returns the change_growth_phase step' do
        expect(subject).to be :move_harvest
      end
    end

    context 'with a previous flowering zone to a new cure zone, and with barcodes' do
      let(:first_move) do
        response = create_response('api/completions/762428-flowering-preprinted')
        artemis_client.process_response(response, 'completions')
      end
      let(:second_move) do
        response = create_response('api/completions/762429-curing-preprinted')
        artemis_client.process_response(response, 'completions')
      end
      it 'returns the change_growth_phase step' do
        expect(subject).to be :move_harvest
      end
    end

    context 'with a previous clone zone to a new clone zone, and with barcodes' do
      let(:first_move) do
        response = create_response('api/completions/762428-flowering-preprinted')
        artemis_client.process_response(response, 'completions')
      end
      let(:second_move) do
        response = create_response('api/completions/762429-clone-preprinted')
        artemis_client.process_response(response, 'completions')
      end

      it 'returns the move_plants step' do
        expect(subject).to be :move_plants
      end
    end
  end

  describe '#move_plants' do
    let(:items) do
      [
        instance_double('Item', relationships: {
          'barcode': {
            'data': {
              'id': 'ABCDEF1234567890ABCDEF01'
            }
          }
        }.with_indifferent_access)
      ]
    end
    let(:expected_payload) do
      items.map do |item|
        {
          Id: nil,
          Label: item.relationships.dig('barcode', 'data', 'id'),
          Location: 'F3 - Inside',
          ActualDate: '2020-04-18'
        }
      end
    end
    subject { described_class.new(ctx, integration) }

    before do
      expect_any_instance_of(described_class)
        .to receive(:items)
        .and_return(items)

      expect_any_instance_of(described_class)
        .to receive(:location_name)
        .and_return('F3 - Inside')

      expect_any_instance_of(described_class)
        .to receive(:start_time)
        .and_return('2020-04-18')

      stub_request(:post, 'https://sandbox-api-md.metrc.com/plants/v1/moveplants?licenseNumber=LIC-0001')
        .with(body: expected_payload.to_json)
        .to_return(status: 200)
    end

    it 'calls the Metrc client method' do
      expect(subject).to receive(:call_metrc)
        .with(:move_plants, expected_payload)
        .and_call_original

      subject.send(:move_plants)
    end
  end

  describe '#move_plant_batches' do
    let(:batch_tag) { 'Apr18-5th-Ele-Can' }
    let(:location_name) { 'F3 - Inside' }
    let(:start_time) { '2020-04-18' }
    let(:expected_payload) do
      [
        {
          Name: batch_tag,
          Location: location_name,
          MoveDate: start_time
        }
      ]
    end
    subject { described_class.new(ctx, integration) }

    before do
      expect_any_instance_of(described_class)
        .to receive(:batch_tag)
        .and_return(batch_tag)

      expect_any_instance_of(described_class)
        .to receive(:location_name)
        .and_return(location_name)

      expect_any_instance_of(described_class)
        .to receive(:start_time)
        .and_return(start_time)

      stub_request(:put, 'https://sandbox-api-md.metrc.com/plantbatches/v1/moveplantbatches?licenseNumber=LIC-0001')
        .with(body: expected_payload.to_json)
        .to_return(status: 200)
    end

    it 'calls the Metrc client method' do
      subject.should_receive(:call_metrc)
        .with(:move_plant_batches, expected_payload)
        .and_call_original

      subject.send(:move_plant_batches)
    end
  end

  describe '#change_growth_phase' do
    let(:batch_tag) { 'Apr18-5th-Ele-Can' }
    let(:quantity) { 10 }
    let(:normalized_growth_phase) { 'Flowering' }
    let(:location_name) { 'F3 - Inside' }
    let(:start_time) { '2020-04-18' }
    let(:facility_id) { 2 }
    let(:batch_id) { 84 }
    subject { described_class.new(ctx, integration) }

    before do
      expect_any_instance_of(described_class)
        .to receive(:batch_tag)
        .and_return(batch_tag)

      expect_any_instance_of(described_class)
        .to receive(:quantity)
        .and_return(quantity)

      expect_any_instance_of(described_class)
        .to receive(:normalized_growth_phase)
        .and_return(normalized_growth_phase)

      expect_any_instance_of(described_class)
        .to receive(:location_name)
        .and_return(location_name)

      expect_any_instance_of(described_class)
        .to receive(:start_time)
        .and_return(start_time)

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
        .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
        .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/3000?include=action_result,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
        .to_return(body: load_response_json('api/completions/3000'))

      stub_request(:post, 'https://sandbox-api-md.metrc.com/plantbatches/v1/changegrowthphase?licenseNumber=LIC-0001')
        .with(body: expected_payload.to_json)
        .to_return(status: 200)
    end

    context 'with an immature batch' do
      let(:expected_payload) do
        [{
          Name: batch_tag,
          Count: quantity,
          StartingTag: nil,
          GrowthPhase: normalized_growth_phase,
          NewLocation: location_name,
          GrowthDate: start_time,
          PatientLicenseNumber: nil
        }]
      end

      it 'calls the Metrc client method' do
        expect_any_instance_of(described_class)
          .to receive(:immature?)
          .and_return(true)

        subject.should_receive(:call_metrc)
          .with(:change_growth_phase, expected_payload)
          .and_call_original

        subject.send(:change_growth_phase)
      end
    end

    context 'with a mature batch' do
      let(:barcode) { 'ABCDEF1234567890ABCDEF01' }
      let(:expected_payload) do
        [
          {
            Name: batch_tag,
            Count: quantity,
            StartingTag: barcode,
            GrowthPhase: normalized_growth_phase,
            NewLocation: location_name,
            GrowthDate: start_time,
            PatientLicenseNumber: nil
          }
        ]
      end

      before do
        expect_any_instance_of(described_class)
          .to receive(:immature?)
          .and_return(false)

        expect_any_instance_of(described_class)
          .to receive(:barcode)
          .and_return(barcode)
      end

      it 'calls the Metrc client method' do
        subject.should_receive(:call_metrc)
          .with(:change_growth_phase, expected_payload)
          .and_call_original

        subject.send(:change_growth_phase)
      end
    end
  end

  describe '#change_plants_growth_phase' do
    let(:normalized_growth_phase) { 'Flowering' }
    let(:location_name) { 'F3 - Inside' }
    let(:start_time) { '2020-04-18' }
    let(:facility_id) { 2 }
    let(:batch_id) { 84 }
    let(:items) do
      [
        instance_double('Item', relationships: {
          'barcode': {
            'data': {
              'id': 'ABCDEF1234567890ABCDEF01'
            }
          }
        }.with_indifferent_access)
      ]
    end
    let(:expected_payload) do
      items.map do |item|
        {
          Id: nil,
          Label: item.relationships.dig('barcode', 'data', 'id'),
          NewLabel: nil,
          GrowthPhase: normalized_growth_phase,
          NewLocation: location_name,
          NewRoom: location_name,
          GrowthDate: start_time
        }
      end
    end
    subject { described_class.new(ctx, integration) }

    before do
      expect_any_instance_of(described_class)
        .to receive(:items)
        .and_return(items)

      expect_any_instance_of(described_class)
        .to receive(:normalized_growth_phase)
        .and_return(normalized_growth_phase)

      expect_any_instance_of(described_class)
        .to receive(:location_name)
        .twice
        .and_return(location_name)

      expect_any_instance_of(described_class)
        .to receive(:start_time)
        .and_return(start_time)

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
        .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
        .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/3000?include=action_result,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
        .to_return(body: load_response_json('api/completions/3000'))

      stub_request(:post, 'https://sandbox-api-md.metrc.com/plants/v1/changegrowthphases?licenseNumber=LIC-0001')
        .with(body: expected_payload.to_json)
        .to_return(status: 200)
    end

    it 'calls the Metrc client method' do
      subject.should_receive(:call_metrc)
        .with(:change_plant_growth_phase, expected_payload)
        .and_call_original

      subject.send(:change_plants_growth_phases)
    end
  end

  describe '#move_harvest' do
    subject { described_class.new(ctx, integration) }

    context 'with harvest sync' do
      let(:batch) { instance_double('Batch', arbitrary_id: 'Apr18-5th-Ele-Can') }
      let(:location_name) { 'F3 - Inside' }
      let(:start_time) { '2020-04-18' }
      let(:expected_payload) do
        [
          {
            HarvestName: batch.arbitrary_id,
            DryingLocation: location_name,
            DryingRoom: location_name,
            ActualDate: start_time
          }
        ]
      end

      it 'calls the Metrc client method' do
        subject.send(:move_harvest)
      end
    end

    context 'with harvest sync disabled' do
      let(:integration) { create(:integration, :harvest_sync_disabled, account: account, state: :md) }

      it 'does not perform the call' do
        subject.should_not_receive(:call_metrc)
             .with(:move_harvest)

        result = subject.send(:move_harvest)

        expect(result).to be_nil
      end
    end
  end

  describe '#normalized_growth_phase' do
    let(:sub_stage) { double(:sub_stage, name: 'clone') }
    let(:zone) { double(:zone, sub_stage: sub_stage) }
    let(:batch) { double(:batch, zone: zone) }
    let(:service) { described_class.new(ctx, integration) }
    let(:params) { [] }

    subject { service.send(:normalized_growth_phase, *params) }

    context 'with no value' do
      it { is_expected.to be_nil }
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

  describe '#next_step_name', :focus do
    context 'with no previous move but a start' do
      let(:facility_id) { 2 }
      let(:batch_id) { 84 }
      let(:start_transaction) { create(:transaction, :successful, :start, account: account, integration: integration, batch_id: batch_id, completion_id: 762428) }
      subject { described_class.new(ctx, integration) }

      before do
        start_transaction

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/762428?include=action_result,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/762428-flowering-preprinted'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/3000?include=action_result,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/762429-drying-preprinted'))
      end

      it 'returns move_harvest' do
        step_name = subject.send(:next_step_name)
        metadata = subject.transaction.metadata

        expect(step_name).to be :move_harvest
        expect(metadata.dig('sub_stage')).to eq 'Drying'
        expect(metadata.dig('next_step')).to eq 'move_harvest'
      end
    end
  end
end
