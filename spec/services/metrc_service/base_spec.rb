require 'rails_helper'

RSpec.describe MetrcService::Base do
  let(:integration) { create(:integration, state: :ca) }

  describe '#run_mode' do
    subject { described_class.run_mode }
    it { is_expected.to eq(:later) }
  end

  describe 'holds the basic attributes' do
    subject { MetrcService::Base.new({}, integration) }

    it 'has @integration' do
      expect(subject.instance_variable_get(:@integration)).to eq integration
    end

    it 'has @logger' do
      expect(subject.instance_variable_get(:@logger)).to eq Rails.logger
    end

    it 'has @client' do
      expect(subject.instance_variable_get(:@client)).to be_a Metrc::Client
    end

    it 'does not have a @batch' do
      expect(subject.instance_variable_get(:@batch)).to be_nil
    end
  end

  context 'with a webhook context (params)' do
    let(:ctx) do
      {
        'id': 3000,
        'relationships': {
          'batch': {
            'data': {
              'id': 2002
            }
          },
          'facility': {
            'data': {
              'id': 1568
            }
          }
        },
        'attributes': {},
        'completion_id': 1001
      }
    end

    subject { MetrcService::Base.new(ctx, integration) }

    it 'has .relationships' do
      expect(subject.instance_variable_get(:@relationships)).to_not be_empty
    end

    it 'has .attributes' do
      expect(subject.instance_variable_get(:@attributes)).to be_empty
    end

    it 'has .completion_id' do
      expect(subject.instance_variable_get(:@completion_id)).to eq 3000
    end

    it 'has .batch_id' do
      expect(subject.instance_variable_get(:@batch_id)).to eq 2002
    end

    it 'has .facility_id' do
      expect(subject.instance_variable_get(:@facility_id)).to eq 1568
    end

    it 'does not have a @batch' do
      expect(subject.instance_variable_get(:@batch)).to be_nil
    end
  end

  describe '#get_transaction' do
    it 'creates a new transaction' do
      ctx = {
        'id': 3000,
        'relationships': {
          'batch': {
            'data': {
              'id': 2002
            }
          },
          'facility': {
            'data': {
              'id': 1568
            }
          }
        },
        'attributes': {},
        'completion_id': 3000
      }
      instance = MetrcService::Base.new(ctx, integration)
      name = :start_batch
      transaction = instance.send :get_transaction, name
      expect(transaction).to_not be_nil
      expect(transaction.type).to eq name.to_s
      expect(transaction.batch_id).to eq 2002
      expect(transaction.completion_id).to eq 3000
    end

    it 'returns an existing transaction' do
      name = :start_batch
      existing = Transaction.create(account_id: integration.account.id,
                                    integration_id: integration.id,
                                    vendor: :metrc,
                                    batch_id: 3002,
                                    completion_id: 4000,
                                    type: name,
                                    metadata: {},
                                    success: true)
      ctx = {
        'id': 4000,
        'relationships': {
          'batch': {
            'data': {
              'id': 3002
            }
          },
          'facility': {
            'data': {
              'id': 3568
            }
          }
        },
        'attributes': {},
        'completion_id': 4000
      }
      instance = MetrcService::Base.new(ctx, integration)
      transaction = instance.send :get_transaction, name

      expect(transaction).to_not be_nil
      expect(transaction).to be_a Transaction
      expect(transaction.id).to eq existing.id
      expect(transaction.type).to eq existing.type
      expect(transaction.batch_id).to eq existing.batch_id
      expect(transaction.completion_id).to eq existing.completion_id
      expect(transaction.success).to eq existing.success
      expect(transaction.account_id).to eq existing.account_id
      expect(transaction.integration_id).to eq existing.integration_id
    end
  end

  describe '#get_batch' do
    before :all do
      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
        .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone')
        .to_return(body: { data: { id: '2002', type: 'batches', attributes: { id: 2002, arbitrary_id: 'Jun19-Bok-Cho' } } }.to_json)
    end

    it 'gets a batch', skip: 'FIXME' do
      ctx = {
        'id': 3000,
        'relationships': {
          'batch': {
            'data': {
              'id': 2002
            }
          },
          'facility': {
            'data': {
              'id': 1568
            }
          }
        },
        'attributes': {},
        'completion_id': 3000
      }
      instance = MetrcService::Base.new(ctx, integration)
      batch = instance.send :get_batch
      expect(batch).to_not be_nil
      expect(batch.id).to eq 2002
      expect(batch.arbitrary_id).to eq 'Jun19-Bok-Cho'
    end
  end

  describe '#get_items' do
    before :all do
      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
        .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002')
        .to_return(body: { data: { id: '2002', type: 'batches', attributes: { id: 2002, arbitrary_id: 'Jun19-Bok-Cho' } } }.to_json)

      stub_request(:get, 'https://portal.artemisag.com/api/v3/items?filter[seeding_unit_id]=100&include=barcodes,seeding_unit')
        .to_return(body: { data: [{ id: '326515', type: 'items', attributes: { id: 326515, status: 'active' }, relationships: { barcode: { data: { id: '1A4FF0200000022000000207', type: 'barcodes' } }, seeding_unit: { data: { id: '100', type: 'seeding_units' } } } }] }.to_json)
    end

    it 'gets batch items', skip: 'FIXME' do
      ctx = {
        'id': 3000,
        'relationships': {
          'batch': {
            'data': {
              'id': 2002
            }
          },
          'facility': {
            'data': {
              'id': 1568
            }
          }
        },
        'attributes': {},
        'completion_id': 3000
      }
      seeding_unit_id = 100
      instance = MetrcService::Base.new(ctx, integration)
      items = instance.send :get_items, seeding_unit_id
      expect(items).to_not be_nil
      expect(items.first.id).to eq 326_515
      expect(items.first.relationships.dig('barcode', 'data', 'id')).to eq '1A4FF0200000022000000207'
      expect(items.first.relationships.dig('seeding_unit', 'data', 'id')).to eq seeding_unit_id.to_s
    end
  end

  describe '#get_zone' do
    before :all do
      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
        .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/zones/2')
        .to_return(body: { data: { id: '2', type: 'zones', attributes: { id: 2, name: 'Propagation' } } }.to_json)
    end

    it 'gets zone', skip: 'FIXME' do
      ctx = {
        'id': 3000,
        'relationships': {
          'batch': {
            'data': {
              'id': 2002
            }
          },
          'facility': {
            'data': {
              'id': 1568
            }
          }
        },
        'attributes': {},
        'completion_id': 3000
      }
      zone_id = 2
      instance = MetrcService::Base.new(ctx, integration)
      zone = instance.send :get_zone, zone_id
      expect(zone).to_not be_nil
      expect(zone.id).to eq zone_id
      expect(zone.name).to eq 'Propagation'
    end
  end

  describe '#get_resource_unit' do
    include_context 'with synced data' do
      let(:facility_id) { 1 }
      let(:batch_id) { 331 }
    end

    before do
      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}")
        .to_return(body: load_response_json("api/sync/facilities/#{facility_id}"))

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone")
        .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/batches/#{batch_id}"))

      stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{facility_id}/resource_units/8")
        .to_return(body: load_response_json("api/sync/facilities/#{facility_id}/resource_units/8"))
    end

    let(:ctx) do
      {
        id: 3000,
        relationships: {
          batch: { data: { id: batch_id } },
          facility: { data: { id: facility_id } }
        },
        attributes: {},
        completion_id: 3000
      }
    end

    let(:instance) { MetrcService::Base.new(ctx, integration) }
    let(:resource_unit) { instance.send(:get_resource_unit, 8) }

    subject { resource_unit }

    it { is_expected.to be_a(OpenStruct) }

    it do
      is_expected.to have_attributes(
        id: 8,
        name: 'Gram of Wet Material, Boss Hog Cannabis',
        unit: 'Grams',
        label: 'Wet Material',
        strain: 'Boss Hog',
        kind: 'weight',
        metrc_type: 'wet_weight'
      )
    end
  end

  describe 'state' do
    let(:state) { 'NY' }
    let(:integration) { create(:integration, state: state) }
    let(:service) { MetrcService::Base.new({}, integration) }
    subject { service.send(:state) }

    it { is_expected.to eq(integration.state) }

    context 'when CO' do
      let(:state) { 'CO' }
      it { is_expected.to eq('CO') }
    end

    context 'when MA' do
      let(:state) { 'MA' }
      it { is_expected.to eq('CO') }
    end

    context 'when MT' do
      let(:state) { 'MT' }
      it { is_expected.to eq('CO') }

      context 'when lower case' do
        let(:state) { 'mt' }
        it { is_expected.to eq('CO') }
      end
    end
  end

  describe '#call_metrc error handling' do
    let(:payload) do
      { Something: 'went wrong' }
    end

    let(:integration) { create(:integration, state: :md) }
    let(:instance) { described_class.new({}, integration) }
    let(:call) { instance.send(:call_metrc, :create_plant_batches, payload) }

    context 'when retryable' do
      before do
        stub_request(:post, 'https://sandbox-api-md.metrc.com/plantbatches/v1/createplantings?licenseNumber=LIC-0001')
          .with(
            body: '{"Something":"went wrong"}',
            basic_auth: [ENV["METRC_SECRET_#{integration.state.upcase}"], integration.secret]
          )
          .to_return(status: 500, body: '', headers: {})
      end

      it 'should raise an error' do
        expect { call }.to raise_error(Cannapi::RetryableError)
      end
    end
  end

  describe '#batch_tag' do
    let(:integration) { create(:integration, state: :md) }
    let(:instance) { described_class.new({}, integration) }
    let(:call) { instance.send(:batch_tag) }
    let(:batch) do
      double(:batch, arbitrary_id: 'a-batch-id', relationships: batch_relationships)
    end

    before do
      expect(instance)
        .to receive(:batch)
        .at_least(:once)
        .and_return(batch)
    end

    subject { call }

    context 'when batch has a valid tag' do
      let(:batch_relationships) do
        {
          'barcodes': {
            'data': [
              { 'id': '12345678901234567890ABCD' }
            ]
          }
        }.with_indifferent_access
      end

      it 'does not raise an exception' do
        expect { subject }.not_to raise_exception
      end
    end

    context 'when batch has no tags' do
      let(:batch_relationships) do
        { 'barcodes': { 'data': [] } }.with_indifferent_access
      end

      it 'raises an exception' do
        expect { subject }.to raise_exception(MetrcService::InvalidAttributes, /Missing barcode for batch 'a-batch-id'/)
      end
    end

    context 'when batch has invalid tags' do
      let(:batch_relationships) do
        {
          'barcodes': {
            'data': [
              { 'id': 'Apr-20-5th-Ele-1' },
              { 'id': 'something-else' }
            ]
          }
        }.with_indifferent_access
      end

      it 'raises an exception' do
        expect { subject }.to raise_exception(MetrcService::InvalidAttributes, /Expected barcode for batch 'a-batch-id' to be alphanumeric with 24 characters. Got: Apr-20-5th-Ele-1, something-else/)
      end
    end
  end
end
