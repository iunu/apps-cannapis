require 'rails_helper'
require 'ostruct'

RSpec.describe NcsService::Package::Start do
  def load_response_json(path)
    File.read("spec/support/data/#{path}.json")
  end

  let(:account) { create(:account) }
  let(:integration) { create(:ncs_integration, account: account) }

  let(:ctx) do
    {
      'id': '2365',
      'type': 'completions',
      'attributes': {
        'id': 2365,
        'user_id': 20,
        'content': nil,
        'start_time': '2020-02-24T05:00:00.000Z',
        'end_time': '2020-02-24T05:00:00.000Z',
        'occurrence': 0,
        'action_type': 'harvest',
        'options': {
          'resources': [
            {
              'resource_unit_id': 26,
              'generated_quantity': 100
            }
          ],
          'harvest_type': 'complete',
          'note_content': '',
          'harvest_unit_id': 12,
          'seeding_unit_id': 11,
          'quantity_remaining': 1,
          'calculated_quantity': 1.0
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
            'id': '374',
            'type': 'batches'
          }
        },
        'facility': {
          'data': {
            'id': 2,
            'type': 'facilities'
          }
        },
        'user': {
          'data': {
            'id': 20,
            'type': 'users'
          }
        }
      }
    }.with_indifferent_access
  end

  let(:transaction) { stub_model Transaction, type: :create_plant_package, success: true, vendor: :ncs }

  before do
    allow_any_instance_of(described_class)
      .to receive(:get_transaction)
      .and_return(transaction)
  end

  describe '#call' do
    subject { described_class.call(ctx, integration) }

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
          Tag: 'asdfasdfasdfasdf123123123',
          Location: 'Warehouse',
          Item: 'Flower',
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
          ActualDate: '2020-02-24T05:00:00.000Z',
          Ingredients: [
            {
              HarvestId: 2,
              HarvestName: 'Feb6-5th-Ele-Can',
              Weight: 50,
              UnitOfWeight: 'Grams'
            }
          ]
        ]
      end

      let(:crop_batch_id) { 374 }
      let(:facility_id) { 2 }
      let(:now) { Time.now.utc }
      let(:testing) { raise 'override in subcontext' }

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json('api/package/facility'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{crop_batch_id}?include=zone,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone")
          .to_return(body: load_response_json("api/package/batch#{testing ? '-testing' : ''}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter[crop_batch_ids][]=#{crop_batch_id}")
          .to_return(body: { data: [{ id: '90210', type: 'completions', attributes: { id: 90210, action_type: 'start', parent_id: 90209 } }, { id: '90211', type: 'completions', attributes: { id: 90211, action_type: 'consume', parent_id: 90209, context: { source_batch: { id: crop_batch_id } }, options: { resource_unit_id: 26, batch_resource_id: 123, consumed_quantity: 50, requested_quantity: 10 } } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{crop_batch_id}")
          .to_return(body: load_response_json('api/package/crop-batch'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/resource_units/26")
          .to_return(body: load_response_json('api/package/resource_unit'))

        stub_request(:get, "#{ENV['NCS_BASE_URI']}/pos/harvests/v1/active")
          .to_return(body: '[{"id": 5, "Name": "Feb24-5th-Ele-Can-2"}]')

        stub_request(:post, "#{ENV['NCS_BASE_URI']}/pos/plantbatches/v1/createplantings")
          .with(
            body: "[{\"Name\":\"1A4FF01000000220000010\",\"Type\":\"Clone\",\"Count\":100,\"StrainName\":\"Banana Split\",\"RoomName\":\"Germination\",\"PlantedDate\":\"#{now}\"}]"
          )
          .to_return(status: 200, body: '{}', headers: {})

        stub_request(:post, "#{ENV['NCS_BASE_URI']}/pos/harvests/v1/createpackages")
          .with(body: '[{"HarvestId":5,"Label":"asdfasdfasdfasdf123123123","RoomName":"Warehouse","ProductName":"5th Element","Weight":1,"UnitOfMeasureName":"Grams","IsProductionBatch":false,"ProductionBatchNumber":null,"ProductRequiresRemediation":false,"RemediationMethodId":null,"RemediationDate":null,"RemediationSteps":null,"PackagedDate":"2020-02-24T05:00:00.000Z"}]')
          .to_return(status: 200, body: '{}', headers: {})
      end

      describe 'standard package' do
        let(:testing) { false }
        let(:upstream_transaction) { create(:transaction, :successful, :plant_package, vendor: :ncs) }

        it { is_expected.to eq(transaction) }
        it { is_expected.to be_success }

        context 'when upstream tasks are not yet processed' do
          before do
            run_on = Time.zone.parse("#{Time.now.localtime(integration.timezone).strftime('%F')}T#{integration.eod}#{integration.timezone}")

            create(
              :task,
              integration: integration,
              batch_id: crop_batch_id,
              facility_id: facility_id,
              run_on: run_on
            )

            stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/v3/facilities/2/batches/15?include=zone,barcodes,completions,custom_data,seeding_unit,harvest_unit,sub_zone")
              .to_return(body: load_response_json('api/package/crop-batch'))

            stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/v3/facilities/1/completions?filter%5Bcrop_batch_ids%5D%5B0%5D=15")
              .to_return(body: load_response_json('api/package/crop-batch-completions'))

            allow_any_instance_of(MetrcService::Plant::Start)
              .to receive(:call)
              .and_return(upstream_transaction)
          end

          it { is_expected.to be_success }
        end
      end

      describe 'testing package' do
        let(:testing) { true }
        it { is_expected.to eq(transaction) }
        it { is_expected.to be_success }
      end
    end
  end
end
