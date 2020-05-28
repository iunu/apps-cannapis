require 'rails_helper'
require 'ostruct'

RSpec.describe MetrcService::Package::Start do
  METRC_API_KEY = ENV['METRC_SECRET_CA'] unless defined?(METRC_API_KEY)

  include_context 'with synced data' do
    let(:facility_id) { 1 }
    let(:batch_id) { 307 }
  end

  context '#run_mode' do
    subject { described_class.run_mode }
    it { is_expected.to eq(:now) }
  end

  let(:integration) { create(:integration, state: 'ca') }

  let(:ctx) do
    {
      'id': '2046',
      'type': 'completions',
      'attributes': {
        'id': 2046,
        'status': 'active',
        'user_id': 11,
        'content': nil,
        'start_time': '2020-04-07T04:00:00.000Z',
        'end_time': '2020-04-07T14:33:39.963Z',
        'occurrence': 0,
        'action_type': 'start',
        'parent_id': 2045,
        'context': {
          'source_batches': nil
        },
        'options': {
          'zone_id': 20,
          'quantity': 1,
          'arbitrary_id': 'Apr7-5th-Ele-Can',
          'seeding_unit_id': 10,
          'arbitrary_id_base': '5th-Ele-Can',
          'zone_name': 'Warehouse'
        }
      },
      'relationships': {
        'action_result': {
          'meta': {
            'included': false
          }
        },
        'batch': {
          'data': {
            'id': batch_id,
            'type': 'batches'
          }
        },
        'facility': {
          'data': {
            'id': facility_id,
            'type': 'facilities'
          }
        },
        'user': {
          'data': {
            'id': 11,
            'type': 'users'
          }
        }
      }
    }.with_indifferent_access
  end

  let(:transaction) { stub_model Transaction, type: :harvest_package_batch, success: false }

  before do
    allow_any_instance_of(described_class)
      .to receive(:get_transaction)
      .and_return(transaction)
  end

  subject { described_class.call(ctx, integration) }

  context 'with product package' do
    context '#call' do
      describe 'on an old successful transaction' do
        before { transaction.success = true }
        it { is_expected.to eq(transaction) }
      end

      describe 'with corn crop' do
        include_examples 'with corn crop'
      end

      describe 'on a complete harvest' do
        let(:expected_payload) do
          [
            Tag: '1A4FF0100000022000001161',
            Location: 'Warehouse',
            Item: '5th Element',
            UnitOfWeight: 'Grams',
            PatientLicenseNumber: nil,
            Note: nil,
            IsProductionBatch: false,
            ProductionBatchNumber: nil,
            IsTradeSample: false,
            ProductRequiresRemediation: false,
            RemediateProduct: false,
            RemediationMethodId: nil,
            RemediationDate: nil,
            RemediationSteps: nil,
            ActualDate: '2020-04-07T04:00:00.000Z',
            Ingredients: [
              {
                HarvestId: 2,
                HarvestName: 'Apr7-5th-Ele-Can-26',
                Weight: 10,
                UnitOfWeight: 'Grams'
              }
            ]
          ]
        end

        let(:crop_batch_id) { 306 }
        let(:testing) { raise 'override in subcontext' }

        before do
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
            .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
            .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter[crop_batch_ids][]=#{batch_id}")
            .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/completions"))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{crop_batch_id}?include=barcodes")
            .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{crop_batch_id}"))

          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/resource_units/21?include=crop_variety")
            .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/resource_units/21"))

          stub_request(:get, 'https://sandbox-api-ca.metrc.com/harvests/v1/active?licenseNumber=LIC-0001')
            .to_return(status: 200, body: '[{"Id":1,"Name":"Some-Other-Harvest","HarvestType":"Product","SourceStrainCount":0},{"Id":2,"Name":"Apr7-5th-Ele-Can-26","HarvestType":"WholePlant","SourceStrainCount":0}]')

          stub_request(:post, "https://sandbox-api-ca.metrc.com/harvests/v1/create/packages#{testing ? '/testing' : ''}?licenseNumber=LIC-0001")
            .with(body: expected_payload.to_json, basic_auth: [METRC_API_KEY, integration.secret])
            .to_return(status: 200, body: '', headers: {})

          stub_request(:get, 'https://sandbox-api-ca.metrc.com/harvests/v1/1?licenseNumber=LIC-0001')
            .to_return(status: 200, body: '{"Id":1,"Name":"Some-Other-Harvest","HarvestType":"Product","SourceStrainCount":0, "CurrentWeight": 100.0}')

          stub_request(:get, 'https://sandbox-api-ca.metrc.com/harvests/v1/2?licenseNumber=LIC-0001')
            .to_return(status: 200, body: '{"Id":2,"Name":"Apr7-5th-Ele-Can-26","HarvestType":"WholePlant","SourceStrainCount":0, "CurrentWeight": 0.0}')

          stub_request(:get, 'https://sandbox-api-ca.metrc.com/items/v1/categories')
            .to_return(status: 200, body: [{ Name: 'Wet Material' }].to_json)
        end

        context 'standard package' do
          let(:testing) { false }
          let(:upstream_transaction) { create(:transaction, :start, :successful) }

          it { is_expected.to eq(transaction) }
          it { is_expected.to be_success }

          context 'when upstream tasks are not yet processed' do
            before do
              run_on = Time.parse("#{Time.now.localtime(integration.timezone).strftime('%F')}T#{integration.eod}#{integration.timezone}")

              create(
                :task,
                integration: integration,
                batch_id: crop_batch_id,
                facility_id: facility_id,
                run_on: run_on
              )

              stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{crop_batch_id}?include=zone,zone.sub_stage,barcodes,completions,custom_data,seeding_unit,harvest_unit,sub_zone")
                .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{crop_batch_id}"))

              stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter%5Bcrop_batch_ids%5D%5B0%5D=#{crop_batch_id}")
                .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{crop_batch_id}/completions"))

              allow(MetrcService::Plant::Start)
                .to receive(:call)
                .and_return(upstream_transaction)
            end

            context 'when upstream tasks succeed' do
              before do
                allow(MetrcService::Plant::Move)
                  .to receive(:call)
                  .and_return(upstream_transaction)

                allow(MetrcService::Plant::Harvest)
                  .to receive(:call)
                  .and_return(upstream_transaction)
              end

              xit { is_expected.to be_success }
            end

            xcontext 'when upstream tasks fail' do
              let(:upstream_transaction) { create(:transaction, :start, :unsuccessful) }
              it { is_expected.not_to be_success }
            end
          end
        end

        xcontext 'testing package', 'pending testing template' do
          let(:testing) { true }
          it { is_expected.to eq(transaction) }
          it { is_expected.to be_success }
        end
      end
    end
  end

  context 'with plant package' do
    describe 'on a complete harvest' do
      let(:expected_payload) do
        [{
          PlantBatch: '1A4FF0000000022000006360',
          Count: 5,
          Location: nil,
          Item: item_type,
          Tag: '1234567890ABCD1234567890',
          PatientLicenseNumber: nil,
          Note: '',
          IsTradeSample: false,
          IsDonation: false,
          ActualDate: '2020-04-07T04:00:00.000Z'
        }]
      end

      let(:facility_id) { 2 }
      let(:batch_id) { 72 }
      let(:crop_batch_id) { 65 }

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter[crop_batch_ids][]=#{batch_id}")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}/completions"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{crop_batch_id}?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field")
          .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{crop_batch_id}"))

        stub_request(:get, 'https://sandbox-api-ca.metrc.com/plantbatches/v1/active?licenseNumber=LIC-0001')
          .to_return(status: 200, body: [{ Id: 54321, Name: 'not-this-one' }, { Id: 12345, Name: '1234567890ABCD1234567890' }].to_json)

        stub_request(:get, 'https://sandbox-api-ca.metrc.com/items/v1/categories')
          .to_return(status: 200, body: [{ Name: 'Wet Material' }].to_json)

        stub_request(:post, "https://sandbox-api-ca.metrc.com/plantbatches/v1/create/plantings?licenseNumber=LIC-0001")
          .with(body: expected_payload.to_json, basic_auth: [METRC_API_KEY, integration.secret])
          .to_return(status: 200, body: '', headers: {})
      end

      context 'when no metrc item name is specified' do
        # crop variety is used by default
        let(:item_type) { 'Boss Hog' }

        before do
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/resource_units/3?include=crop_variety")
            .to_return(body: load_response_json("api/package/plant_resource_unit_generic"))
        end

        it { is_expected.to be_success }
      end

      context 'when metrc item name is specified' do
        let(:item_type) { 'Boss Hog Teens' }

        before do
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/resource_units/3?include=crop_variety")
            .to_return(body: load_response_json("api/package/plant_resource_unit_metrc_item_name"))
        end

        it { is_expected.to be_success }
      end

      context 'when metrc item suffix is specified' do
        let(:item_type) { 'Boss Hog Teens' }

        before do
          stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/resource_units/3?include=crop_variety")
            .to_return(body: load_response_json("api/package/plant_resource_unit_metrc_item_name"))
        end

        it { is_expected.to be_success }
      end
    end
  end

  describe '#validate_item_type!' do
    let(:handler) { described_class.new(ctx, integration) }

    subject { handler.send(:validate_item_type!, item_type) }

    before do
      stub_request(:get, 'https://sandbox-api-ca.metrc.com/items/v1/categories')
        .to_return(status: 200, body: valid_categories.to_json)
    end

    context 'when type is valid' do
      let(:valid_categories) { [{ Name: 'Wet Material' }] }
      let(:item_type) { 'Wet Material' }

      it 'should not raise an error' do
        expect { subject }.not_to raise_error
      end
    end

    context 'when type is not valid' do
      let(:valid_categories) { [{ Name: 'Flower' }] }

      describe 'and not similar to supported types' do
        let(:item_type) { 'Bud' }

        it 'should not raise an error' do
          expect { subject }.to raise_error(InvalidAttributes, /package item type .* not supported .* No similar types/)
        end
      end

      describe 'but similar to supported types' do
        let(:item_type) { 'Flowers' }

        it 'should not raise an error' do
          expect { subject }.to raise_error(InvalidAttributes, /package item type .* not supported .* Did you mean "Flower"/)
        end
      end
    end
  end
end
