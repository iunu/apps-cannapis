require 'rails_helper'

RSpec.describe MetrcService::Plant::Discard do
  describe 'MA discards' do
    let(:account) { create(:account) }
    let(:integration) { create(:integration, account: account, state: :ma) }
    let(:ctx) do
      {
        id: 3000,
        relationships: {
          batch: { data: { id: 2002 } },
          facility: { data: { id: 1568 } }
        },
        attributes: {
          options: {
            barcode: ['1A4060300003B01000000838'],
            note_content: 'And the only prescription is moar cow bell',
            calculated_quantity: '5'
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
          .and_return transaction
      end

      describe 'on an old successful transaction' do
        let(:transaction) { create(:transaction, :successful, :discard, account: account, integration: integration) }
        it { is_expected.to eq(transaction) }
      end

      describe 'with corn crop' do
        include_examples 'with corn crop'
      end

      describe 'on a different tracking method' do
        let(:ctx) do
          {
            id: 3000,
            relationships: {
              batch: { data: { id: 2002 } },
              facility: { data: { id: 1568 } },
              action_result: { data: { id: 111436 } }
            },
            attributes: {
              options: {
                barcode: ['1A4FF01000000220000010'],
                note_content: 'And the only prescription is moar cow bell'
              }
            },
            completion_id: 1001
          }.with_indifferent_access
        end
        let(:transaction) { create(:transaction, :unsuccessful, :discard, account: account, integration: integration) }

        before do
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568")
            .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
            .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'custom_prefix' } }] }.to_json)

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002")
            .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'custom_prefix' } }] }.to_json)
        end

        # FIXME
        # it skip: 'FIXME' { is_expected.to be_nil }
      end

      describe 'on a complete discard' do
        batch_id = 96182
        let(:ctx) do
          {
            id: 3000,
            relationships: {
              batch: { data: { id: batch_id } },
              facility: { data: { id: 1568 } },
              action_result: { data: { id: 111436 } }
            },
            attributes: {
              options: {
                barcode: %w[1A4FF010000002200000105 1A4FF010000002200000104 1A4FF010000002200000103],
                note_content: 'And the only prescription is moar cow bell'
              }
            },
            completion_id: 1001
          }.with_indifferent_access
        end
        let(:transaction) { create(:transaction, :unsuccessful, :discard, account: account, integration: integration) }

        before do
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568")
            .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/96182?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
            .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'preprinted' } }] }.to_json)

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/96182")
            .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { data: [] }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'preprinted' } }] }.to_json)

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/")
            .to_return(body: { data: [{ id: '1001', type: 'discards', attributes: { id: 1001, quantity: 5, options: { reason_type: 'mandated', reason_description: nil }, start_time: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111435', type: 'discards', attributes: { id: 111435, quantity: 5, reason_type: 'other', reason_description: 'I don\'t like them', start_time: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96219', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111423', type: 'discards', attributes: { id: 111423, quantity: 1, reason_type: 'other', reason_description: 'I have a fever', start_time: '2019-10-04T00:00:00.000Z' }, relationships: { batch: { data: { id: '96182', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111331', type: 'discards', attributes: { id: 111331, quantity: 1, reason_type: 'mandated', reason_description: nil, start_time: '2019-10-03T00:00:00.000Z' }, relationships: { batch: { data: { id: '95956', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '33550', type: 'discards', attributes: { id: 33550, quantity: 1, reason_type: 'mandated', reason_description: nil, start_time: '2019-09-01T00:00:00.000Z' }, relationships: { batch: { data: { id: '83397', type: 'batches' } }, completion: { meta: { included: false } } } }] }.to_json)

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/3000?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
            .to_return(body: load_response_json('api/completions/3000'))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/1001?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
            .to_return(body: { data: { id: '1001', type: 'discards', attributes: { id: 1001, quantity: 5, options: { reason_type: 'mandated', reason_description: nil }, start_time: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } } }.to_json)

          # TODO: return generate completion
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions?filter[crop_batch_ids][]=96182")
            .to_return(body: { data: [] }.to_json)

          stub_request(:post, 'https://sandbox-api-ma.metrc.com/plants/v1/destroyplants?licenseNumber=LIC-0001')
            .with(
              body: [
                { Id: nil,
                  Label: '1A4FF010000002200000105',
                  WasteMethodName: 'Made Unrecognizable & Unusable',
                  WasteMaterialMixed: 'None',
                  WasteWeight: 0.0,
                  WasteUnitOfMeasureName: '',
                  WasteReasonName: 'Waste',
                  ReasonNote: 'Waste',
                  ActualDate: '2020-03-30T07:00:00.000Z' },
                { Id: nil,
                  Label: '1A4FF010000002200000104',
                  WasteMethodName: 'Made Unrecognizable & Unusable',
                  WasteMaterialMixed: 'None',
                  WasteWeight: 0.0,
                  WasteUnitOfMeasureName: '',
                  WasteReasonName: 'Waste',
                  ReasonNote: 'Waste',
                  ActualDate: '2020-03-30T07:00:00.000Z' },
                { Id: nil,
                  Label: '1A4FF010000002200000103',
                  WasteMethodName: 'Made Unrecognizable & Unusable',
                  WasteMaterialMixed: 'None',
                  WasteWeight: 0.0,
                  WasteUnitOfMeasureName: '',
                  WasteReasonName: 'Waste',
                  ReasonNote: 'Waste',
                  ActualDate: '2020-03-30T07:00:00.000Z' }
              ].to_json
            )
            .to_return(status: 200, body: '', headers: {})

          expect_any_instance_of(described_class)
            .not_to receive(:get_transaction)
        end

        it { is_expected.to be_success }
      end

      describe 'on a partial discard' do
        let(:ctx) do
          {
            id: 3000,
            relationships: {
              batch: { data: { id: 2002 } },
              facility: { data: { id: 1568 } },
              action_result: { data: { id: 111436 } }
            },
            attributes: {
              options: {
                note_content: 'And the only prescription is moar cow bell',
                calculated_quantity: '5'
              }
            },
            completion_id: 1001
          }.with_indifferent_access
        end
        let(:transaction) { create(:transaction, :unsuccessful, :discard, account: account, integration: integration) }

        before do
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568")
            .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
            .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: nil } }] }.to_json)

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002")
            .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: nil } }] }.to_json)

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/")
            .to_return(body: { data: [{ id: '111436', type: 'discards', attributes: { id: 111436, quantity: 5, options: { reason_type: 'mandated', reason_description: nil }, start_time: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111435', type: 'discards', attributes: { id: 111435, quantity: 5, reason_type: 'other', reason_description: 'I don\'t like them', start_time: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96219', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111423', type: 'discards', attributes: { id: 111423, quantity: 1, reason_type: 'other', reason_description: 'I have a fever', start_time: '2019-10-04T00:00:00.000Z' }, relationships: { batch: { data: { id: '96182', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111331', type: 'discards', attributes: { id: 111331, quantity: 1, reason_type: 'mandated', reason_description: nil, start_time: '2019-10-03T00:00:00.000Z' }, relationships: { batch: { data: { id: '95956', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '33550', type: 'discards', attributes: { id: 33550, quantity: 1, reason_type: 'mandated', reason_description: nil, start_time: '2019-09-01T00:00:00.000Z' }, relationships: { batch: { data: { id: '83397', type: 'batches' } }, completion: { meta: { included: false } } } }] }.to_json)

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/3000?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
            .to_return(body: load_response_json('api/completions/3000'))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/111436?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
            .to_return(body: { data: { id: '111436', type: 'discards', attributes: { id: 111436, quantity: 5, options: { reason_type: 'mandated', reason_description: nil }, start_time: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } } }.to_json)

          stub_request(:post, 'https://sandbox-api-ma.metrc.com/plantbatches/v1/destroy?licenseNumber=LIC-0001')
            .with(
              body: [
                {
                  PlantBatch: '1A4060300003B01000000838',
                  Count: 5,
                  ReasonNote: 'Waste',
                  ActualDate: '2020-03-30T07:00:00.000Z'
                }
              ].to_json
            )
            .to_return(status: 200, body: '', headers: {})
        end

        it { is_expected.to be_success }
      end
    end

    describe '#build_immature_payload' do
      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568")
          .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002")
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'custom_prefix' } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'custom_prefix' } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/")
          .to_return(body: { data: [{ id: '111436', type: 'discards', attributes: { id: 111436, quantity: 5, options: { reason_type: 'mandated', reason_description: nil }, start_time: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111435', type: 'discards', attributes: { id: 111435, quantity: 5, reason_type: 'mandated', reason_description: 'I don\'t like them', start_time: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96219', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111423', type: 'discards', attributes: { id: 111423, quantity: 1, reason_type: 'mandated', reason_description: 'I have a fever', start_time: '2019-10-04T00:00:00.000Z' }, relationships: { batch: { data: { id: '96182', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111331', type: 'discards', attributes: { id: 111331, quantity: 1, reason_type: 'mandated', reason_description: nil, start_time: '2019-10-03T00:00:00.000Z' }, relationships: { batch: { data: { id: '95956', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '33550', type: 'discards', attributes: { id: 33550, quantity: 1, reason_type: 'mandated', reason_description: nil, start_time: '2019-09-01T00:00:00.000Z' }, relationships: { batch: { data: { id: '83397', type: 'batches' } }, completion: { meta: { included: false } } } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/3000?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
          .to_return(body: { data: { id: '3000', type: 'discards', attributes: { id: 3000, quantity: 5, options: { reason_type: 'mandated', reason_description: nil }, start_time: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } } }.to_json)
      end

      subject { described_class.new(ctx, integration) }

      it 'returns a valid payload' do
        payload = subject.send :build_immature_payload

        expect(payload.size).to eq 1
        expect(payload.first).to eq(
          PlantBatch: '1A4060300003B01000000838',
          Count: 5,
          ReasonNote: 'Waste',
          ActualDate: '2019-10-25T00:00:00.000Z'
        )
      end
    end

    describe '#build_mature_payload' do
      let(:ctx) do
        {
          id: 652810,
          relationships: {
            batch: { data: { id: 96182 } },
            facility: { data: { id: 1568 } }
          },
          attributes: {
            options: {
              barcode: [
                'A4FF010000002200000101',
                'A4FF010000002200000102',
                'A4FF010000002200000103',
                'A4FF010000002200000104',
                'A4FF010000002200000105'
              ],
              resources: [
                {
                  index: 0,
                  strategy: 'manual',
                  resource_unit_id: 22,
                  generated_quantity: 100
                }
              ],
              calculated_quantity: 1,
              reason_type: 'undesirable',
              discard_type: 'partial',
              note_content: 'The only prescription is more cowbell'
            }
          },
          completion_id: 1001
        }.with_indifferent_access
      end

      context 'with waste resources' do
        before do
          # get facility
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568")
            .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

          # get batch
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/96182?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
            .to_return(body: load_response_json('api/1568-facility/batches/96182-batch'))

          # get facility completions
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/")
            .to_return(body: { data: [
              JSON.parse(load_response_json('api/1568-facility/completions/652799-start'))['data'],
              JSON.parse(load_response_json('api/1568-facility/completions/652800-move'))['data'],
              JSON.parse(load_response_json('api/1568-facility/completions/652801-move'))['data'],
              JSON.parse(load_response_json('api/1568-facility/completions/652802-partial-harvest'))['data'],
              JSON.parse(load_response_json('api/1568-facility/completions/652810-discard'))['data'],
              JSON.parse(load_response_json('api/1568-facility/completions/652811-generate-waste'))['data']
            ] }.to_json)

          # get discard completion
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/652810?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
            .to_return(body: load_response_json('api/1568-facility/completions/652810-discard'))

          # get generate waste completion
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions?filter[crop_batch_ids][]=96182")
            .to_return(body: { data: [
              JSON.parse(load_response_json('api/1568-facility/completions/652811-generate-waste'))['data']
            ] }.to_json)

          # get resource unit
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/resource_units/22?include=crop_variety")
            .to_return(body: load_response_json('api/sync/facilities/1/resource_units/22'))
        end

        subject { described_class.new(ctx, integration) }

        it 'returns a valid payload' do
          payload = subject.send :build_mature_payload

          expect(payload.size).to eq 5
          expect(payload.first).to eq(
            Id: nil,
            Label: 'A4FF010000002200000101',
            WasteMethodName: 'Made Unrecognizable & Unusable',
            WasteMaterialMixed: 'None',
            WasteWeight: 20,
            WasteUnitOfMeasureName: 'Grams',
            WasteReasonName: 'Waste',
            ReasonNote: 'Waste: The only prescription is more cowbell.',
            ActualDate: '2019-10-04T04:00:00.000Z'
          )
        end
      end
    end
  end

  describe 'CA discards' do
    let(:account) { create(:account) }
    let(:integration) { create(:integration, account: account, state: :ca) }
    describe '#build_mature_payload with resources' do
      let(:ctx) do
        {
          id: 652810,
          relationships: {
            batch: { data: { id: 96182 } },
            facility: { data: { id: 1568 } }
          },
          attributes: {
            options: {
              barcode: [
                'A4FF010000002200000101',
                'A4FF010000002200000102',
                'A4FF010000002200000103',
                'A4FF010000002200000104',
                'A4FF010000002200000105'
              ],
              resources: [
                {
                  index: 0,
                  strategy: 'manual',
                  resource_unit_id: 22,
                  generated_quantity: 100
                }
              ],
              calculated_quantity: 1,
              reason_type: 'undesirable',
              discard_type: 'partial',
              note_content: 'The only prescription is more cowbell'
            }
          },
          completion_id: 1001
        }.with_indifferent_access
      end

      context 'returns valid payload' do
        before do
          # get facility
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568")
            .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

          # get batch
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/96182?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,sub_zone,custom_data.custom_field")
            .to_return(body: load_response_json('api/1568-facility/batches/96182-batch'))

          # get facility completions
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/")
            .to_return(body: { data: [
              JSON.parse(load_response_json('api/1568-facility/completions/652799-start'))['data'],
              JSON.parse(load_response_json('api/1568-facility/completions/652800-move'))['data'],
              JSON.parse(load_response_json('api/1568-facility/completions/652801-move'))['data'],
              JSON.parse(load_response_json('api/1568-facility/completions/652802-partial-harvest'))['data'],
              JSON.parse(load_response_json('api/1568-facility/completions/652810-discard'))['data'],
              JSON.parse(load_response_json('api/1568-facility/completions/652811-generate-waste'))['data']
            ] }.to_json)

          # get discard completion
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions/652810?include=action_result,crop_batch_state,crop_batch_state.seeding_unit,crop_batch_state.zone.sub_stage")
            .to_return(body: load_response_json('api/1568-facility/completions/652810-discard'))

          # get generate waste completion
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/completions?filter[crop_batch_ids][]=96182")
            .to_return(body: { data: [
              JSON.parse(load_response_json('api/1568-facility/completions/652811-generate-waste'))['data']
            ] }.to_json)

          # get resource unit
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/resource_units/22?include=crop_variety")
            .to_return(body: load_response_json('api/sync/facilities/1/resource_units/22'))
        end

        subject { described_class.new(ctx, integration) }

        it 'returns the correct payload' do
          payload = subject.send :build_mature_payload

          expect(payload.size).to eq 5
          expect(payload.first).to eq(
            Id: nil,
            Label: 'A4FF010000002200000101',
            WasteMethodName: 'Waste-Hauler',
            WasteMaterialMixed: 'None',
            WasteWeight: 20.0,
            WasteUnitOfMeasureName: 'Grams',
            WasteReasonName: 'Male Plants',
            ReasonNote: 'Male Plants: The only prescription is more cowbell.',
            ActualDate: '2019-10-04T04:00:00.000Z'
          )
        end
      end
    end
  end
end
