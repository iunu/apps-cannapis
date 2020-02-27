require 'rails_helper'

RSpec.describe MetrcService::Batch do
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
      }
    end

    let(:task) { create(:task, integration: integration) }

    subject { described_class.call(ctx, integration, nil, task) }

    describe 'with corn crop' do
      include_examples 'with corn crop'
    end

    describe 'with no completions' do
      before do
        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
          .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,barcodes,harvests,completions,custom_data,seeding_unit,harvest_unit,sub_zone,items,discard')
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16: 00: 00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { data: [] }, completions: { data: [{ type: 'completions', id: '652633' }] }, items: { data: [{ type: 'items', id: '969664' }, { type: 'items', id: '969663' }, { type: 'items', id: '969662' }, { type: 'items', id: '969661' }, { type: 'items', id: '969660' }] }, custom_data: { data: [] }, barcodes: { data: [] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { data: nil }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { data: { id: nil, type: 'sub_zones' } } } }, included: [{ id: '652633', type: 'completions', attributes: { id: 652633, user_id: 1598, content: nil, start_time: '2019-10-01T16: 00: 00.000Z', end_time: '2019-10-01T16: 00: 00.000Z', occurrence: nil, action_type: 'batch', options: { zone_id: 6422, quantity: '5', arbitrary_id: 'Oct1-Ban-Spl-Can', growth_cycle_id: 11417, seeding_unit_id: 3479, tracking_barcode: '1A4FF01000000220000010', arbitrary_id_base: 'Ban-Spl-Can' } }, relationships: { action_result: { data: { id: 96182, type: 'CropBatch' } }, batch: { data: { id: '96182', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '969664', type: 'items', attributes: { id: 969664, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000105', type: 'barcodes' } } } }, { id: '969663', type: 'items', attributes: { id: 969663, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000104', type: 'barcodes' } } } }, { id: '969662', type: 'items', attributes: { id: 969662, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000103', type: 'barcodes' } } } }, { id: '969661', type: 'items', attributes: { id: 969661, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000102', type: 'barcodes' } } } }, { id: '969660', type: 'items', attributes: { id: 969660, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000101', type: 'barcodes' } } } }, { id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plants (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'custom_prefix' } }, { id: '6425', type: 'zones', attributes: { id: 6425, facility_id: 1568, name: 'Flowering', slug: 'flowering', zone_type: 'generic', created_at: '2019-09-12T19: 56: 28.548Z', updated_at: '2019-09-12T19: 56: 28.548Z', status: 'active', position: nil, size: 0, seeding_unit: { id: 3479, name: 'Plants (barcoded)', zones: [{ id: 6122, slug: 'clone-room', name: 'Clone Room', seeding_unit_id: 3479, zone_type: 'trays', sub_zones: [] }, { id: 6425, slug: 'flowering', name: 'Flowering', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6431, slug: 'flowering-field', name: 'Flowering Field', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6429, slug: 'flowering-greenhouse', name: 'Flowering Greenhouse', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6666, slug: 'flower-room-barcoded', name: 'Flower Room Barcoded', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6422, slug: 'mothers', name: 'Mothers', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6434, slug: 'mothers', name: 'Mothers', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6427, slug: 'propagation', name: 'Propagation', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6424, slug: 'vegetation', name: 'Vegetation', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6430, slug: 'vegetation-field', name: 'Vegetation Field', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6428, slug: 'vegetation-greenhouse', name: 'Vegetation Greenhouse', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6665, slug: 'veg-room-barcoded', name: 'Veg Room Barcoded', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }], secondary_display_active: nil, secondary_display_capacity: nil }, seeding_unit_capacity: 0, system: 'None' }, relationships: { sub_zones: { meta: { included: false } }, seeding_unit: { meta: { included: false } } } }] }.to_json)

        # TODO: should we delete this task if there are no completions?
        # expect(task)
        #   .to receive(:delete)
        #   .and_call_original
      end

      it { is_expected.to be_nil }
    end

    describe 'with completions' do
      before do
        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
          .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,barcodes,harvests,completions,custom_data,seeding_unit,harvest_unit,sub_zone,discard')
          .to_return(body: { data: { id: '96197', type: 'batches', attributes: { id: 96197, arbitrary_id: 'Oct6-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: 105, expected_harvest_at: '2019-10-09', harvested_at: '2019-10-09', seeded_at: '2019-10-06', completed_at: '2019-10-09T04:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { data: [{ type: 'harvests', id: '80835' }, { type: 'harvests', id: '80834' }] }, completions: { data: [{ type: 'completions', id: '652798' }, { type: 'completions', id: '652799' }, { type: 'completions', id: '652800' }, { type: 'completions', id: '652801' }, { type: 'completions', id: '652802' }, { type: 'completions', id: '652820' }] }, items: { data: [{ type: 'items', id: '969669' }, { type: 'items', id: '969668' }, { type: 'items', id: '969667' }, { type: 'items', id: '969666' }, { type: 'items', id: '969665' }] }, custom_data: { data: [] }, barcodes: { data: [] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { data: { type: 'harvest_units', id: '5269' } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { data: { id: nil, type: 'sub_zones' } } } }, included: [{ id: '80835', type: 'harvests', attributes: { id: 80835, harvest_type: 'complete', quantity: 1, harvest_quantity: 100, harvested_at: '2019-10-09', secondary_harvest_quantity: nil }, relationships: { batch: { data: { id: '96197', type: 'batches' } }, completion: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } } } }, { id: '80834', type: 'harvests', attributes: { id: 80834, harvest_type: 'partial', quantity: 0, harvest_quantity: 5, harvested_at: '2019-10-09', secondary_harvest_quantity: nil }, relationships: { batch: { data: { id: '96197', type: 'batches' } }, completion: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } } } }, { id: '652798', type: 'completions', attributes: { id: 652798, user_id: 1598, content: nil, start_time: '2019-10-06T16:00:00.000Z', end_time: '2019-10-06T16:00:00.000Z', occurrence: nil, action_type: 'batch', options: { zone_id: 6422, quantity: '5', arbitrary_id: 'Oct6-Ban-Spl-Can', growth_cycle_id: 11417, seeding_unit_id: 3479, tracking_barcode: '1A4FF01000000220000011', arbitrary_id_base: 'Ban-Spl-Can' } }, relationships: { action_result: { data: { id: 96197, type: 'CropBatch' } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652799', type: 'completions', attributes: { id: 652799, user_id: 1598, content: { crop_batch_item_ids: [969665, 969666, 969667, 969668, 969669] }, start_time: '2019-10-06T16:00:00.000Z', end_time: '2019-10-06T16:00:00.000Z', occurrence: 0, action_type: 'start', options: { zone_id: 6422, quantity: '5', arbitrary_id: 'Oct6-Ban-Spl-Can', seeding_unit_id: 3479, tracking_barcode: '1A4FF01000000220000011', arbitrary_id_base: 'Ban-Spl-Can' } }, relationships: { action_result: { meta: { included: false } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652800', type: 'completions', attributes: { id: 652800, user_id: 1598, content: nil, start_time: '2019-10-07T04:00:00.000Z', end_time: '2019-10-07T04:00:00.000Z', occurrence: 0, action_type: 'move', options: { zone_id: 6424, quantity: 1, seeding_unit_id: 3479, tracking_barcode: 'Oct6-Ban-Spl-Can-' } }, relationships: { action_result: { meta: { included: false } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652801', type: 'completions', attributes: { id: 652801, user_id: 1598, content: nil, start_time: '2019-10-08T04:00:00.000Z', end_time: '2019-10-08T04:00:00.000Z', occurrence: 0, action_type: 'move', options: { zone_id: 6425, quantity: 1, seeding_unit_id: 3479, tracking_barcode: 'Oct6-Ban-Spl-Can-' } }, relationships: { action_result: { meta: { included: false } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652802', type: 'completions', attributes: { id: 652802, user_id: 1598, content: { crop_batch_item_ids: [969669, 969668, 969667, 969666, 969665] }, start_time: '2019-10-09T04:00:00.000Z', end_time: '2019-10-09T04:00:00.000Z', occurrence: 0, action_type: 'harvest', options: { harvest_type: 'partial', note_content: 'Testy', harvest_unit_id: 5266, seeding_unit_id: 3479, harvest_quantity: 5, quantity_remaining: 1 } }, relationships: { action_result: { data: { id: 80834, type: 'CropBatchHarvest' } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652820', type: 'completions', attributes: { id: 652820, user_id: 1598, content: { crop_batch_item_ids: [969665, 969666, 969667, 969668, 969669] }, start_time: '2019-10-09T04:00:00.000Z', end_time: '2019-10-09T04:00:00.000Z', occurrence: 0, action_type: 'harvest', options: { harvest_type: 'complete', note_content: 'Testy', harvest_unit_id: 5269, seeding_unit_id: 3479, harvest_quantity: 100, quantity_remaining: 1 } }, relationships: { action_result: { data: { id: 80835, type: 'CropBatchHarvest' } }, batch: { data: { id: '96197', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '652797', type: 'completions', attributes: { id: 652797, user_id: 1598, content: nil, start_time: '2019-10-04T16:00:00.000Z', end_time: '2019-10-04T04:00:00.000Z', occurrence: 0, action_type: 'discard', options: { barcode: %w[A4FF010000002200000101 A4FF010000002200000102 A4FF010000002200000103 A4FF010000002200000104 A4FF010000002200000105], quantity: 1, reason_type: 'other', discard_type: 'complete', note_content: 'The only prescription is more cowbell', reason_description: 'I have a fever' } }, relationships: { action_result: { data: { id: 111423, type: 'CropBatchDiscard' } }, batch: { data: { id: '96182', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '969669', type: 'items', attributes: { id: 969669, harvest_quantity: 21, secondary_harvest_quantity: 0, status: 'active', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000115', type: 'barcodes' } } } }, { id: '969668', type: 'items', attributes: { id: 969668, harvest_quantity: 21, secondary_harvest_quantity: 0, status: 'active', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000114', type: 'barcodes' } } } }, { id: '969667', type: 'items', attributes: { id: 969667, harvest_quantity: 21, secondary_harvest_quantity: 0, status: 'active', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000113', type: 'barcodes' } } } }, { id: '969666', type: 'items', attributes: { id: 969666, harvest_quantity: 21, secondary_harvest_quantity: 0, status: 'active', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000112', type: 'barcodes' } } } }, { id: '969665', type: 'items', attributes: { id: 969665, harvest_quantity: 21, secondary_harvest_quantity: 0, status: 'active', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000111', type: 'barcodes' } } } }, { id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plants (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'custom_prefix' } }, { id: '5269', type: 'harvest_units', attributes: { id: 5269, name: 'Wet Weight (g)', organization_id: 1020, active: true, weight: 0.002 } }, { id: '6425', type: 'zones', attributes: { id: 6425, facility_id: 1568, name: 'Flowering', slug: 'flowering', zone_type: 'generic', created_at: '2019-09-12T19:56:28.548Z', updated_at: '2019-09-12T19:56:28.548Z', status: 'active', position: nil, size: 0, seeding_unit: { id: 3479, name: 'Plants (barcoded)', zones: [{ id: 6122, slug: 'clone-room', name: 'Clone Room', seeding_unit_id: 3479, zone_type: 'trays', sub_zones: [] }, { id: 6425, slug: 'flowering', name: 'Flowering', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6431, slug: 'flowering-field', name: 'Flowering Field', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6429, slug: 'flowering-greenhouse', name: 'Flowering Greenhouse', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6666, slug: 'flower-room-barcoded', name: 'Flower Room Barcoded', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6422, slug: 'mothers', name: 'Mothers', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6434, slug: 'mothers', name: 'Mothers', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6427, slug: 'propagation', name: 'Propagation', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6424, slug: 'vegetation', name: 'Vegetation', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6430, slug: 'vegetation-field', name: 'Vegetation Field', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6428, slug: 'vegetation-greenhouse', name: 'Vegetation Greenhouse', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6665, slug: 'veg-room-barcoded', name: 'Veg Room Barcoded', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }], secondary_display_active: nil, secondary_display_capacity: nil }, seeding_unit_capacity: 0, system: 'None' }, relationships: { sub_zones: { meta: { included: false } }, seeding_unit: { meta: { included: false } } } }] }.to_json)

        expect(MetrcService::Start)
          .to receive(:call)

        expect(MetrcService::Move)
          .to receive(:call)
          .exactly(:twice)

        expect(MetrcService::Discard)
          .to receive(:call)

        expect(MetrcService::Harvest)
          .to receive(:call)
          .exactly(:twice)

        expect(task)
          .to receive(:delete)
          .and_call_original
      end

      it { is_expected.to be_nil }
    end
  end

  context 'module lookup' do
    let(:task) { create(:task, integration: integration) }
    let(:instance) { described_class.new(ctx, integration, nil, task) }
    let(:seeding_unit) { double(:seeding_unit, name: seeding_unit_name) }
    before do
      allow(instance)
        .to receive(:seeding_unit)
        .and_return(seeding_unit)
    end

    context '#module_name_for_seeding_unit' do
      subject { instance.send(:module_name_for_seeding_unit) }
      context 'crop' do
        let(:seeding_unit_name) { 'crop' }
        it { is_expected.to eq('crop') }
      end

      context 'package' do
        let(:seeding_unit_name) { 'package' }
        it { is_expected.to eq('package') }
      end

      context 'testing_package' do
        let(:seeding_unit_name) { 'testing_package' }
        it { is_expected.to eq('package') }
      end
    end

    context '#module_for_completion' do
      let(:completion) { double(:completion, action_type: 'start') }
      subject { instance.send(:module_for_completion, completion) }

      context 'crop' do
        let(:seeding_unit_name) { 'crop' }
        it { is_expected.to eq(MetrcService::Start) }
      end

      context 'package' do
        let(:seeding_unit_name) { 'package' }
        it { is_expected.to eq(MetrcService::Package::Start) }
      end

      context 'testing_package' do
        let(:seeding_unit_name) { 'testing_package' }
        it { is_expected.to eq(MetrcService::Package::Start) }
      end
    end
  end
end
