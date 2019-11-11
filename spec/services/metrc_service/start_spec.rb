require 'rails_helper'
require 'ostruct'

RSpec.describe MetrcService::Start do
  let(:integration) { create(:integration) }
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

  context '#call' do
    describe 'on an old successful transaction' do
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
      subject { described_class.new(ctx, integration) }

      it 'returns the old transaction' do
        allow(subject).to receive(:get_transaction).and_return transaction
        expect(subject.call).to eq transaction
      end
    end

    describe 'with corn crop' do
      let(:transaction) { stub_model Transaction, type: :start_batch, success: false }
      let(:batch) { OpenStruct.new(crop: 'Corn') }
      subject { described_class.new(ctx, integration) }

      it 'returns nil' do
        allow(subject).to receive(:get_transaction).and_return transaction
        allow(subject).to receive(:get_batch).and_return batch
        expect(subject.call).to be_nil
      end
    end

    describe 'metrc#create_plant_batches' do
      subject { described_class.new(ctx, integration) }
      now = Time.zone.now
      let(:transaction) { stub_model Transaction, type: :start_batch, success: false }

      before :all do
        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
          .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,barcodes,items,custom_data,seeding_unit,harvest_unit,sub_zone')
          .to_return(body: {
            data: {
              id: '2002',
              type: 'batches',
              attributes: {
                id: 2002,
                arbitrary_id: 'Jun19-Bok-Cho',
                quantity: '100',
                crop_variety: 'Banana Split',
                seeded_at: now,
                zone_name: 'Germination',
                crop: 'Cannabis'
              }
            },
            included: [
              {
                id: '1234',
                type: 'zones',
                attributes: {
                  id: 1234,
                  seeding_unit: {
                    name: 'Clone'
                  }
                }
              }
            ]
          }.to_json)
      end

      it 'calls metrc#create_plant_batches method' do
        allow(subject).to receive(:get_transaction).and_return transaction

        expected_payload = [
          {
            Name: '1A4FF01000000220000010',
            Type: 'Clone',
            Count: 100,
            Strain: 'Banana Split',
            Room: 'Germination',
            PatientLicenseNumber: nil,
            ActualDate: now
          }
        ]

        allow(subject).to receive(:build_start_payload).and_return(expected_payload.first)
        allow(subject.instance_variable_get(:@client)).to receive(:create_plant_batches).with(integration.vendor_id, expected_payload).and_return(nil)

        transaction = subject.call
        expect(transaction.success).to eq true
      end
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
      instance = described_class.new(ctx, integration)
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
