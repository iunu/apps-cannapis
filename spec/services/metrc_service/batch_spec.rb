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

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,barcodes,completions,custom_data,seeding_unit,harvest_unit,sub_zone')
          .to_return(body: load_response_json('api/seed/batch-2002'))

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/completions?filter%5Bcrop_batch_ids%5D%5B0%5D=96182')
          .to_return(body: { data: [{ id: '652633', type: 'completions', attributes: { id: 652633, user_id: 1598, content: nil, start_time: '2019-10-01T16: 00: 00.000Z', end_time: '2019-10-01T16: 00: 00.000Z', occurrence: nil, action_type: 'batch', options: { zone_id: 6422, quantity: '5', arbitrary_id: 'Oct1-Ban-Spl-Can', growth_cycle_id: 11417, seeding_unit_id: 3479, tracking_barcode: '1A4FF01000000220000010', arbitrary_id_base: 'Ban-Spl-Can' } }, relationships: { action_result: { data: { id: 96182, type: 'CropBatch' } }, batch: { data: { id: '96182', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }] }.to_json)
      end

      it { is_expected.to be_nil }
    end

    describe 'with completions' do
      include_context 'with synced data'

      let(:successful_transaction) { create(:transaction, :harvest, :successful) }

      before do
        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
          .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,barcodes,completions,custom_data,seeding_unit,harvest_unit,sub_zone')
          .to_return(body: load_response_json('api/seed/batch-2002'))

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/completions?filter%5Bcrop_batch_ids%5D%5B0%5D=96182')
          .to_return(body: { data: [{ id: '652798', type: 'completions', attributes: { id: 652798, user_id: 1598, content: nil, start_time: '2019-10-06T16:00:00.000Z', end_time: '2019-10-06T16:00:00.000Z', occurrence: nil, action_type: 'batch', options: { zone_id: 6422, quantity: '5', arbitrary_id: 'Oct6-Ban-Spl-Can', growth_cycle_id: 11417, seeding_unit_id: 3479, tracking_barcode: '1A4FF01000000220000011', arbitrary_id_base: 'Ban-Spl-Can' } }, relationships: { action_result: { data: { id: 96197, type: 'CropBatch' } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652799', type: 'completions', attributes: { id: 652799, user_id: 1598, content: { crop_batch_item_ids: [969665, 969666, 969667, 969668, 969669] }, start_time: '2019-10-06T16:00:00.000Z', end_time: '2019-10-06T16:00:00.000Z', occurrence: 0, action_type: 'start', options: { zone_id: 6422, quantity: '5', arbitrary_id: 'Oct6-Ban-Spl-Can', seeding_unit_id: 3479, tracking_barcode: '1A4FF01000000220000011', arbitrary_id_base: 'Ban-Spl-Can' } }, relationships: { action_result: { meta: { included: false } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652800', type: 'completions', attributes: { id: 652800, user_id: 1598, content: nil, start_time: '2019-10-07T04:00:00.000Z', end_time: '2019-10-07T04:00:00.000Z', occurrence: 0, action_type: 'move', options: { zone_id: 6424, quantity: 1, seeding_unit_id: 3479, tracking_barcode: 'Oct6-Ban-Spl-Can-' } }, relationships: { action_result: { meta: { included: false } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652801', type: 'completions', attributes: { id: 652801, user_id: 1598, content: nil, start_time: '2019-10-08T04:00:00.000Z', end_time: '2019-10-08T04:00:00.000Z', occurrence: 0, action_type: 'move', options: { zone_id: 6425, quantity: 1, seeding_unit_id: 3479, tracking_barcode: 'Oct6-Ban-Spl-Can-' } }, relationships: { action_result: { meta: { included: false } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652802', type: 'completions', attributes: { id: 652802, user_id: 1598, content: { crop_batch_item_ids: [969669, 969668, 969667, 969666, 969665] }, start_time: '2019-10-09T04:00:00.000Z', end_time: '2019-10-09T04:00:00.000Z', occurrence: 0, action_type: 'harvest', options: { harvest_type: 'partial', note_content: 'Testy', harvest_unit_id: 5266, seeding_unit_id: 3479, harvest_quantity: 5, quantity_remaining: 1 } }, relationships: { action_result: { data: { id: 80834, type: 'CropBatchHarvest' } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652820', type: 'completions', attributes: { id: 652820, user_id: 1598, content: { crop_batch_item_ids: [969665, 969666, 969667, 969668, 969669] }, start_time: '2019-10-09T04:00:00.000Z', end_time: '2019-10-09T04:00:00.000Z', occurrence: 0, action_type: 'harvest', options: { harvest_type: 'complete', note_content: 'Testy', harvest_unit_id: 5269, seeding_unit_id: 3479, harvest_quantity: 100, quantity_remaining: 1 } }, relationships: { action_result: { data: { id: 80835, type: 'CropBatchHarvest' } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652797', type: 'completions', attributes: { id: 652797, user_id: 1598, content: nil, start_time: '2019-10-04T16:00:00.000Z', end_time: '2019-10-04T04:00:00.000Z', occurrence: 0, action_type: 'discard', options: { barcode: %w[A4FF010000002200000101 A4FF010000002200000102 A4FF010000002200000103 A4FF010000002200000104 A4FF010000002200000105], quantity: 1, reason_type: 'other', discard_type: 'complete', note_content: 'The only prescription is more cowbell', reason_description: 'I have a fever' } }, relationships: { action_result: { data: { id: 111423, type: 'CropBatchDiscard' } }, batch: { data: { id: '96182', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }] }.to_json)

        expect(MetrcService::Plant::Start)
          .to receive(:call)
          .and_return(successful_transaction)

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
