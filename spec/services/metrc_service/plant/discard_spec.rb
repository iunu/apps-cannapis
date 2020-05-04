require 'rails_helper'

RSpec.describe MetrcService::Plant::Discard do
  METRC_API_KEY = ENV['METRC_SECRET_MD'] unless defined?(METRC_API_KEY)

  let(:account) { create(:account) }
  let(:integration) { create(:integration, account: account, state: :md) }
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
              tracking_barcode: '1A4FF01000000220000010',
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

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { meta: { included: false } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'custom_prefix' } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002")
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { meta: { included: false } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'custom_prefix' } }] }.to_json)
      end

      # FIXME
      # it skip: 'FIXME' { is_expected.to be_nil }
    end

    describe 'on a complete discard' do
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
              tracking_barcode: '1A4FF01000000220000010',
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

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { meta: { included: false } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'preprinted' } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002")
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { meta: { included: false } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'preprinted' } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/discards/")
          .to_return(body: { data: [{ id: '111436', type: 'discards', attributes: { id: 111436, quantity: 5, reason_type: 'disease', reason_description: nil, discarded_at: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111435', type: 'discards', attributes: { id: 111435, quantity: 5, reason_type: 'other', reason_description: 'I don\'t like them', discarded_at: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96219', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111423', type: 'discards', attributes: { id: 111423, quantity: 1, reason_type: 'other', reason_description: 'I have a fever', discarded_at: '2019-10-04T00:00:00.000Z' }, relationships: { batch: { data: { id: '96182', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111331', type: 'discards', attributes: { id: 111331, quantity: 1, reason_type: 'disease', reason_description: nil, discarded_at: '2019-10-03T00:00:00.000Z' }, relationships: { batch: { data: { id: '95956', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '33550', type: 'discards', attributes: { id: 33550, quantity: 1, reason_type: 'disease', reason_description: nil, discarded_at: '2019-09-01T00:00:00.000Z' }, relationships: { batch: { data: { id: '83397', type: 'batches' } }, completion: { meta: { included: false } } } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/discards/111436")
          .to_return(body: { data: { id: '111436', type: 'discards', attributes: { id: 111436, quantity: 5, reason_type: 'disease', reason_description: nil, discarded_at: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } } }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/96182/items?filter[seeding_unit_id]=3479&include=barcodes,seeding_unit")
          .to_return(body: { data: [{ id: '969664', type: 'items', attributes: { id: 969664, harvest_quantity: 0, secondary_harvest_quantity: 10.0, secondary_harvest_unit: 'Grams', harvest_unit: 'Grams' }, relationships: { barcode: { data: { id: '1A4FF010000002200000105', type: 'barcodes' } } } }, { id: '969663', type: 'items', attributes: { id: 969663, harvest_quantity: 0, secondary_harvest_quantity: 10.0, secondary_harvest_unit: 'Grams', harvest_unit: 'Grams' }, relationships: { barcode: { data: { id: '1A4FF010000002200000104', type: 'barcodes' } } } }, { id: '969662', type: 'items', attributes: { id: 969662, harvest_quantity: 0, secondary_harvest_quantity: 10.0, secondary_harvest_unit: 'Grams', harvest_unit: 'Grams' }, relationships: { barcode: { data: { id: '1A4FF010000002200000103', type: 'barcodes' } } } }] }.to_json)

        stub_request(:post, 'https://sandbox-api-md.metrc.com/plants/v1/destroyplants?licenseNumber=LIC-0001')
          .with(
            body: [{ Id: nil, Label: '1A4FF010000002200000105', ReasonNote: described_class::NOT_SPECIFIED, ActualDate: '2019-10-25T00:00:00.000Z' }, { Id: nil, Label: '1A4FF010000002200000104', ReasonNote: described_class::NOT_SPECIFIED, ActualDate: '2019-10-25T00:00:00.000Z' }, { Id: nil, Label: '1A4FF010000002200000103', ReasonNote: described_class::NOT_SPECIFIED, ActualDate: '2019-10-25T00:00:00.000Z' }].to_json,
            basic_auth: [METRC_API_KEY, integration.secret]
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
              tracking_barcode: '1A4FF01000000220000010',
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

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { meta: { included: false } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: nil } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002")
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { meta: { included: false } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: nil } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/discards/")
          .to_return(body: { data: [{ id: '111436', type: 'discards', attributes: { id: 111436, quantity: 5, reason_type: 'disease', reason_description: nil, discarded_at: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111435', type: 'discards', attributes: { id: 111435, quantity: 5, reason_type: 'other', reason_description: 'I don\'t like them', discarded_at: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96219', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111423', type: 'discards', attributes: { id: 111423, quantity: 1, reason_type: 'other', reason_description: 'I have a fever', discarded_at: '2019-10-04T00:00:00.000Z' }, relationships: { batch: { data: { id: '96182', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111331', type: 'discards', attributes: { id: 111331, quantity: 1, reason_type: 'disease', reason_description: nil, discarded_at: '2019-10-03T00:00:00.000Z' }, relationships: { batch: { data: { id: '95956', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '33550', type: 'discards', attributes: { id: 33550, quantity: 1, reason_type: 'disease', reason_description: nil, discarded_at: '2019-09-01T00:00:00.000Z' }, relationships: { batch: { data: { id: '83397', type: 'batches' } }, completion: { meta: { included: false } } } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/discards/111436")
          .to_return(body: { data: { id: '111436', type: 'discards', attributes: { id: 111436, quantity: 5, reason_type: 'disease', reason_description: nil, discarded_at: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } } }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/96182/items?filter[seeding_unit_id]=3479&include=barcodes,seeding_unit")
          .to_return(body: { data: [{ id: '969664', type: 'items', attributes: { id: 969664, harvest_quantity: 0, secondary_harvest_quantity: 10.0, secondary_harvest_unit: 'Grams', harvest_unit: 'Grams' }, relationships: { barcode: { data: { id: '1A4FF010000002200000105', type: 'barcodes' } } } }, { id: '969663', type: 'items', attributes: { id: 969663, harvest_quantity: 0, secondary_harvest_quantity: 10.0, secondary_harvest_unit: 'Grams', harvest_unit: 'Grams' }, relationships: { barcode: { data: { id: '1A4FF010000002200000104', type: 'barcodes' } } } }, { id: '969662', type: 'items', attributes: { id: 969662, harvest_quantity: 0, secondary_harvest_quantity: 10.0, secondary_harvest_unit: 'Grams', harvest_unit: 'Grams' }, relationships: { barcode: { data: { id: '1A4FF010000002200000103', type: 'barcodes' } } } }] }.to_json)

        stub_request(:post, 'https://sandbox-api-md.metrc.com/plantbatches/v1/destroy?licenseNumber=LIC-0001')
          .with(
            body: [{ PlantBatch: '1A4060300003B01000000838', Count: 5, ReasonNote: described_class::NOT_SPECIFIED, ActualDate: '2019-10-25T00:00:00.000Z' }].to_json,
            basic_auth: [METRC_API_KEY, integration.secret]
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
        .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { meta: { included: false } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'custom_prefix' } }] }.to_json)

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
        .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { meta: { included: false } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'custom_prefix' } }] }.to_json)

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/discards/")
        .to_return(body: { data: [{ id: '111436', type: 'discards', attributes: { id: 111436, quantity: 5, reason_type: 'disease', reason_description: nil, discarded_at: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111435', type: 'discards', attributes: { id: 111435, quantity: 5, reason_type: 'other', reason_description: 'I don\'t like them', discarded_at: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96219', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111423', type: 'discards', attributes: { id: 111423, quantity: 1, reason_type: 'other', reason_description: 'I have a fever', discarded_at: '2019-10-04T00:00:00.000Z' }, relationships: { batch: { data: { id: '96182', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111331', type: 'discards', attributes: { id: 111331, quantity: 1, reason_type: 'disease', reason_description: nil, discarded_at: '2019-10-03T00:00:00.000Z' }, relationships: { batch: { data: { id: '95956', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '33550', type: 'discards', attributes: { id: 33550, quantity: 1, reason_type: 'disease', reason_description: nil, discarded_at: '2019-09-01T00:00:00.000Z' }, relationships: { batch: { data: { id: '83397', type: 'batches' } }, completion: { meta: { included: false } } } }] }.to_json)

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/discards/3000")
        .to_return(body: { data: { id: '111436', type: 'discards', attributes: { id: 111436, quantity: 5, reason_type: 'disease', reason_description: nil, discarded_at: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } } }.to_json)
    end

    subject { described_class.new(ctx, integration) }

    it 'returns a valid payload' do
      payload = subject.send :build_immature_payload

      expect(payload.size).to eq 1
      expect(payload.first).to eq(
        PlantBatch: '1A4060300003B01000000838',
        Count: 5,
        ReasonNote: described_class::NOT_SPECIFIED,
        ActualDate: '2019-10-25T00:00:00.000Z'
      )
    end
  end

  describe '#build_mature_payload' do
    context 'with no reason given' do
      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568")
          .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002")
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { meta: { included: false } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'custom_prefix' } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { meta: { included: false } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'custom_prefix' } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/discards/")
          .to_return(body: { data: [{ id: '111436', type: 'discards', attributes: { id: 111436, quantity: 5, reason_type: 'disease', reason_description: nil, discarded_at: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111435', type: 'discards', attributes: { id: 111435, quantity: 5, reason_type: 'other', reason_description: 'I don\'t like them', discarded_at: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96219', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111423', type: 'discards', attributes: { id: 111423, quantity: 1, reason_type: 'other', reason_description: 'I have a fever', discarded_at: '2019-10-04T00:00:00.000Z' }, relationships: { batch: { data: { id: '96182', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111331', type: 'discards', attributes: { id: 111331, quantity: 1, reason_type: 'disease', reason_description: nil, discarded_at: '2019-10-03T00:00:00.000Z' }, relationships: { batch: { data: { id: '95956', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '33550', type: 'discards', attributes: { id: 33550, quantity: 1, reason_type: 'disease', reason_description: nil, discarded_at: '2019-09-01T00:00:00.000Z' }, relationships: { batch: { data: { id: '83397', type: 'batches' } }, completion: { meta: { included: false } } } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/discards/3000")
          .to_return(body: { data: { id: '111436', type: 'discards', attributes: { id: 111436, quantity: 5, reason_type: 'disease', reason_description: nil, discarded_at: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } } }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/96182/items?filter%5Bseeding_unit_id%5D=3479&include=barcodes,seeding_unit")
          .to_return(body: { data: [{ id: '326515', type: 'items', attributes: { id: 326515, status: 'active' }, relationships: { barcode: { data: { id: '1A4060300003B01000000838', type: 'barcodes' } }, seeding_unit: { data: { id: '100', type: 'seeding_units' } } } }] }.to_json)
      end

      subject { described_class.new(ctx, integration) }

      it 'returns a valid payload' do
        payload = subject.send :build_mature_payload

        expect(payload.size).to eq 1
        expect(payload.first).to eq(
          Id: nil,
          Label: '1A4060300003B01000000838',
          ReasonNote: described_class::NOT_SPECIFIED,
          ActualDate: '2019-10-25T00:00:00.000Z'
        )
      end
    end

    context 'with reason given' do
      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568")
          .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002")
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { meta: { included: false } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'custom_prefix' } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
          .to_return(body: { data: { id: '96182', type: 'batches', attributes: { id: 96182, arbitrary_id: 'Oct1-Ban-Spl-Can', start_type: 'seed', quantity: 0, harvest_quantity: nil, expected_harvest_at: '2019-10-04', harvested_at: nil, seeded_at: '2019-10-01', completed_at: '2019-10-04T16:00:00.000Z', facility_id: 1568, zone_name: 'Flowering', crop_variety: 'Banana Split', crop: 'Cannabis' }, relationships: { harvests: { meta: { included: false } }, completions: { meta: { included: false } }, items: { meta: { included: false } }, custom_data: { meta: { included: false } }, barcodes: { data: [{ type: :barcodes, id: '1A4060300003B01000000838' }] }, discards: { meta: { included: false } }, seeding_unit: { data: { type: 'seeding_units', id: '3479' } }, harvest_unit: { meta: { included: false } }, zone: { data: { id: 6425, type: 'zones' } }, sub_zone: { meta: { included: false } } } }, included: [{ id: '3479', type: 'seeding_units', attributes: { id: 3479, name: 'Plant (barcoded)', secondary_display_active: nil, secondary_display_capacity: nil, item_tracking_method: 'custom_prefix' } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/discards/")
          .to_return(body: { data: [{ id: '111436', type: 'discards', attributes: { id: 111436, quantity: 5, reason_type: 'disease', reason_description: 'Not enough cow bell', discarded_at: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111435', type: 'discards', attributes: { id: 111435, quantity: 5, reason_type: 'other', reason_description: 'I don\'t like them', discarded_at: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96219', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111423', type: 'discards', attributes: { id: 111423, quantity: 1, reason_type: 'other', reason_description: 'I have a fever', discarded_at: '2019-10-04T00:00:00.000Z' }, relationships: { batch: { data: { id: '96182', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '111331', type: 'discards', attributes: { id: 111331, quantity: 1, reason_type: 'disease', reason_description: nil, discarded_at: '2019-10-03T00:00:00.000Z' }, relationships: { batch: { data: { id: '95956', type: 'batches' } }, completion: { meta: { included: false } } } }, { id: '33550', type: 'discards', attributes: { id: 33550, quantity: 1, reason_type: 'disease', reason_description: nil, discarded_at: '2019-09-01T00:00:00.000Z' }, relationships: { batch: { data: { id: '83397', type: 'batches' } }, completion: { meta: { included: false } } } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/discards/3000")
          .to_return(body: { data: { id: '111436', type: 'discards', attributes: { id: 111436, quantity: 5, reason_type: 'disease', reason_description: 'Not enough cow bell', discarded_at: '2019-10-25T00:00:00.000Z' }, relationships: { batch: { data: { id: '96258', type: 'batches' } }, completion: { meta: { included: false } } } } }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/1568/batches/96182/items?filter%5Bseeding_unit_id%5D=3479&include=barcodes,seeding_unit")
          .to_return(body: { data: [{ id: '326515', type: 'items', attributes: { id: 326515, status: 'active' }, relationships: { barcode: { data: { id: '1A4060300003B01000000838', type: 'barcodes' } }, seeding_unit: { data: { id: '100', type: 'seeding_units' } } } }] }.to_json)
      end

      subject { described_class.new(ctx, integration) }

      it 'returns a valid payload' do
        payload = subject.send :build_mature_payload

        expect(payload.size).to eq 1
        expect(payload.first).to eq(
          Id: nil,
          Label: '1A4060300003B01000000838',
          ReasonNote: 'Disease: Not enough cow bell. And the only prescription is moar cow bell',
          ActualDate: '2019-10-25T00:00:00.000Z'
        )
      end
    end
  end
end
