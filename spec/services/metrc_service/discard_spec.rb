require 'rails_helper'

RSpec.describe MetrcService::Discard do
  let(:account) { create(:account) }
  let(:integration) { create(:integration, account: account) }
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
      attributes: {
        options: {
          tracking_barcode: '1A4FF01000000220000010',
          note_content: 'And the only prescription is moar cow bell'
        }
      },
      completion_id: 1001
    }.with_indifferent_access
  end

  context '#call' do
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
        completion_id: 1001
      }
    end
    subject { described_class.new(ctx, integration) }


    describe 'on an old successful transaction' do
      let(:transaction) { create(:transaction, :successful, :discard, account: account, integration: integration) }

      it 'returns the transaction' do
        allow(subject).to receive(:get_transaction).and_return transaction
        expect(subject.call).to eq transaction
      end
    end

    describe 'with corn crop' do
      let(:transaction) { create(:transaction, :unsuccessful, :discard, account: account, integration: integration) }
      let(:batch) { OpenStruct.new(crop: 'Corn') }

      it 'returns nil' do
        allow(subject).to receive(:get_transaction).and_return transaction
        allow(subject).to receive(:get_batch).and_return batch
        expect(subject.call).to be_nil
      end
    end

    describe 'metrc#destroy_plant_batches', skip: 'WIP' do
      now = Time.zone.now
      let(:transaction) { create(:transaction, :unsucceed, :discard) }

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

  context '#build_immature_payload' do
    it 'returns a valid payload' do
      now = DateTime.now
      discard = OpenStruct.new(attributes: {
        quantity: '1',
        discarded_at: now
      }.with_indifferent_access)
      batch = OpenStruct.new(arbitrary_id: 'Oct1-Ban-Spl-Can')

      instance = described_class.new(ctx, integration)
      payload = instance.send :build_immature_payload, discard, batch

      expect(payload.size).to eq 1
      expect(payload.first).to eq({
        PlantBatch: 'Oct1-Ban-Spl-Can',
        Count: 1,
        ReasonNote: 'Does not meet internal QC',
        ActualDate: now
      })
    end
  end

  context '#build_mature_payload' do
    describe 'on partial dumps' do
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
          attributes: {
            options: {
              tracking_barcode: '1A4FF01000000220000010',
              note_content: 'And the only prescription is moar cow bell',
              discard_type: 'partial',
              barcode: '1A4FF01000000220000010'
            }
          },
          completion_id: 1001
        }.with_indifferent_access
      end

      it 'returns a valid payload' do
        now = DateTime.now
        discard = OpenStruct.new(attributes: {
          discarded_at: now
        }.with_indifferent_access)
        instance = described_class.new(ctx, integration)
        payload = instance.send :build_mature_payload, discard, nil

        expect(payload.size).to eq 1
        expect(payload.first).to eq({
          Id: nil,
          Label: '1A4FF01000000220000010',
          ReasonNote: 'Does not meet internal QC',
          ActualDate: now
        })
      end
    end
  end

  context '#reason_note' do
    describe 'with no type nor description' do
      it 'returns the expected text' do
        discard = OpenStruct.new(attributes: {})
        instance = described_class.new(ctx, integration)
        note = instance.send :reason_note, discard

        expect(note).to eq 'Does not meet internal QC'
      end
    end

    describe 'with type but no description' do
      it 'returns the expected text' do
        discard = OpenStruct.new(attributes: {
          reason_type: 'Other'
        }.with_indifferent_access)
        instance = described_class.new(ctx, integration)
        note = instance.send :reason_note, discard

        expect(note).to eq 'Does not meet internal QC'
      end
    end

    describe 'with type and description' do
      it 'returns the expected text' do
        discard = OpenStruct.new(attributes: {
          reason_type: 'other',
          reason_description: 'I got a fever'
        }.with_indifferent_access)
        instance = described_class.new(ctx, integration)
        note = instance.send :reason_note, discard

        expect(note).to eq 'Other: I got a fever. And the only prescription is moar cow bell'
      end
    end
  end
end
