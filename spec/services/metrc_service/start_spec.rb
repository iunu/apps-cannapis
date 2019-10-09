require 'rails_helper'
require 'ostruct'

RSpec.describe MetrcService::Start do
  let(:account) { Account.create(artemis_id: 'ohai', name: 'Jon Snow') }
  let(:integration) { Integration.create(secret: 'jonisdany\'snephew', key: 'jonsnow', state: :cb, account: account, facility_id: 1568, vendor: :metrc, vendor_id: 'LIC-0001') }

  context 'on an old successful transaction' do
    let(:transaction) { stub_model Transaction, type: :start_batch, success: true }
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
    subject { MetrcService::Start.new(ctx, integration) }

    it 'returns the old transaction' do
      allow(subject).to receive(:get_transaction).and_return transaction
      expect(subject.call).to eq transaction
    end
  end

  context 'with corn crop' do
    let(:transaction) { stub_model Transaction, type: :start_batch, success: false }
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
    let(:batch) { OpenStruct.new(crop: 'Corn') }
    subject { MetrcService::Start.new(ctx, integration) }

    it 'returns nil' do
      allow(subject).to receive(:get_transaction).and_return transaction
      allow(subject).to receive(:get_batch).and_return batch
      expect(subject.call).to be_nil
    end
  end
end
