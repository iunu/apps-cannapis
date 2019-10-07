require 'rails_helper'

RSpec.describe MetrcService::Base do
  let(:account) { stub_model Account, artemis_id: 'ohai', name: 'Jon Snow' }
  let(:integration) { stub_model Integration, secret: 'jonisdany\'snephew', key: 'jonsnow', state: :cb, account: account, facility_id: 1568, vendor: :metrc, vendor_id: 'LIC-0001' }

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
end
