require 'rails_helper'

RSpec.describe MetrcService::SalesOrder::Harvest do
  METRC_API_KEY = ENV['METRC_SECRET_CA'] unless defined?(METRC_API_KEY)

  def load_response_json(path)
    File.read("spec/support/data/#{path}.json")
  end

  let(:account) { create(:account) }
  let(:integration) { create(:integration, account: account, state: :ca) }
  let(:facility_id) { 1 }
  let(:batch_id) { 40 }

  def api_url(path)
    "#{ENV['ARTEMIS_BASE_URI']}/api/v3/#{path}"
  end

  let(:ctx) do
    {
      id: 3000,
      relationships: {
        batch: { data: { id: batch_id } },
        facility: { data: { id: facility_id } }
      },
      completion_id: 1001
    }.with_indifferent_access
  end

  context '#call' do
    subject { described_class.call(ctx, integration) }

    before do
      expect_any_instance_of(described_class)
        .to receive(:get_transaction)
        .and_return transaction
    end

    describe 'on an old successful transaction' do
      let(:transaction) { create(:transaction, :successful, :harvest, account: account, integration: integration) }
      it { is_expected.to eq(transaction) }
    end

    describe 'with corn crop' do
      include_examples 'with corn crop'
    end

    describe 'on a complete harvest' do
      let(:transaction) { create(:transaction, :unsuccessful, :harvest, account: account, integration: integration) }
      let(:template_id) { 1 }

      before do
        stub_request(:get, api_url("facilities/#{facility_id}"))
          .to_return(body: load_response_json('api/sales_order/facility'))

        stub_request(:get, api_url("facilities/#{facility_id}/batches/#{batch_id}?include=zone,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone"))
          .to_return(body: load_response_json('api/sales_order/batch'))

        stub_request(:get, api_url("facilities/#{facility_id}/batches/#{batch_id}"))
          .to_return(body: load_response_json('api/sales_order/batch'))

        stub_request(:post, 'https://sandbox-api-ca.metrc.com/transfers/v1/templates?licenseNumber=LIC-0001')
          .with(basic_auth: [METRC_API_KEY, integration.secret])
          .to_return(status: 200, body: '', headers: {})
      end

      it { is_expected.to be_success }
    end
  end
end