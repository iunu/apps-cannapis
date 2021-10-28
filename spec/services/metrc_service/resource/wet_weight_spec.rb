require 'rails_helper'

RSpec.describe MetrcService::Resource::WetWeight do
  let(:account) { create(:account) }
  let(:integration) { create(:integration, account: account, state: :md) }
  let(:ctx) do
    {
      id: 2239,
      relationships: {
        batch: { data: { id: 2002 } },
        facility: { data: { id: 1568 } },
        action_result: { data: { id: 200 } }
      },
      attributes: {
        content: {
          crop_batch_item_ids: [969664, 969663, 969662]
        },
        action_type: 'generate',
        options: {
          resource_unit_id: 297,
          generated_quantity: 50,
          zone_name: 'Bay 02'
        }
      },
      completion_id: 2239
    }.with_indifferent_access
  end

  describe '#call' do
    context 'with removed items on batch' do
      let(:expected_payload) do
        [
          {
            DryingLocation: 'Room',
            PatientLicenseNumber: nil,
            ActualDate: nil,
            Plant: '1A4FF010000002200000105',
            Weight: 0.0,
            UnitOfWeight: 'Grams',
            HarvestName: 'Oct1-Ban-Spl-Can'
          },
          {
            DryingLocation: 'Room',
            PatientLicenseNumber: nil,
            ActualDate: nil,
            Plant: '1A4FF010000002200000104',
            Weight: 0.0,
            UnitOfWeight: 'Grams',
            HarvestName: 'Oct1-Ban-Spl-Can'
          },
          {
            DryingLocation: 'Room',
            PatientLicenseNumber: nil,
            ActualDate: nil,
            Plant: '1A4FF010000002200000103',
            Weight: 0.0,
            UnitOfWeight: 'Grams',
            HarvestName: 'Oct1-Ban-Spl-Can'
          }
        ]
      end
      subject { described_class.call(ctx, integration) }

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568")
          .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002")
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: nil } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: nil } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/resource_units?include=crop_variety")
          .to_return(body: { data: [{ id: '99', type: 'resource_units', attributes: { id: 99, conversion_si: 1.0, kind: 'weight', name: 'g Wet Weight - Banana Split', unit_name: 'Gram', product_modifier: 'Wet Weight', options: { } }, relationships: { crop_variety: { data: { type: 'crop_varieties', id: 1 } } } }, { id: '100', type: 'resource_units', attributes: { id: 100, conversion_si: 1.0, kind: 'weight', name: 'g Waste - Banana Split', unit_name: 'Gram', product_modifier: 'Wet Waste', options: {} }, relationships: { crop_variety: { data: { type: 'crop_varieties', id: 1 } } } }], included: [{ type: 'crop_varieties', id: 1, attributes: { name: 'Banana Split' } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions?filter%5Bcrop_batch_ids%5D%5B0%5D=96182")
          .to_return(body:
            { data: [{ id: '652633', type: 'completions', attributes: { id: 652633, user_id: 1598, content: nil, start_time: '2019-10-01T16: 00: 00.000Z', end_time: '2019-10-01T16: 00: 00.000Z', occurrence: nil, action_type: 'batch', status: 'active', options: { zone_id: 6422, quantity: '5', arbitrary_id: 'Oct1-Ban-Spl-Can', growth_cycle_id: 11417, seeding_unit_id: 3479, tracking_barcode: '1A4FF01000000220000010', arbitrary_id_base: 'Ban-Spl-Can' } }, relationships: { action_result: { data: { id: 96182, type: 'CropBatch' } }, batch: { data: { id: '96182', type: 'batches' } }, facility: { data: { id: 1568, type: 'facilities' } }, user: { data: { id: 1598, type: 'users' } } } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/2239?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: load_response_json('api/completions/2239-generate'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/zones/6425")
          .to_return(body: {
            data: { id: '6425', type: 'zones', attributes: { id: 6425, name: 'Room' } }
          }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/resource_units/?include=crop_variety")
          .to_return(status: 200, body: load_response_json('api/sync/facilities/1/resource_units'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/resource_units/297?include=crop_variety")
          .to_return(status: 200, body: load_response_json('api/sync/facilities/1/resource_units/8'))

        stub_request(:post, 'https://sandbox-api-md.metrc.com/plants/v1/harvestplants?licenseNumber=LIC-0001')
          .with(body: expected_payload.to_json)
          .to_return(status: 200, body: '', headers: {})
      end

      it 'is successful with active items' do
        expect(subject).to be_success
      end
    end
  end
end
