require 'rails_helper'
require 'ostruct'

RSpec.describe MetrcService::Start do
  let(:account) { Account.create(artemis_id: 'ohai', name: 'Jon Snow') }
  let(:integration) { Integration.create(secret: 'jonisdany\'snephew', key: 'jonsnow', state: :cb, account: account, facility_id: 1568, vendor: :metrc, vendor_id: 'LIC-0001') }
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
      'attributes': {
        'options': {
          'tracking_barcode': '1A4FF01000000220000010'
        }
      },
      'completion_id': 1001
    }.with_indifferent_access
  end

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
    let(:batch) { OpenStruct.new(crop: 'Corn') }
    subject { MetrcService::Start.new(ctx, integration) }

    it 'returns nil' do
      allow(subject).to receive(:get_transaction).and_return transaction
      allow(subject).to receive(:get_batch).and_return batch
      expect(subject.call).to be_nil
    end
  end

  context '#build_start_payload' do
    let(:batch) do
      zone = OpenStruct.new(attributes: {
                              seeding_unit: {
                                name: 'Clone'
                              }.with_indifferent_access
                            })

      OpenStruct.new(zone: zone,
                     attributes: {
                       quantity: '100',
                       crop_variety: 'Banana Split',
                       seeded_at: Time.zone.now,
                       zone_name: 'Germination'
                     }.with_indifferent_access)
    end

    it 'returns a valid payload' do
      instance = MetrcService::Start.new(ctx, integration)
      payload = instance.send :build_start_payload, batch

      expect(payload).not_to be_nil
      expect(payload[:Name]).not_to be_nil
      expect(payload[:Name]).to eq '1A4FF01000000220000010'
      expect(payload[:Type]).not_to be_nil
      expect(payload[:Type]).to eq 'Clone'
      expect(payload[:Count]).not_to be_nil
      expect(payload[:Count]).to eq 100
      expect(payload[:Strain]).not_to be_nil
      expect(payload[:Strain]).to eq 'Banana Split'
      expect(payload[:Room]).not_to be_nil
      expect(payload[:Room]).to eq 'Germination'
      expect(payload[:PatientLicenseNumber]).to be_nil
      expect(payload[:ActualDate]).not_to be_nil
    end
  end
end
