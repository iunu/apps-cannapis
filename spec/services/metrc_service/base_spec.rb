require 'rails_helper'

RSpec.describe MetrcService::Base do
  let(:account) { Account.create(artemis_id: 'ohai', name: 'Jon Snow') }
  let(:integration) { Integration.create(secret: 'jonisdany\'snephew', key: 'jonsnow', state: :cb, account: account, facility_id: 1568, vendor: :metrc, vendor_id: 'LIC-0001') }

  context 'holds the basic attributes' do
    subject { MetrcService::Base.new({}, integration) }

    it 'has .integration' do
      expect(subject.instance_variable_get(:@integration)).to eq integration
    end

    it 'has .logger' do
      expect(subject.instance_variable_get(:@logger)).to eq Rails.logger
    end

    it 'has .client' do
      expect(subject.instance_variable_get(:@client)).to be_a Metrc::Client
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
  end

  context 'getting a transaction' do
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
      existing = Transaction.create(account_id: account.id,
                                    integration_id: integration.id,
                                    vendor: :metrc,
                                    batch_id: 3002,
                                    completion_id: 4000,
                                    type: name,
                                    metadata: {}.to_json,
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
      expect(transaction.id).to eq existing.id
      expect(transaction.type).to eq existing.type
      expect(transaction.batch_id).to eq existing.batch_id
      expect(transaction.completion_id).to eq existing.completion_id
      expect(transaction.success).to eq existing.success
      expect(transaction.account_id).to eq existing.account_id
      expect(transaction.integration_id).to eq existing.integration_id
    end
  end
end
