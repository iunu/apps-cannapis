require 'rails_helper'

RSpec.describe MetrcService::Plant::Move do
  let(:account) { create(:account) }
  let(:integration) { create(:integration, account: account, state: 'ma') }
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
      let(:zone) { double(:zone, sub_stage: sub_stage) }
      let(:batch) { double(:batch, crop: 'Cannabis', zone: zone) }

      it { is_expected.to eq(transaction) }
    end

    describe 'with corn crop' do
      include_examples 'with corn crop' do
        let(:sub_stage) { double(:sub_stage, name: 'clone', attributes: { 'name': 'clone' }) }
        let(:zone) { double(:zone, crop: 'Corn', sub_stage: sub_stage)  }
      end
    end

    describe 'skipping a non-barcoded split' do
      let(:seeding_unit_id) { 7 }

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}/items?filter[seeding_unit_id]=#{seeding_unit_id}&include=barcodes,seeding_unit")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/items"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/3000?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/3000-non-barcode-split'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter[crop_batch_ids][]=#{batch_id}")
          .to_return(body: { data: [
            JSON.parse(load_response_json('api/completions/2999-veg-move'))['data'],
            JSON.parse(load_response_json('api/completions/3000-non-barcode-split'))['data']
          ] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/2999?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/2999-veg-move'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter%5Baction_type%5D=generate&filter%5Bparent_id%5D=3000")
          .to_return(body: { data: [] }.to_json)
      end

      it 'skips transaction' do
        expect(subject).to be_skipped
      end
    end

    describe 'skipping a move_harvest' do
      let(:ctx) do
        {
          id: 2238,
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
          completion_id: 2238
        }.with_indifferent_access
      end

      let(:seeding_unit_id) { 7 }

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}/items?filter[seeding_unit_id]=#{seeding_unit_id}&include=barcodes,seeding_unit")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/items"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/2238?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/2238-curing-move'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter[crop_batch_ids][]=#{batch_id}")
          .to_return(body: { data: [
            JSON.parse(load_response_json('api/completions/2237-flower-move'))['data'],
            JSON.parse(load_response_json('api/completions/2238-curing-move'))['data'],
            JSON.parse(load_response_json('api/completions/2239-generate'))['data']
          ] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/2237?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/2237-flower-move'))

        # stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter%5Baction_type%5D=generate&filter%5Bparent_id%5D=3000")
        #   .to_return(body: { data: [] }.to_json)
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/resource_units/21?include=crop_variety")
          .to_return(body: load_response_json('api/sync/facilities/1/resource_units/21'))
      end

      it 'skips transaction' do
        expect(subject).to be_skipped
        expect(subject).not_to be_success
      end
    end

    describe 'moving from vegetative to vegetative phase' do
      let(:seeding_unit_id) { 7 }
      let(:expected_payload) do
        [{
          Name: 'ABCDEF1234567890ABCDEF01',
          Location: 'Zone 1',
          MoveDate: '2020-04-15'
        }]
      end

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}/items?filter[seeding_unit_id]=#{seeding_unit_id}&include=barcodes,seeding_unit")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/items"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/3000?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/3000-veg-move'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter[crop_batch_ids][]=#{batch_id}")
          .to_return(body: { data: [
            JSON.parse(load_response_json('api/completions/2999-veg-move'))['data'],
            JSON.parse(load_response_json('api/completions/3000-veg-move'))['data']
          ] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/2999?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/2999-veg-move'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter%5Baction_type%5D=generate&filter%5Bparent_id%5D=3000")
          .to_return(body: { data: [] }.to_json)

        stub_request(:put, 'https://sandbox-api-ma.metrc.com/plantbatches/v1/moveplantbatches?licenseNumber=LIC-0001')
          .with(body: expected_payload.to_json)
          .to_return(status: 200)
      end

      it 'is updates location successful' do
        expect_any_instance_of(MetrcService::Resource::WetWeight)
          .not_to receive(:harvest_plants)

        expect(subject).to be_success
      end
    end

    describe 'moving from flower to flower' do
      let(:batch_id) { 82 }
      let(:seeding_unit_id) { 7 }
      let(:ctx) do
        {
          id: 4000,
          relationships: {
            batch: { data: { id: batch_id } },
            facility: { data: { id: 2 } }
          },
          attributes: {
            start_time: '2020-04-15',
            options: {
              tracking_barcode: 'ABCDEF1234567890ABCDEF01',
              note_content: 'And the only prescription is moar cow bell',
              zone_name: 'Mothers [Flowering]',
              seeding_unit_id: seeding_unit_id
            }
          },
          completion_id: 4000
        }.with_indifferent_access
      end

      let(:expected_payload) do
        [{
          Name: 'ABCDEF1234567890ABCDEF01',
          Location: 'Zone 1',
          MoveDate: '2020-04-15'
        }]
      end

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}/items?filter[seeding_unit_id]=#{seeding_unit_id}&include=barcodes,seeding_unit")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/items"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/4000?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/4000-flower-move'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter[crop_batch_ids][]=#{batch_id}")
          .to_return(body: { data: [
            JSON.parse(load_response_json('api/completions/3999-flower-move'))['data'],
            JSON.parse(load_response_json('api/completions/4000-flower-move'))['data']
          ] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/3999?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/3999-flower-move'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter%5Baction_type%5D=generate&filter%5Bparent_id%5D=3000")
          .to_return(body: { data: [] }.to_json)

        stub_request(:put, 'https://sandbox-api-ma.metrc.com/plantbatches/v1/moveplantbatches?licenseNumber=LIC-0001')
          .with(body: expected_payload.to_json)
          .to_return(status: 200)
      end

      it 'is successful' do
        expect_any_instance_of(MetrcService::Resource::WetWeight)
          .not_to receive(:harvest_plants)

        expect(subject).to be_success
      end
    end

    describe 'moving from split_start vegetative to vegetative phase' do
      let(:seeding_unit_id) { 7 }
      let(:expected_payload) do
        [{
          Name: 'ABCDEF1234567890ABCDEF01',
          Location: 'Zone 1',
          MoveDate: '2020-04-15'
        }]
      end

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}/items?filter[seeding_unit_id]=#{seeding_unit_id}&include=barcodes,seeding_unit")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/items"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/3000?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/3000-veg-move'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter[crop_batch_ids][]=#{batch_id}")
          .to_return(body: { data: [
            JSON.parse(load_response_json('api/completions/2999-veg-split-start'))['data'],
            JSON.parse(load_response_json('api/completions/3000-veg-move'))['data']
          ] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/2999?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/2999-veg-split-start'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter%5Baction_type%5D=generate&filter%5Bparent_id%5D=3000")
          .to_return(body: { data: [] }.to_json)

        stub_request(:put, 'https://sandbox-api-ma.metrc.com/plantbatches/v1/moveplantbatches?licenseNumber=LIC-0001')
          .with(body: expected_payload.to_json)
          .to_return(status: 200)
      end

      it 'is updates location successful' do
        expect_any_instance_of(MetrcService::Resource::WetWeight)
          .not_to receive(:harvest_plants)

        expect(subject).to be_success
      end
    end

    describe 'moves to unsupported growth phases will raise an exception' do
      describe 'move to cure growth phase raises exception' do
        let(:ctx) do
          {
            id: 2238,
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
            completion_id: 2238
          }.with_indifferent_access
        end

        let(:seeding_unit_id) { 7 }

        before do
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
            .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}")
            .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
            .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}/items?filter[seeding_unit_id]=#{seeding_unit_id}&include=barcodes,seeding_unit")
            .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/items"))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/2238?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
            .to_return(body: load_response_json('api/completions/2238-curing-move'))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter[crop_batch_ids][]=#{batch_id}")
            .to_return(body: { data: [
              JSON.parse(load_response_json('api/completions/2237-flower-move'))['data'],
              JSON.parse(load_response_json('api/completions/2238-curing-move'))['data']
            ] }.to_json)

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/2237?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
            .to_return(body: load_response_json('api/completions/2237-flower-move'))
        end

        it 'raises an exception' do
          expect { subject }.to raise_exception(InvalidAttributes, /Curing is not a valid growth phase for the state of ma/)
        end
      end

      describe 'move to dry growth phase w/o a harvest weight reported raises exception' do
        let(:ctx) do
          {
            id: 2240,
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
            completion_id: 2240
          }.with_indifferent_access
        end

        let(:seeding_unit_id) { 7 }

        before do
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
            .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}")
            .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
            .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}/items?filter[seeding_unit_id]=#{seeding_unit_id}&include=barcodes,seeding_unit")
            .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/items"))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/2240?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
            .to_return(body: load_response_json('api/completions/2240-drying-move'))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter[crop_batch_ids][]=#{batch_id}")
            .to_return(body: { data: [
              JSON.parse(load_response_json('api/completions/2237-flower-move'))['data'],
              JSON.parse(load_response_json('api/completions/2240-drying-move'))['data']
            ] }.to_json)

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/2237?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
            .to_return(body: load_response_json('api/completions/2237-flower-move'))
        end

        it 'raises an exception' do
          expect { subject }.to raise_exception(InvalidAttributes, /Curing is not a valid growth phase for the state of ma/)
        end
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

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
        .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/3000?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
        .to_return(body: load_response_json('api/completions/3000'))

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter[crop_batch_ids][]=#{batch_id}")
        .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/completions"))
    end

    context 'with no completions' do
      it 'returns the default move step' do
        expect(subject).to be :change_growth_phase
      end
    end

    context 'with non-barcoded split' do
      let(:first_move) do
        response = create_response('api/completions/2999-veg-move')
        artemis_client.process_response(response, 'completions')
      end
      let(:second_move) do
        response = create_response('api/completions/3000-non-barcode-split')
        artemis_client.process_response(response, 'completions')
      end

      it 'returns nil' do
        expect(subject).to be nil
      end
    end

    context 'with an unsupported growth phase' do
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

    context 'with a previous veg zone to a new flowering zone, and with barcodes' do
      let(:first_move) do
        response = create_response('api/completions/762429-vegetative-preprinted')
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
        expect(subject).to be :move_plants
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
        expect(subject).to be :move_plants
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
    context 'with no split' do
      let(:expected_payload) do
        [
          {
            Id: nil,
            Label: 'ABCDEF1234567890ABCDEF01',
            Location: 'F3 - Inside',
            ActualDate: '2020-04-18'
          },
          {
            Id: nil,
            Label: 'ABCDEF1234567890ABCDEF03',
            Location: 'F3 - Inside',
            ActualDate: '2020-04-18'
          }
        ]
      end
      subject { described_class.new(ctx, integration) }

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/2")
          .to_return(body: load_response_json('api/sync/facilities/2'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/2/batches/84?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json('api/sync/facilities/2/batches/84'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/2/completions/3000?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/3000-veg-move'))

        stub_request(:post, 'https://sandbox-api-ma.metrc.com/plants/v1/moveplants?licenseNumber=LIC-0001')
          .with(body: expected_payload.to_json)
          .to_return(status: 200)
      end

      it 'calls the Metrc client method' do
        expect_any_instance_of(described_class)
          .to receive(:location_name)
          .twice
          .and_return('F3 - Inside')

        expect_any_instance_of(described_class)
          .to receive(:start_time)
          .twice
          .and_return('2020-04-18')

        expect_any_instance_of(described_class)
          .to receive(:call_metrc)
          .with(:move_plants, expected_payload)
          .and_call_original

        subject.send(:move_plants)
      end
    end

    context 'with a split' do
      let(:expected_payload) do
        [
          {
            Id: nil,
            Label: 'LABEL_00004001',
            Location: 'F3 - Inside',
            ActualDate: '2020-04-18'
          }
        ]
      end
      subject { described_class.new(ctx, integration) }

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/2")
          .to_return(body: load_response_json('api/sync/facilities/2'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/2/batches/84?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json('api/sync/facilities/2/batches/84'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/2/completions/3000?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/3000-split'))

        stub_request(:post, 'https://sandbox-api-ma.metrc.com/plants/v1/moveplants?licenseNumber=LIC-0001')
          .with(body: expected_payload.to_json)
          .to_return(status: 200)
      end

      it 'calls the Metrc client method' do
        expect_any_instance_of(described_class)
          .to receive(:location_name)
          .and_return('F3 - Inside')

        expect_any_instance_of(described_class)
          .to receive(:start_time)
          .and_return('2020-04-18')

        expect_any_instance_of(described_class)
          .to receive(:call_metrc)
          .with(:move_plants, expected_payload)
          .and_call_original

        subject.send(:move_plants)
      end
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

      stub_request(:put, 'https://sandbox-api-ma.metrc.com/plantbatches/v1/moveplantbatches?licenseNumber=LIC-0001')
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

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
        .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/3000?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
        .to_return(body: load_response_json('api/completions/3000'))

      stub_request(:post, 'https://sandbox-api-ma.metrc.com/plantbatches/v1/changegrowthphase?licenseNumber=LIC-0001')
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
          .to receive(:first_barcode)
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
    let(:barcode) { 'ABCDEF1234567890ABCDEF01' }
    let(:normalized_growth_phase) { 'Flowering' }
    let(:location_name) { 'F3 - Inside' }
    let(:start_time) { '2020-04-18' }
    let(:facility_id) { 2 }
    let(:batch_id) { 84 }
    let(:expected_payload) {
      [
        {
          Id: nil,
          Label: 'ABCDEF1234567890ABCDEF01',
          NewLabel: nil,
          GrowthPhase: normalized_growth_phase,
          NewLocation: location_name,
          GrowthDate: start_time
        },
        {
          Id: nil,
          Label: 'ABCDEF1234567890ABCDEF03',
          NewLabel: nil,
          GrowthPhase: normalized_growth_phase,
          NewLocation: location_name,
          GrowthDate: start_time
        }
      ]
    }
    subject { described_class.new(ctx, integration) }

    before do
      expect_any_instance_of(described_class)
        .to receive(:normalized_growth_phase)
        .and_return(normalized_growth_phase)

      expect_any_instance_of(described_class)
        .to receive(:location_name)
        .exactly(2)
        .and_return(location_name)

      expect_any_instance_of(described_class)
        .to receive(:start_time)
        .twice
        .and_return(start_time)

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
        .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
        .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/3000?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
        .to_return(body: load_response_json('api/completions/3000'))

      stub_request(:post, 'https://sandbox-api-ma.metrc.com/plants/v1/changegrowthphases?licenseNumber=LIC-0001')
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

  describe '#next_step_name' do
    context 'with no previous move but a start' do
      let(:facility_id) { 2 }
      let(:batch_id) { 84 }
      let(:ctx) do
        {
          id: 762429,
          relationships: {
            batch: { data: { id: batch_id } },
            facility: { data: { id: facility_id } }
          },
          attributes: {
            options: {
              zone_id: 7249,
              quantity: 100,
              sub_zone_id: nil,
              arbitrary_id: 'Mar30-Lav-Cak-M0102',
              crop_variety_id: 19278,
              seeding_unit_id: 3591,
              zone_name: 'Drying Room'
            }
          },
          completion_id: 762429
        }.with_indifferent_access
      end

      let(:start_transaction) { create(:transaction, :successful, :start, account: account, integration: integration, batch_id: batch_id, completion_id: 762429) }
      subject { described_class.new(ctx, integration) }

      before do
        start_transaction

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/762428?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/762428-flowering-preprinted'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter[crop_batch_ids][]=#{batch_id}")
          .to_return(body: { data: [
            JSON.parse(load_response_json('api/completions/762428-flowering-preprinted'))['data'],
            JSON.parse(load_response_json('api/completions/762429-drying-preprinted'))['data']
          ] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions/762429?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/762429-drying-preprinted'))
      end

      it 'returns move_plants' do
        step_name = subject.send(:next_step_name)
        metadata = subject.transaction.metadata

        expect(step_name).to be :move_plants
        expect(metadata.dig('sub_stage')).to eq 'Drying'
        expect(metadata.dig('next_step')).to eq 'move_plants'
      end
    end
  end
end
