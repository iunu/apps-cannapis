require 'rails_helper'

RSpec.describe NcsService::Plant::Harvest do
  def load_response_json(path)
    File.read("spec/support/data/#{path}.json")
  end

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

    subject { described_class.call(ctx, integration) }

    before do
      expect_any_instance_of(described_class)
        .to receive(:get_transaction)
        .and_return(transaction)
    end

    context 'with an old successful transaction' do
      let(:transaction) { create(:transaction, :successful, :harvest, account: account, integration: integration, vendor: :ncs) }

      it { is_expected.to eq(transaction) }
    end

    context 'with corn crop' do
      include_examples 'with corn crop'
    end

    context 'with a partial harvest' do
      let(:transaction) { create(:transaction, :successful, :harvest, account: account, integration: integration, vendor: :ncs) }

      let(:ctx) do
        {
          id: 3000,
          relationships: {
            batch: { data: { id: 96182 } },
            facility: { data: { id: 1568 } }
          },
          attributes: {
            start_time: '2019-11-13T18:44:45',
            options: {
              tracking_barcode: '1A4FF01000000220000010',
              note_content: 'And the only prescription is moar cow bell',
              harvest_type: 'partial',
              zone_name: 'Flowering',
              seeding_unit_id: 3479
            }
          }
        }.with_indifferent_access
      end

      before do
        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
          .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/96182')
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16: 00: 00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { data: [] }, completions: { data: [{ type: 'completions', id: '652633' }] }, items: { data: [{ type: 'items', id: '969664' }, { type: 'items', id: '969663' }, { type: 'items', id: '969662' }, { type: 'items', id: '969661' }, { type: 'items', id: '969660' }] }, custom_data: { data: [] }, barcodes: { data: [] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { data: nil }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { data: { id: nil, type: 'sub_zones' } } } }, included: [{ id: '652633', type: 'completions', attributes: { id: 652633, user_id: 1598, content: nil, start_time: '2019-10-01T16: 00: 00.000Z', end_time: '2019-10-01T16: 00: 00.000Z', occurrence: nil, action_type: 'batch', options: { zone_id: 6422, quantity: '5', arbitrary_id: 'Oct1-Ban-Spl-Can', growth_cycle_id: 11417, seeding_unit_id: 3479, tracking_barcode: '1A4FF01000000220000010', arbitrary_id_base: 'Ban-Spl-Can' } }, relationships: { action_result: { data: { id: 96182, type: 'CropBatch' } }, batch: { data: { id: '96182', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '969664', type: 'items', attributes: { id: 969664, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: 'Grams' }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000105', type: 'barcodes' } } } }, { id: '969663', type: 'items', attributes: { id: 969663, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000104', type: 'barcodes' } } } }, { id: '969662', type: 'items', attributes: { id: 969662, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000103', type: 'barcodes' } } } }, { id: '969661', type: 'items', attributes: { id: 969661, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000102', type: 'barcodes' } } } }, { id: '969660', type: 'items', attributes: { id: 969660, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000101', type: 'barcodes' } } } }, { id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'preprinted' } }, { id: '6425', type: 'zones', attributes: { id: 6425, facility_id: 1568, name: 'Flowering', slug: 'flowering', zone_type: 'generic', created_at: '2019-09-12T19: 56: 28.548Z', updated_at: '2019-09-12T19: 56: 28.548Z', status: 'active', position: nil, size: 0, seeding_unit: { id: 3479, name: 'Plant (barcoded)', zones: [{ id: 6122, slug: 'clone-room', name: 'Clone Room', seeding_unit_id: 3479, zone_type: 'trays', sub_zones: [] }, { id: 6425, slug: 'flowering', name: 'Flowering', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6431, slug: 'flowering-field', name: 'Flowering Field', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6429, slug: 'flowering-greenhouse', name: 'Flowering Greenhouse', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6666, slug: 'flower-room-barcoded', name: 'Flower Room Barcoded', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6422, slug: 'mothers', name: 'Mothers', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6434, slug: 'mothers', name: 'Mothers', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6427, slug: 'propagation', name: 'Propagation', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6424, slug: 'vegetation', name: 'Vegetation', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6430, slug: 'vegetation-field', name: 'Vegetation Field', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6428, slug: 'vegetation-greenhouse', name: 'Vegetation Greenhouse', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6665, slug: 'veg-room-barcoded', name: 'Veg Room Barcoded', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }], secondary_display_active: nil, secondary_display_capacity: nil }, seeding_unit_capacity: 0, system: 'None' }, relationships: { sub_zones: { meta: { included: false } }, seeding_unit: { meta: { included: false } } } }] }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/96182?include=zone,barcodes,items,custom_data,seeding_unit,harvest_unit,sub_zone')
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16: 00: 00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { data: [] }, completions: { data: [{ type: 'completions', id: '652633' }] }, items: { data: [{ type: 'items', id: '969664' }, { type: 'items', id: '969663' }, { type: 'items', id: '969662' }, { type: 'items', id: '969661' }, { type: 'items', id: '969660' }] }, custom_data: { data: [] }, barcodes: { data: [] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { data: nil }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { data: { id: nil, type: 'sub_zones' } } } }, included: [{ id: '652633', type: 'completions', attributes: { id: 652633, user_id: 1598, content: nil, start_time: '2019-10-01T16: 00: 00.000Z', end_time: '2019-10-01T16: 00: 00.000Z', occurrence: nil, action_type: 'batch', options: { zone_id: 6422, quantity: '5', arbitrary_id: 'Oct1-Ban-Spl-Can', growth_cycle_id: 11417, seeding_unit_id: 3479, tracking_barcode: '1A4FF01000000220000010', arbitrary_id_base: 'Ban-Spl-Can' } }, relationships: { action_result: { data: { id: 96182, type: 'CropBatch' } }, batch: { data: { id: '96182', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '969664', type: 'items', attributes: { id: 969664, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000105', type: 'barcodes' } } } }, { id: '969663', type: 'items', attributes: { id: 969663, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000104', type: 'barcodes' } } } }, { id: '969662', type: 'items', attributes: { id: 969662, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000103', type: 'barcodes' } } } }, { id: '969661', type: 'items', attributes: { id: 969661, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000102', type: 'barcodes' } } } }, { id: '969660', type: 'items', attributes: { id: 969660, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000101', type: 'barcodes' } } } }, { id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'preprinted' } }, { id: '6425', type: 'zones', attributes: { id: 6425, facility_id: 1568, name: 'Flowering', slug: 'flowering', zone_type: 'generic', created_at: '2019-09-12T19: 56: 28.548Z', updated_at: '2019-09-12T19: 56: 28.548Z', status: 'active', position: nil, size: 0, seeding_unit: { id: 3479, name: 'Plant (barcoded)', zones: [{ id: 6122, slug: 'clone-room', name: 'Clone Room', seeding_unit_id: 3479, zone_type: 'trays', sub_zones: [] }, { id: 6425, slug: 'flowering', name: 'Flowering', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6431, slug: 'flowering-field', name: 'Flowering Field', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6429, slug: 'flowering-greenhouse', name: 'Flowering Greenhouse', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6666, slug: 'flower-room-barcoded', name: 'Flower Room Barcoded', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6422, slug: 'mothers', name: 'Mothers', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6434, slug: 'mothers', name: 'Mothers', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6427, slug: 'propagation', name: 'Propagation', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6424, slug: 'vegetation', name: 'Vegetation', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6430, slug: 'vegetation-field', name: 'Vegetation Field', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6428, slug: 'vegetation-greenhouse', name: 'Vegetation Greenhouse', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6665, slug: 'veg-room-barcoded', name: 'Veg Room Barcoded', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }], secondary_display_active: nil, secondary_display_capacity: nil }, seeding_unit_capacity: 0, system: 'None' }, relationships: { sub_zones: { meta: { included: false } }, seeding_unit: { meta: { included: false } } } }] }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/96182/items?filter[seeding_unit_id]=3479&include=barcodes,seeding_unit')
          .to_return(body: { data: [{ id: '969664', type: 'items', attributes: { id: 969664, harvest_quantity: 0, secondary_harvest_quantity: 10.0, secondary_harvest_unit: 'Grams', harvest_unit: 'Grams' }, relationships: { barcode: { data: { id: '1A4FF010000002200000105', type: 'barcodes' } } } }, { id: '969663', type: 'items', attributes: { id: 969663, harvest_quantity: 0, secondary_harvest_quantity: 10.0, secondary_harvest_unit: 'Grams', harvest_unit: 'Grams' }, relationships: { barcode: { data: { id: '1A4FF010000002200000104', type: 'barcodes' } } } }, { id: '969662', type: 'items', attributes: { id: 969662, harvest_quantity: 0, secondary_harvest_quantity: 10.0, secondary_harvest_unit: 'Grams', harvest_unit: 'Grams' }, relationships: { barcode: { data: { id: '1A4FF010000002200000103', type: 'barcodes' } } } }] }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/resource_units')
          .to_return(body: { data: [{ id: '99', type: 'resource_units', attributes: { id: 99, conversion_si: 1.0, kind: 'weight', name: 'g Wet Material - Banana Split' } }, { id: '100', type: 'resource_units', attributes: { id: 100, conversion_si: 1.0, kind: 'weight', name: 'g Waste - Banana Split' } }] }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/96182/completions')
          .to_return(body: { data: [] }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/completions?filter%5Bcrop_batch_ids%5D%5B0%5D=96182')
          .to_return(body: { data: [] }.to_json)

        stub_request(:post, "#{ENV['NCS_BASE_URI']}/pos/plants/v1/manicureplants")
          .with(
            body: [{ Label: '1A4FF010000002200000105', ManicuredWeight: 0.0, ManicuredUnitOfWeightName: 'Grams', RoomName: 'Flowering', HarvestName: nil, ManicuredDate: '2019-11-13T18:44:45' }, { Label: '1A4FF010000002200000104', ManicuredWeight: 0.0, ManicuredUnitOfWeightName: 'Grams', RoomName: 'Flowering', HarvestName: nil, ManicuredDate: '2019-11-13T18:44:45' }, { Label: '1A4FF010000002200000103', ManicuredWeight: 0.0, ManicuredUnitOfWeightName: 'Grams', RoomName: 'Flowering', HarvestName: nil, ManicuredDate: '2019-11-13T18:44:45' }].to_json,
            headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ABC1234567890' }
          )
          .to_return(status: 200, body: '{}', headers: {})

        stub_request(:get, "#{ENV['NCS_BASE_URI']}/pos/harvests/v1/active")
          .with(headers: { Authorization: 'Bearer ABC1234567890', 'Content-Type': 'application/json' })
          .to_return(status: 200, body: [{ Id: 100, Name: 'Oct1-Ban-Spl-Can' }].to_json, headers: {})

        stub_request(:post, "#{ENV['NCS_BASE_URI']}/pos/harvests/v1/removewaste")
          .with(
            body: [].to_json,
            headers: {
              Authorization: 'Bearer ABC1234567890',
              'Content-Type': 'application/json'
            })
          .to_return(status: 200, body: "{}", headers: {})

        allow(subject).to receive(:get_transaction).and_return transaction
      end

      subject { described_class.new(ctx, integration) }

      it 'calls NCS\' manicure plants method' do
        final_transaction = subject.call

        expect(subject).to have_received(:get_transaction)
        expect(final_transaction).not_to be_nil
        expect(final_transaction.success).to eq true
      end
    end

    context 'with a complete harvest' do
      let(:transaction) { create(:transaction, :successful, :harvest, account: account, integration: integration, vendor: :ncs) }

      let(:ctx) do
        {
          id: 3000,
          relationships: {
            batch: { data: { id: 96182 } },
            facility: { data: { id: 1568 } }
          },
          attributes: {
            start_time: '2019-11-13T18:44:45',
            options: {
              tracking_barcode: '1A4FF01000000220000010',
              note_content: 'And the only prescription is moar cow bell',
              harvest_type: 'complete',
              zone_name: 'Clone',
              seeding_unit_id: 3479
            }
          }
        }.with_indifferent_access
      end

      subject { described_class.call(ctx, integration) }

      before do
        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
          .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/96182')
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16: 00: 00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { data: [] }, completions: { data: [{ type: 'completions', id: '652633' }] }, items: { data: [{ type: 'items', id: '969664' }, { type: 'items', id: '969663' }, { type: 'items', id: '969662' }, { type: 'items', id: '969661' }, { type: 'items', id: '969660' }] }, custom_data: { data: [] }, barcodes: { data: [{ id: '1A4FF010000002200000211' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { data: nil }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { data: { id: nil, type: 'sub_zones' } } } }, included: [{ id: '652633', type: 'completions', attributes: { id: 652633, user_id: 1598, content: nil, start_time: '2019-10-01T16: 00: 00.000Z', end_time: '2019-10-01T16: 00: 00.000Z', occurrence: nil, action_type: 'batch', options: { zone_id: 6422, quantity: '5', arbitrary_id: 'Oct1-Ban-Spl-Can', growth_cycle_id: 11417, seeding_unit_id: 3479, tracking_barcode: '1A4FF01000000220000010', arbitrary_id_base: 'Ban-Spl-Can' } }, relationships: { action_result: { data: { id: 96182, type: 'CropBatch' } }, batch: { data: { id: '96182', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '969664', type: 'items', attributes: { id: 969664, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: 'Grams' }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000105', type: 'barcodes' } } } }, { id: '969663', type: 'items', attributes: { id: 969663, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000104', type: 'barcodes' } } } }, { id: '969662', type: 'items', attributes: { id: 969662, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000103', type: 'barcodes' } } } }, { id: '969661', type: 'items', attributes: { id: 969661, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000102', type: 'barcodes' } } } }, { id: '969660', type: 'items', attributes: { id: 969660, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000101', type: 'barcodes' } } } }, { id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'preprinted' } }, { id: '6425', type: 'zones', attributes: { id: 6425, facility_id: 1568, name: 'Flowering', slug: 'flowering', zone_type: 'generic', created_at: '2019-09-12T19: 56: 28.548Z', updated_at: '2019-09-12T19: 56: 28.548Z', status: 'active', position: nil, size: 0, seeding_unit: { id: 3479, name: 'Plant (barcoded)', zones: [{ id: 6122, slug: 'clone-room', name: 'Clone Room', seeding_unit_id: 3479, zone_type: 'trays', sub_zones: [] }, { id: 6425, slug: 'flowering', name: 'Flowering', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6431, slug: 'flowering-field', name: 'Flowering Field', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6429, slug: 'flowering-greenhouse', name: 'Flowering Greenhouse', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6666, slug: 'flower-room-barcoded', name: 'Flower Room Barcoded', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6422, slug: 'mothers', name: 'Mothers', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6434, slug: 'mothers', name: 'Mothers', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6427, slug: 'propagation', name: 'Propagation', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6424, slug: 'vegetation', name: 'Vegetation', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6430, slug: 'vegetation-field', name: 'Vegetation Field', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6428, slug: 'vegetation-greenhouse', name: 'Vegetation Greenhouse', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6665, slug: 'veg-room-barcoded', name: 'Veg Room Barcoded', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }], secondary_display_active: nil, secondary_display_capacity: nil }, seeding_unit_capacity: 0, system: 'None' }, relationships: { sub_zones: { meta: { included: false } }, seeding_unit: { meta: { included: false } } } }] }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/96182?include=zone,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone')
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16: 00: 00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { data: [] }, completions: { data: [{ type: 'completions', id: '652633' }] }, items: { data: [{ type: 'items', id: '969664' }, { type: 'items', id: '969663' }, { type: 'items', id: '969662' }, { type: 'items', id: '969661' }, { type: 'items', id: '969660' }] }, custom_data: { data: [] }, barcodes: { data: [{ id: '1A4FF010000002200000211' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { data: nil }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { data: { id: nil, type: 'sub_zones' } } } }, included: [{ id: '652633', type: 'completions', attributes: { id: 652633, user_id: 1598, content: nil, start_time: '2019-10-01T16: 00: 00.000Z', end_time: '2019-10-01T16: 00: 00.000Z', occurrence: nil, action_type: 'batch', options: { zone_id: 6422, quantity: '5', arbitrary_id: 'Oct1-Ban-Spl-Can', growth_cycle_id: 11417, seeding_unit_id: 3479, tracking_barcode: '1A4FF01000000220000010', arbitrary_id_base: 'Ban-Spl-Can' } }, relationships: { action_result: { data: { id: 96182, type: 'CropBatch' } }, batch: { data: { id: '96182', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }, { id: '969664', type: 'items', attributes: { id: 969664, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000105', type: 'barcodes' } } } }, { id: '969663', type: 'items', attributes: { id: 969663, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000104', type: 'barcodes' } } } }, { id: '969662', type: 'items', attributes: { id: 969662, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000103', type: 'barcodes' } } } }, { id: '969661', type: 'items', attributes: { id: 969661, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000102', type: 'barcodes' } } } }, { id: '969660', type: 'items', attributes: { id: 969660, harvest_quantity: 0, secondary_harvest_quantity: 0, status: 'removed', secondary_harvest_unit: nil }, relationships: { batch: { meta: { included: false } }, seeding_unit: { meta: { included: false } }, harvest_unit: { meta: { included: false } }, barcode: { data: { id: '1A4FF010000002200000101', type: 'barcodes' } } } }, { id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'preprinted' } }, { id: '6425', type: 'zones', attributes: { id: 6425, facility_id: 1568, name: 'Flowering', slug: 'flowering', zone_type: 'generic', created_at: '2019-09-12T19: 56: 28.548Z', updated_at: '2019-09-12T19: 56: 28.548Z', status: 'active', position: nil, size: 0, seeding_unit: { id: 3479, name: 'Plant (barcoded)', zones: [{ id: 6122, slug: 'clone-room', name: 'Clone Room', seeding_unit_id: 3479, zone_type: 'trays', sub_zones: [] }, { id: 6425, slug: 'flowering', name: 'Flowering', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6431, slug: 'flowering-field', name: 'Flowering Field', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6429, slug: 'flowering-greenhouse', name: 'Flowering Greenhouse', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6666, slug: 'flower-room-barcoded', name: 'Flower Room Barcoded', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6422, slug: 'mothers', name: 'Mothers', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6434, slug: 'mothers', name: 'Mothers', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6427, slug: 'propagation', name: 'Propagation', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6424, slug: 'vegetation', name: 'Vegetation', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6430, slug: 'vegetation-field', name: 'Vegetation Field', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6428, slug: 'vegetation-greenhouse', name: 'Vegetation Greenhouse', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }, { id: 6665, slug: 'veg-room-barcoded', name: 'Veg Room Barcoded', seeding_unit_id: 3479, zone_type: 'generic', sub_zones: [] }], secondary_display_active: nil, secondary_display_capacity: nil }, seeding_unit_capacity: 0, system: 'None' }, relationships: { sub_zones: { meta: { included: false } }, seeding_unit: { meta: { included: false } } } }] }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/completions?filter[crop_batch_ids][]=96182')
          .to_return(body: { data: [{ id: '12345', type: 'completions', attributes: { id: 12345, action_type: 'move' } }, { id: '12346', type: 'completions', attributes: { id: 12346, action_type: 'process', options: { resource_unit_id: 99, processed_quantity: 4000 } } }, { id: '12347', type: 'completions', attributes: { id: 12346, action_type: 'process', options: { resource_unit_id: 100, processed_quantity: 50 } } }] }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/resource_units')
          .to_return(body: { data: [{ id: '99', type: 'resource_units', attributes: { id: 99, conversion_si: 1.0, kind: 'weight', name: 'g Wet Material - Banana Split' } }, { id: '100', type: 'resource_units', attributes: { id: 100, conversion_si: 1.0, kind: 'weight', name: 'g Waste - Banana Split' } }] }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/96182/items?filter[seeding_unit_id]=3479&include=barcodes,seeding_unit')
          .to_return(body: { data: [{ id: '969664', type: 'items', attributes: { id: 969664, harvest_quantity: 0, secondary_harvest_quantity: 10.0, secondary_harvest_unit: 'Grams', harvest_unit: 'Grams' }, relationships: { barcode: { data: { id: '1A4FF010000002200000105', type: 'barcodes' } } } }, { id: '969663', type: 'items', attributes: { id: 969663, harvest_quantity: 0, secondary_harvest_quantity: 10.0, secondary_harvest_unit: 'Grams', harvest_unit: 'Grams' }, relationships: { barcode: { data: { id: '1A4FF010000002200000104', type: 'barcodes' } } } }, { id: '969662', type: 'items', attributes: { id: 969662, harvest_quantity: 0, secondary_harvest_quantity: 10.0, secondary_harvest_unit: 'Grams', harvest_unit: 'Grams' }, relationships: { barcode: { data: { id: '1A4FF010000002200000103', type: 'barcodes' } } } }] }.to_json)

        stub_request(:post, "#{ENV['NCS_BASE_URI']}/pos/harvests/v1/create")
          .with(
            body: [ { Name: 'Oct1-Ban-Spl-Can', HarvestType: 'Product', DryingRoomName: 'Flowering', UnitOfWeightName: 'Grams', HarvestStartDate: '2019-11-13T18:44:45' } ].to_json,
            headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ABC1234567890' }
          )
          .to_return(status: 200, body: '{}', headers: {})

        stub_request(:post, "#{ENV['NCS_BASE_URI']}/pos/plants/v1/harvestplants")
          .with(
            body: [{ Label: '1A4FF010000002200000105', HarvestedWetWeight: 1333.33, HarvestedUnitOfWeightName: 'Grams', RoomName: 'Flowering', HarvestName: 'Oct1-Ban-Spl-Can', ManicuredDate: '2019-11-13T18:44:45' }, { Label: '1A4FF010000002200000104', HarvestedWetWeight: 1333.33, HarvestedUnitOfWeightName: 'Grams', RoomName: 'Flowering', HarvestName: 'Oct1-Ban-Spl-Can', ManicuredDate: '2019-11-13T18:44:45' }, { Label: '1A4FF010000002200000103', HarvestedWetWeight: 1333.33, HarvestedUnitOfWeightName: 'Grams', RoomName: 'Flowering', HarvestName: 'Oct1-Ban-Spl-Can', ManicuredDate: '2019-11-13T18:44:45' }].to_json,
            headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ABC1234567890' }
          )
          .to_return(status: 200, body: '{}', headers: {})

        stub_request(:get, "#{ENV['NCS_BASE_URI']}/pos/harvests/v1/active")
          .with(headers: { Authorization: 'Bearer ABC1234567890', 'Content-Type': 'application/json' })
          .to_return(status: 200, body: [{ Id: 100, Name: 'Oct1-Ban-Spl-Can' }].to_json, headers: {})

        stub_request(:post, "#{ENV['NCS_BASE_URI']}/pos/harvests/v1/removewaste")
          .with(
            body: [{ Id: 100, UnitOfWeightName: 'Grams', TotalWasteWeight: 50, FinishedDate: '2019-11-13T18:44:45' }].to_json,
            headers: {
              Authorization: 'Bearer ABC1234567890',
              'Content-Type': 'application/json'
            })
          .to_return(status: 200, body: '{}', headers: {})
      end

      it { is_expected.to be_success }
    end
  end

  xdescribe '#calculate_average_weight' do
    let(:non_zero_items) do
      _items = [] # rubocop:disable Lint/UnderscorePrefixedVariableName
      10.times { _items << double(:item, attributes: { secondary_harvest_quantity: rand(1.0..10.0) }.with_indifferent_access) }
      _items
    end

    let(:zeroed_items) do
      _items = [] # rubocop:disable Lint/UnderscorePrefixedVariableName
      10.times { _items << double(:item, attributes: { secondary_harvest_quantity: 0 }.with_indifferent_access) }
      _items
    end

    subject { described_class.new(ctx, integration) }

    it 'calculates the secondary harvest quantity average weight with values greater than zero' do
      average = subject.send :calculate_average_weight, non_zero_items

      expect(average).not_to be_nil
      expect(average).to be > 0
    end

    it 'return zero when the calculation is zero' do
      average = subject.send :calculate_average_weight, zeroed_items

      expect(average).not_to be_nil
      expect(average).to eq 0
    end
  end

  xdescribe '#build_harvest_plants_payload' do
    let(:items) do
      10.times.map do
        double(
          :item,
          attributes: {
            resource_unit_id: 1,
            secondary_harvest_quantity: 10.0
          }.with_indifferent_access,
          relationships: {
            barcode: {
              data: {
                id: Faker::Alphanumeric.unique.alphanumeric(number: 6)
              }
            }
          }.with_indifferent_access
        )
      end
    end

    let(:ctx) do
      {
        'attributes': {
          'action_type': 'harvest',
          'content': { 'crop_batch_item_ids': [2083, 2084, 2085, 2086, 2087, 2088, 2089, 2090, 2091, 2092] },
          'end_time': '2020-06-23T04:00:00.000Z',
          'id': 2351,
          'occurrence': 0,
          'options': {
            'calculated_quantity': 10.0,
            'harvest_type': 'complete',
            'harvest_unit_id': 12,
            'quantity_remaining': 10,
            'resources': [
              { 'generated_quantity': 46.3125, 'resource_unit_id': 25 },
              { 'generated_quantity': 46.3125, 'resource_unit_id': 24 },
              { 'processed_quantity': 7.5, 'resource_unit_id': 19 },
              { 'processed_quantity': 1.875, 'resource_unit_id': 20 }
            ],
            'seeding_unit_id': 8
          },
          'start_time': '2020-02-23T05:00:00.000Z',
          'user_id': 20
        },
        'id': '2351',
        'relationships': {
          'batch': { 'data': { 'id': '371', 'type': 'batches' } },
          'facility': { 'data': { 'id': 2, 'type': 'facilities' } }
        },
        'type': 'completions'
      }
    end

    let(:batch) { double(:batch, arbitrary_id: 'Oct1-Ban-Spl-Can') }

    subject { described_class.new(ctx, integration) }

    it 'returns a valid payload' do
      allow(subject).to receive(:calculate_average_weight).and_return 10.0
      payload = subject.send :build_harvest_plants_payload, items, batch

      expect(subject).to have_received(:calculate_average_weight).with(items)
      expect(payload).not_to be_nil
      expect(payload.size).to be 10

      payload.each do |item|
        expect(item[:PatientLicenseNumber]).to be_nil
        expect(item[:DryingLocation]).to eq 'The Red Keep'
        expect(item[:ActualDate]).to be start_time
        expect(item[:Plant]).not_to be_nil
        expect(item[:Weight]).to eq 10.0
        expect(item[:UnitOfWeight]).to eq 'Grams'
        expect(item[:HarvestName]).to eq 'Oct1-Ban-Spl-Can'
      end
    end
  end

  xdescribe '#build_manicure_plants_payload' do
    let(:items) do
      _items = [] # rubocop:disable Lint/UnderscorePrefixedVariableName
      10.times do
        _items << double(:item, attributes: {
          secondary_harvest_quantity: 10.0,
          secondary_harvest_unit: 'Grams'
        }.with_indifferent_access,
                                relationships: {
                                  barcode: {
                                    data: {
                                      id: Faker::Alphanumeric.unique.alphanumeric(number: 6)
                                    }
                                  }
                                }.with_indifferent_access)
      end

      _items
    end

    let(:start_time) { Time.now.utc - 1.hour }

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
          start_time: start_time,
          options: {
            zone_name: 'The Red Keep'
          }
        },
        completion_id: 1001
      }
    end

    let(:batch) { double(:batch, arbitrary_id: 'Oct1-Ban-Spl-Can') }

    subject { described_class.new(ctx, integration) }

    it 'returns a valid payload' do
      allow(subject).to receive(:calculate_average_weight).and_return 10.0
      payload = subject.send :build_manicure_plants_payload, items, batch

      expect(subject).to have_received(:calculate_average_weight).with(items)
      expect(payload).not_to be_nil
      expect(payload.size).to be 10

      payload.each do |item|
        expect(item[:Label]).not_to be_nil
        expect(item[:ManicuredWeight]).to eq 10.0
        expect(item[:ManicuredUnitOfWeightName]).to eq 'Grams'
        expect(item[:RoomName]).to eq 'The Red Keep'
        expect(item[:HarvestName]).to be_nil
        expect(item[:ManicuredDate]).to be start_time
      end
    end
  end
end
