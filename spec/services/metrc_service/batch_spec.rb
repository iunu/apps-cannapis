require 'rails_helper'

RSpec.describe MetrcService::Batch do
  let(:account) { create(:account) }
  let(:integration) { create(:integration, account: account) }
  let(:ctx) do
    {
      id: 3000,
      relationships: {
        batch: { data: { id: 2002 } },
        facility: { data: { id: 1568 } }
      },
      attributes: {
        options: {
          tracking_barcode: '1A4FF01000000220000010'
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
          batch: { data: { id: 2002 } },
          facility: { data: { id: 1568 } }
        },
        attributes: {},
        completion_id: 1001
      }
    end

    let(:task) { create(:task, integration: integration) }

    let(:call) { described_class.call(ctx, integration, nil, task) }

    subject { call }

    describe 'with corn crop' do
      include_examples 'with corn crop'
    end

    describe 'with no completions' do
      include_context 'with synced data'

      before do
        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
          .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field')
          .to_return(body: load_response_json('api/seed/batch-2002'))

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/completions?filter%5Bcrop_batch_ids%5D%5B0%5D=96182')
          .to_return(body: { data: [{ id: '652633', type: 'completions', attributes: { id: 652633, user_id: 1598, content: nil, start_time: '2019-10-01T16: 00: 00.000Z', end_time: '2019-10-01T16: 00: 00.000Z', created_at: '2019-10-01T16: 00: 00.000Z', occurrence: nil, action_type: 'batch', status: 'active', options: { zone_id: 6422, quantity: '5', arbitrary_id: 'Oct1-Ban-Spl-Can', growth_cycle_id: 11417, seeding_unit_id: 3479, tracking_barcode: '1A4FF01000000220000010', arbitrary_id_base: 'Ban-Spl-Can' } }, relationships: { action_result: { data: { id: 96182, type: 'CropBatch' } }, batch: { data: { id: '96182', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }] }.to_json)
      end

      it { is_expected.to be_nil }
    end

    describe 'with completions' do
      include_context 'with synced data'

      let(:successful_transaction) { create(:transaction, :harvest, :successful) }
      let(:skipped_transaction) { create(:transaction, :harvest, :skipped) }

      before do
        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
          .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field')
          .to_return(body: load_response_json('api/seed/batch-2002'))

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/completions?filter%5Bcrop_batch_ids%5D%5B0%5D=96182')
          .to_return(body: { data: [
            JSON.parse(load_response_json('api/1568-facility/completions/652799-start'))['data'],
            JSON.parse(load_response_json('api/1568-facility/completions/652800-move'))['data'],
            JSON.parse(load_response_json('api/1568-facility/completions/652801-move'))['data'],
            JSON.parse(load_response_json('api/1568-facility/completions/652802-partial-harvest'))['data'],
            JSON.parse(load_response_json('api/1568-facility/completions/652810-discard'))['data'],
            JSON.parse(load_response_json('api/1568-facility/completions/652820-complete-harvest'))['data']
          ] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/652799?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/1568-facility/completions/652799-start'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/652800?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/1568-facility/completions/652800-move'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/652801?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/1568-facility/completions/652801-move'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/652802?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/1568-facility/completions/652802-partial-harvest'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/652810?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/1568-facility/completions/652810-discard'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/652820?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/1568-facility/completions/652820-complete-harvest'))

        expect(MetrcService::Plant::Start)
          .to receive(:call)
          .and_return(skipped_transaction)

        expect(MetrcService::Plant::Move)
          .to receive(:call)
          .exactly(:twice)
          .and_return(successful_transaction)

        expect(MetrcService::Plant::Discard)
          .to receive(:call)
          .and_return(successful_transaction)

        expect(MetrcService::Plant::Harvest)
          .to receive(:call)
          .exactly(:twice)
          .and_return(successful_transaction)

        expect(task)
          .to receive(:delete)
          .and_call_original

        expect(task)
          .to receive(:current_action=)
          .with(%r{metrc_service/plant/.*})
          .exactly(6).times
          .and_call_original
      end

      it { is_expected.to be_a(Transaction) }
      it { is_expected.to be_success }
    end
  end
end
