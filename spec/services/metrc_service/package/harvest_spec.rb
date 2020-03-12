require 'rails_helper'
require 'ostruct'

RSpec.describe MetrcService::Package::Harvest do
  METRC_API_KEY = ENV['METRC_SECRET_CA'] unless defined?(METRC_API_KEY)

  def load_response_json(path)
    File.read("spec/support/data/#{path}.json")
  end

  let(:integration) { create(:integration, state: 'ca') }
  let(:facility_id) { 2 }
  let(:batch_id) { 374 }

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

  let(:transaction) { stub_model Transaction, type: :harvest_package_batch, success: false }

  before do
    allow_any_instance_of(described_class)
      .to receive(:get_transaction)
      .and_return(transaction)
  end

  context '#call' do
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
          Item: 'Bulk Flower',
          UnitOfWeight: 'g of Bulk Flower - 5th Element',
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
              HarvestName: 'Feb6-Bos-Hog-Can',
              Weight: 50,
              UnitOfWeight: 'g of Bulk Flower - 5th Element'
            }
          ]
        ]
      end

      let(:testing) { raise 'override in subcontext' }

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
          .to_return(body: load_response_json('api/package/facility'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone")
          .to_return(body: load_response_json("api/package/batch#{testing ? '-testing' : ''}"))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter[crop_batch_ids][]=#{batch_id}")
          .to_return(body: { data: [{ id: '90210', type: 'completions', attributes: { id: 90210, action_type: 'start' } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/completions?filter%5Bparent_id%5D=90210&filter%5Baction_type%5D=consume")
          .to_return(body: { data: [{ id: '90211', type: 'completions', attributes: { id: 90211, action_type: 'consume', options: { resource_unit_id: 26, batch_resource_id: 15, consumed_quantity: 50, requested_quantity: 10 } } }] }.to_json)

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/15")
          .to_return(body: load_response_json('api/package/crop-batch'))

        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/resource_units/26")
          .to_return(body: load_response_json('api/package/resource_unit'))

        stub_request(:get, 'https://sandbox-api-ca.metrc.com/harvests/v1/active?licenseNumber=LIC-0001')
          .to_return(status: 200, body: '[{"Id":1,"Name":"Some-Other-Harvest","HarvestType":"Product","SourceStrainCount":0},{"Id":2,"Name":"Feb6-Bos-Hog-Can","HarvestType":"WholePlant","SourceStrainCount":0}]')

        stub_request(:post, "https://sandbox-api-ca.metrc.com/packages/v1/create#{testing ? '/testing' : ''}?licenseNumber=LIC-0001")
          .with(body: expected_payload.to_json, basic_auth: [METRC_API_KEY, integration.secret])
          .to_return(status: 200, body: '', headers: {})
      end

      context 'standard package' do
        let(:testing) { false }
        it { is_expected.to eq(transaction) }
        it { is_expected.to be_success }
      end

      context 'testing package' do
        let(:testing) { true }
        it { is_expected.to eq(transaction) }
        it { is_expected.to be_success }
      end
    end
  end
end
