require 'rails_helper'

RSpec.describe NcsService::Batch do
  let(:account) { create(:account) }
  let(:integration) { create(:integration, :ncs_vendor, account: account) }
  let(:ctx) do
    {
      id: 3000,
      relationships: {
        batch: { data: { id: 96197 } },
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

  describe '#call' do
    let(:ctx) do
      {
        id: 3000,
        relationships: {
          batch: { data: { id: 96197 } },
          facility: { data: { id: 1568 } }
        },
        attributes: {},
        completion_id: 1001
      }
    end

    let(:task) { create(:task, integration: integration) }

    subject { described_class.call(ctx, integration, nil, task) }

    context 'with corn crop' do
      include_examples 'with corn crop'
    end

    context 'with no completions' do
      before do
        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
          .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/96197?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field')
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16: 00: 00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { data: [] }, completions: { data: [{ type: 'completions', id: '652633' }] }, items: { data: [{ type: 'items', id: '969664' }, { type: 'items', id: '969663' }, { type: 'items', id: '969662' }, { type: 'items', id: '969661' }, { type: 'items', id: '969660' }] }, custom_data: { data: [] }, barcodes: { data: [] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } },  zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { data: { id: nil, type: 'sub_zones' } } } }, included: [{ id: '652633', type: 'completions', attributes: { id: 652633, user_id: 1598, content: nil, start_time: '2019-10-01T16: 00: 00.000Z', end_time: '2019-10-01T16: 00: 00.000Z', occurrence: nil, action_type: 'batch', options: { zone_id: 6422, quantity: '5', arbitrary_id: 'Oct1-Ban-Spl-Can', growth_cycle_id: 11417, seeding_unit_id: 3479, tracking_barcode: '1A4FF01000000220000010', arbitrary_id_base: 'Ban-Spl-Can' } }, relationships: { action_result: { data: { id: 96182, type: 'CropBatch' } }, batch: { data: { id: '96182', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '969664', type: 'items', attributes: { id: 969664,status: 'removed' }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000105', type: 'barcodes' } } } }, { id: '969663', type: 'items', attributes: { id: 969663,status: 'removed' }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000104', type: 'barcodes' } } } }, { id: '969662', type: 'items', attributes: { id: 969662,status: 'removed' }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000103', type: 'barcodes' } } } }, { id: '969661', type: 'items', attributes: { id: 969661,status: 'removed' }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000102', type: 'barcodes' } } } }, { id: '969660', type: 'items', attributes: { id: 969660,status: 'removed' }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000101', type: 'barcodes' } } } }, { id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'custom_prefix' } }, { id: '6425', type: 'zones', attributes: { id: 6425, facility_id: 1568, name: 'Flowering', slug: 'flowering', zone_type: 'generic', created_at: '2019-09-12T19: 56: 28.548Z', updated_at: '2019-09-12T19: 56: 28.548Z', status: 'active', position: nil, size: 0, seeding_unit: { id: 3479, name: 'Plant (barcoded)', zones: [{ id: 6122, slug: 'clone-room', name: 'Clone Room', seeding_unit_id: 3479, zone_type: 'trays', sub_zones: [] }, { id: 6425, slug: 'flowering', name: 'Flowering', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6431, slug: 'flowering-field', name: 'Flowering Field', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6429, slug: 'flowering-greenhouse', name: 'Flowering Greenhouse', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6666, slug: 'flower-room-barcoded', name: 'Flower Room Barcoded', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6422, slug: 'mothers', name: 'Mothers', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6434, slug: 'mothers', name: 'Mothers', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6427, slug: 'propagation', name: 'Propagation', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6424, slug: 'vegetation', name: 'Vegetation', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6430, slug: 'vegetation-field', name: 'Vegetation Field', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6428, slug: 'vegetation-greenhouse', name: 'Vegetation Greenhouse', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6665, slug: 'veg-room-barcoded', name: 'Veg Room Barcoded', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }], secondary_display_active: nil, secondary_display_capacity: nil }, seeding_unit_capacity: 0, system: 'None' }, relationships: { sub_zones: { meta: { included: false } }, seeding_unit: { meta: { included: false } } } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions?filter[crop_batch_ids][0]=96182")
          .to_return(status: 200, body: { data: [] }.to_json, headers: {})
      end

      it { is_expected.to be_nil }
    end

    context 'with completions' do
      include_context 'with synced data'

      let(:successful_transaction) { create(:transaction, :ncs_vendor, :harvest, :successful, account: account, integration: integration) }

      before do
        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
          .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/96197?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field')
          .to_return(body: load_response_json('api/seed/batch-2002'))

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/completions?filter[crop_batch_ids][0]=96182')
          .to_return(body: { data: [{ id: '652798', type: 'completions', attributes: { id: 652798, user_id: 1598, content: nil, start_time: '2019-10-06T16:00:00.000Z', end_time: '2019-10-06T16:00:00.000Z', occurrence: nil, action_type: 'batch', options: { zone_id: 6422, quantity: '5', arbitrary_id: 'Oct6-Ban-Spl-Can', growth_cycle_id: 11417, seeding_unit_id: 3479, tracking_barcode: '1A4FF01000000220000011', arbitrary_id_base: 'Ban-Spl-Can' } }, relationships: { action_result: { data: { id: 96197, type: 'CropBatch' } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652799', type: 'completions', attributes: { id: 652799, user_id: 1598, content: { crop_batch_item_ids: [969665, 969666, 969667, 969668, 969669] }, start_time: '2019-10-06T16:00:00.000Z', end_time: '2019-10-06T16:00:00.000Z', occurrence: 0, action_type: 'start', options: { zone_id: 6422, quantity: '5', arbitrary_id: 'Oct6-Ban-Spl-Can', seeding_unit_id: 3479, tracking_barcode: '1A4FF01000000220000011', arbitrary_id_base: 'Ban-Spl-Can' } }, relationships: { action_result: { meta: { included: false } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652800', type: 'completions', attributes: { id: 652800, user_id: 1598, content: nil, start_time: '2019-10-07T04:00:00.000Z', end_time: '2019-10-07T04:00:00.000Z', occurrence: 0, action_type: 'move', options: { zone_id: 6424, quantity: 1, seeding_unit_id: 3479, tracking_barcode: 'Oct6-Ban-Spl-Can-' } }, relationships: { action_result: { meta: { included: false } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652801', type: 'completions', attributes: { id: 652801, user_id: 1598, content: nil, start_time: '2019-10-08T04:00:00.000Z', end_time: '2019-10-08T04:00:00.000Z', occurrence: 0, action_type: 'move', options: { zone_id: 6425, quantity: 1, seeding_unit_id: 3479, tracking_barcode: 'Oct6-Ban-Spl-Can-' } }, relationships: { action_result: { meta: { included: false } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652802', type: 'completions', attributes: { id: 652802, user_id: 1598, content: { crop_batch_item_ids: [969669, 969668, 969667, 969666, 969665] }, start_time: '2019-10-09T04:00:00.000Z', end_time: '2019-10-09T04:00:00.000Z', occurrence: 0, action_type: 'harvest', options: { harvest_type: 'partial', note_content: 'Testy', seeding_unit_id: 3479, harvest_quantity: 5, quantity_remaining: 1 } }, relationships: { action_result: { data: { id: 80834, type: 'CropBatchHarvest' } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652820', type: 'completions', attributes: { id: 652820, user_id: 1598, content: { crop_batch_item_ids: [969665, 969666, 969667, 969668, 969669] }, start_time: '2019-10-09T04:00:00.000Z', end_time: '2019-10-09T04:00:00.000Z', occurrence: 0, action_type: 'harvest', options: { harvest_type: 'complete', note_content: 'Testy', seeding_unit_id: 3479, harvest_quantity: 100, quantity_remaining: 1 } }, relationships: { action_result: { data: { id: 80835, type: 'CropBatchHarvest' } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652797', type: 'completions', attributes: { id: 652797, user_id: 1598, content: nil, start_time: '2019-10-04T16:00:00.000Z', end_time: '2019-10-04T04:00:00.000Z', occurrence: 0, action_type: 'discard', options: { barcode: %w[A4FF010000002200000101 A4FF010000002200000102 A4FF010000002200000103 A4FF010000002200000104 A4FF010000002200000105], quantity: 1, reason_type: 'other', discard_type: 'complete', note_content: 'The only prescription is more cowbell', reason_description: 'I have a fever' } }, relationships: { action_result: { data: { id: 111423, type: 'CropBatchDiscard' } }, batch: { data: { id: '96182', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }] }.to_json)

        expect(NcsService::Plant::Start)
          .to receive(:call)
          .and_return(successful_transaction)

        expect(NcsService::Plant::Move)
          .to receive(:call)
          .exactly(:twice)
          .and_return(successful_transaction)

        expect(NcsService::Plant::Discard)
          .to receive(:call)
          .and_return(successful_transaction)

        expect(NcsService::Plant::Harvest)
          .to receive(:call)
          .exactly(:twice)
          .and_return(successful_transaction)

        expect(task)
          .to receive(:delete)
          .and_call_original

        expect(task)
          .to receive(:current_action=)
          .with(%r{ncs_service/plant/.*})
          .exactly(6).times
          .and_call_original
      end

      xit { is_expected.to be_a(Transaction) }
      xit { is_expected.to be_success }
    end
  end
end
