require 'rails_helper'

RSpec.describe NcsService::Base do
  let(:account) { create(:account) }
  let(:integration) { create(:ncs_integration, account: account) }

  subject { described_class.new({}, integration) }

  context 'when holds the basic attributes' do
    it 'has @integration' do
      expect(subject.instance_variable_get(:@integration)).to eq integration
    end

    it 'has @logger' do
      expect(subject.instance_variable_get(:@logger)).to eq Rails.logger
    end

    it 'has @client' do
      expect(subject.instance_variable_get(:@client)).to be_a NcsAnalytics::Client
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

    subject { described_class.new(ctx, integration) }

    it 'has .relationships' do
      expect(subject.instance_variable_get(:@relationships)).not_to be_empty
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
      instance = described_class.new(ctx, integration)
      name = :start_batch
      transaction = instance.send :get_transaction, name
      expect(transaction).not_to be_nil
      expect(transaction.type).to eq name.to_s
      expect(transaction.batch_id).to eq 2002
      expect(transaction.completion_id).to eq 3000
    end

    it 'returns an existing transaction' do
      name = :start_batch
      existing = Transaction.create(account_id: integration.account.id,
                                    integration_id: integration.id,
                                    vendor: :ncs,
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
      instance = described_class.new(ctx, integration)
      transaction = instance.send :get_transaction, name

      expect(transaction).not_to be_nil
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
    before do
      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
        .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone')
        .to_return(body: { data: { id: '2002', type: 'batches', attributes: { id: 2002, arbitrary_id: 'Jun19-Bok-Cho', facility_id: 1568 } } }.to_json)
    end

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
        completion_id: 3000
      }.with_indifferent_access
    end

    subject { described_class.new(ctx, integration) }

    it 'gets a batch' do
      batch = subject.send :get_batch
      expect(batch).not_to be_nil
      expect(batch.id).to eq 2002
      expect(batch.arbitrary_id).to eq 'Jun19-Bok-Cho'
    end
  end

  describe '#get_items' do
    before do
      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
        .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002')
        .to_return(body: { data: { id: '2002', type: 'batches', attributes: { id: 2002, arbitrary_id: 'Jun19-Bok-Cho', facility_id: 1568 } } }.to_json)

      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002/items?filter[seeding_unit_id]=100&include=barcodes,seeding_unit')
        .to_return(body: { data: [{ id: '326515', type: 'items', attributes: { id: 326515, status: 'active' }, relationships: { barcode: { data: { id: '1A4FF0200000022000000207', type: 'barcodes' } }, seeding_unit: { data: { id: '100', type: 'seeding_units' } } } }] }.to_json)
    end

    let(:integration) { create(:ncs_integration, account: account, facility_id: 1568) }
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
              id: integration.facility_id
            }
          }
        },
        attributes: {},
        completion_id: 3000
      }.with_indifferent_access
    end
    let(:seeding_unit_id) { 100 }

    subject { described_class.new(ctx, integration) }

    it 'gets batch items' do
      items = subject.send :get_items, seeding_unit_id
      expect(items).not_to be_nil
      expect(items.first.id).to eq 326_515
      expect(items.first.relationships.dig('barcode', 'data', 'id')).to eq '1A4FF0200000022000000207'
      expect(items.first.relationships.dig('seeding_unit', 'data', 'id')).to eq seeding_unit_id.to_s
    end
  end

  describe '#get_zone' do
    before do
      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
        .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/zones/2')
        .to_return(body: { data: { id: '2', type: 'zones', attributes: { id: 2, name: 'Propagation' } } }.to_json)
    end

    it 'gets zone' do
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
      instance = described_class.new(ctx, integration)
      zone = instance.send :get_zone, zone_id
      expect(zone).not_to be_nil
      expect(zone.id).to eq zone_id
      expect(zone.name).to eq 'Propagation'
    end
  end

  describe '#get_resource_unit' do
    before do
      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
        .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone')
        .to_return(body: { data: { id: '2002', type: 'batches', attributes: { id: 2002, crop_variety: '5th Element' } } }.to_json)

      stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/resource_units/1')
        .to_return(body: { data: { id: '1', type: 'resource_units', attributes: { id: 1, name: 'g of Something - 5th Element', kind: 'weight', conversion_si: 1.0 } } }.to_json)
    end

    let(:ctx) do
      {
        id: 3000,
        relationships: {
          batch: { data: { id: 2002 } },
          facility: { data: { id: 1568 } }
        },
        attributes: {},
        completion_id: 3000
      }
    end

    let(:instance) { described_class.new(ctx, integration) }
    let(:resource_unit) { instance.send(:get_resource_unit, 1) }

    subject { resource_unit }

    it { is_expected.to be_a(OpenStruct) }

    it do
      is_expected.to have_attributes(
        id: 1,
        name: 'g of Something - 5th Element',
        unit: 'Grams',
        label: 'g of Something',
        strain: '5th Element',
        kind: 'weight',
        conversion_si: 1.0
      )
    end
  end

  describe '#call_ncs error handling' do
    let(:payload) do
      { Something: 'went wrong' }
    end

    let(:instance) { described_class.new({}, integration) }

    context 'when retryable' do
      before do
        stub_request(:post, "#{ENV['NCS_BASE_URI']}/pos/plantbatches/v1/createplantings")
          .with(
            body: [payload].to_json,
            headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ABC1234567890' }
          )
          .to_return(status: 500, body: '{}')
      end

      it 'raises an error' do
        expect { instance.send(:call_ncs, :plant_batch, :create, payload) }.to raise_error(Cannapi::RetryableError)
      end
    end
  end
end
