require 'rails_helper'
require 'ostruct'

RSpec.describe MetrcService::Plant::Start do
  let(:integration) { create(:integration, state: 'ca') }
  let(:ctx) do
    {
      id: 3000,
      relationships: {
        batch: { data: { id: 2002 } },
        facility: { data: { id: 1568 } }
      },
      attributes: {
        options: {
          tracking_barcode: '1A4FF01000000220000010',
          zone_name: 'Germination'
        }
      },
      completion_id: 1001
    }.with_indifferent_access
  end

  describe '#call' do
    subject { described_class.call(ctx, integration) }

    describe 'on an old successful transaction' do
      let(:transaction) { stub_model Transaction, type: :start_batch, success: true }
      let(:ctx) do
        {
          id: 3000,
          relationships: {
            batch: { data: { id: 2002 } },
            facility: { data: { id: 1568 } }
          },
          attributes: {},
          completion_id: 1001
        }
      end

      before do
        allow_any_instance_of(described_class)
          .to receive(:get_transaction)
          .and_return(transaction)
      end

      it { is_expected.to eq(transaction) }
    end

    describe 'with corn crop' do
      include_examples 'with corn crop'
    end

    describe '#create_plant_batches' do
      subject { described_class.call(ctx, integration) }

      let(:now) { Time.zone.now.strftime('%Y-%m-%d') }
      let(:transaction) { stub_model Transaction, type: :start_batch, success: false }
      let(:expected_payload) do
        [
          {
            Name: '1A4FF01000000220000010',
            Type: 'Clone',
            Count: 100,
            Strain: 'Banana Split',
            Location: 'Germination',
            PatientLicenseNumber: nil,
            ActualDate: now
          }
        ]
      end

      before do
        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
          .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone')
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
              },
              relationships: {
                'seeding_unit': {
                  'data': {
                    'id': '1235',
                    'type': 'seeding_units'
                  }
                }
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
              },
              {
                id: '1235',
                type: 'seeding_units',
                attributes: {
                  id: 1235,
                  item_tracking_method: 'preprinted',
                  name: 'Clone'
                }
              }
            ]
          }.to_json)

        stub_request(:post, 'https://sandbox-api-ca.metrc.com/plantbatches/v1/createplantings?licenseNumber=LIC-0001')
          .with(body: "[{\"Name\":\"1A4FF01000000220000010\",\"Type\":\"Clone\",\"Count\":100,\"Strain\":\"Banana Split\",\"Location\":\"Germination\",\"PatientLicenseNumber\":null,\"ActualDate\":\"#{now}\"}]")
          .to_return(status: 200, body: '', headers: {})
      end

      it 'is successful' do
        expect_any_instance_of(described_class)
          .to receive(:get_transaction)
          .and_return transaction

        expect_any_instance_of(described_class)
          .to receive(:build_start_payload)
          .and_return(expected_payload)

        expect(subject).to be_success
      end
    end
  end

  describe '#build_start_payload' do
    context 'with tracking barcode' do
      let(:batch) do
        zone_attributes = {
          seeding_unit: {
            name: 'Clone'
          }
        }.with_indifferent_access
        zone = double(:zone, attributes: zone_attributes, name: 'Germination')

        double(:batch,
               zone: zone,
               relationships: {
                 'barcodes': { 'data': [{ 'id': '1A4FF01000000220000010' }] }
               }.with_indifferent_access,
               attributes: {
                 quantity: '100',
                 crop_variety: 'Banana Split',
                 seeded_at: Time.zone.now
               }.with_indifferent_access)
      end

      subject { described_class.new(ctx, integration) }

      it 'returns a valid payload' do
        expect_any_instance_of(described_class)
          .to receive(:batch)
          .and_return(batch)
        payload = subject.send(:build_start_payload, batch).first

        expect(payload).not_to be_nil
        expect(payload[:Name]).to eq '1A4FF01000000220000010'
        expect(payload[:Type]).to eq 'Clone'
        expect(payload[:Count]).to eq 100
        expect(payload[:Strain]).to eq 'Banana Split'
        expect(payload[:Location]).to eq 'Germination'
        expect(payload[:PatientLicenseNumber]).to be_nil
        expect(payload[:ActualDate]).not_to be_nil
      end
    end

    describe 'with no tracking barcode' do
      let(:ctx) do
        {
          id: 3000,
          relationships: {
            batch: { data: { id: 2002 } },
            facility: { data: { id: 1568 } }
          },
          attributes: {
            options: {
              zone_name: 'Germination'
            }
          },
          completion_id: 1001
        }.with_indifferent_access
      end

      let(:batch) do
        zone_attributes = {
          seeding_unit: {
            name: 'Plant (Seed)'
          }
        }.with_indifferent_access
        zone = double(:zone, attributes: zone_attributes, name: 'Germination')

        double(:batch,
               zone: zone,
               relationships: {
                 barcodes: {
                   'data': [{ 'type': :barcodes, 'id': '1A4FF01000000220000011' }]
                 }
               }.with_indifferent_access,
               attributes: {
                 quantity: '100',
                 crop_variety: 'Banana Split',
                 seeded_at: Time.zone.now
               }.with_indifferent_access)
      end

      subject { described_class.new(ctx, integration) }

      it 'returns a valid payload using the batch barcode' do
        expect_any_instance_of(described_class)
          .to receive(:batch)
          .and_return(batch)
        payload = subject.send(:build_start_payload, batch).first

        expect(payload).not_to be_nil
        expect(payload[:Name]).to eq '1A4FF01000000220000011'
        expect(payload[:Type]).to eq 'Seed'
        expect(payload[:Count]).to eq 100
        expect(payload[:Strain]).to eq 'Banana Split'
        expect(payload[:Location]).to eq 'Germination'
        expect(payload[:PatientLicenseNumber]).to be_nil
        expect(payload[:ActualDate]).not_to be_nil
      end
    end
  end
end
