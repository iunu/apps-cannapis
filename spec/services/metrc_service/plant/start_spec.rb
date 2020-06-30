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
          zone_name: 'Germination',
          quantity: '100'
        }
      },
      completion_id: 1001
    }.with_indifferent_access
  end

  describe '#call' do
    subject { described_class.call(ctx, integration) }

    describe 'on an old successful transaction' do
      let(:transaction) { create(:transaction, :start, :successful) }
      let(:ctx) do
        {
          id: 3000,
          relationships: {
            batch: { data: { id: 2002 } },
            facility: { data: { id: 1568 } }
          },
          attributes: {
            options: {
              quantity: '100'
            }
          },
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

    describe '#create_plant_batch' do
      describe '#create_plant_batches' do
        let(:now) { Time.zone.now.strftime('%Y-%m-%d') }
        let(:transaction) { create(:transaction, :start, :unsuccessful) }
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

          stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field')
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

          expect_any_instance_of(described_class)
            .to receive(:get_transaction)
            .and_return transaction

          expect_any_instance_of(described_class)
            .to receive(:build_start_payload)
            .and_return(expected_payload)
        end

        it 'is successful' do
          expect(subject).to be_success
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
                    quantity: '100',
                    crop_variety: 'Banana Split',
                    seeded_at: Time.zone.now,
                    relationships: {
                      'barcodes': { 'data': [{ 'id': '1A4FF0100000022000001010' }] }
                    }.with_indifferent_access)
          end

          subject { described_class.new(ctx, integration) }

          it 'returns a valid payload' do
            expect_any_instance_of(described_class)
              .to receive(:batch)
              .at_least(:once)
              .and_return(batch)
            payload = subject.send(:build_start_payload).first

            expect(payload).not_to be_nil
            expect(payload[:Name]).to eq '1A4FF0100000022000001010'
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
                  zone_name: 'Germination',
                  quantity: '100'
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
                    quantity: '100',
                    crop_variety: 'Banana Split',
                    seeded_at: Time.zone.now,
                    relationships: {
                      barcodes: {
                        'data': [{ 'type': :barcodes, 'id': '1A4FF0100000022000001101' }]
                      }
                    }.with_indifferent_access)
          end

          subject { described_class.new(ctx, integration) }

          it 'returns a valid payload using the batch barcode' do
            expect_any_instance_of(described_class)
              .to receive(:batch)
              .at_least(:once)
              .and_return(batch)
            payload = subject.send(:build_start_payload).first

            expect(payload).not_to be_nil
            expect(payload[:Name]).to eq '1A4FF0100000022000001101'
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

    describe '#create_plantings_from_package' do
      subject { described_class.call(ctx, integration) }

      describe '#create_plantings_from_package_payload' do
        context 'with no custom data', skip: 'Notifies Bugsnag?' do
          let(:now) { Time.zone.now.strftime('%Y-%m-%d') }

          before do
            stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
              .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

            stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field')
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
                    },
                    'custom_data': {
                      'data': [
                        {
                          'type': 'custom_data',
                          'id': '66998'
                        }
                      ]
                    },
                    'barcodes': {
                      'data': [
                        {
                          'type': 'barcodes',
                          'id': '1A406020000E4E9000003989'
                        }
                      ]
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
                  },
                  {
                    id: '66998',
                    type: 'custom_data',
                    attributes: {
                      id: 66998,
                      value: '1A4060300003779000013229',
                      crop_batch_id: 108064,
                      custom_field_id: 407
                    },
                    relationships: {
                      custom_field: {
                        data: {
                          id: '407',
                          type: 'custom_fields'
                        }
                      },
                      crop_batch: {
                        data: {
                          id: '2002',
                          type: 'crop_batches'
                        }
                      }
                    }
                  },
                  {
                    id: '407',
                    type: 'custom_fields',
                    attributes: {
                      id: 407,
                      name: 'Source Package Id (Metrc)',
                      organization_id: 1062,
                      position: 0,
                      kind: 'text',
                      status: 'active'
                    },
                    relationships: {
                      stage: {
                        data: {
                          id: '1068',
                          type: 'stages'
                        }
                      }
                    }
                  }
                ]
              }.to_json)

            stub_request(:post, 'https://sandbox-api-ca.metrc.com/packages/v1/create/plantings?licenseNumber=LIC-0001')
              .with(body: [{Name: '1A4FF01000000220000010', Type: 'Clone', Count: 100, Strain: 'Banana Split', Location: 'Germination', PatientLicenseNumber: nil, ActualDate: now}].to_json)
              .to_return(status: 200, body: '', headers: {})
          end

          it 'returns raises an Invalid Operation exception' do
            expect { subject.send(:create_plantings_from_package_payload) }.to raise_error(InvalidOperation)
          end
        end
      end

      context 'when planting are teens' do
        let(:now) { Time.zone.now.strftime('%Y-%m-%d') }
        let(:transaction) { create(:transaction, :unsuccessful, type: :start_batch_from_package) }
        let(:expected_payload) do
          [{
            PackageLabel: 'Latiff',
            PackageAdjustmentAmount: 0,
            PackageAdjustmentUnitOfMeasureName: 'Ounces',
            PlantBatchName: '1A4060300003B01000000838',
            PlantBatchType: 'Clone',
            PlantCount: 100,
            LocationName: 'Flowering',
            RoomName: 'Flowering',
            StrainName: 'Banana Split',
            PatientLicenseNumber: nil,
            PlantedDate: '2019-10-01',
            UnpackagedDate: '2019-10-01'
          }]
        end

        before do
          stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
            .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

          stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field')
            .to_return(body: load_response_json('api/seed/batch-96182'))

          stub_request(:post, 'https://sandbox-api-ca.metrc.com/packages/v1/create/plantings?licenseNumber=LIC-0001')
            .with(body: expected_payload.to_json)
            .to_return(status: 200, body: '', headers: {})

          stub_request(:post, 'https://sandbox-api-ca.metrc.com/plantbatches/v1/changegrowthphase?licenseNumber=LIC-0001')
            .with(body: [{
              Name: '1A4060300003B01000000838',
              Count: 100,
              StartingTag: nil,
              GrowthPhase: 'Clone',
              NewLocation: 'Flowering',
              GrowthDate: nil,
              PatientLicenseNumber: nil
            }].to_json)
            .to_return(status: 200, body: '', headers: {})

          stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/completions?filter%5Baction_type%5D=generate&filter%5Bparent_id%5D=3000')
            .to_return(status: 204, body: '', headers: {})
        end

        it 'is successful' do
          expect_any_instance_of(described_class)
            .to receive(:get_transaction)
            .and_return transaction

          expect(subject).to be_success
        end
      end
    end

    describe '#create_plantings_from_source_plant' do
      subject { described_class.call(ctx, integration) }

      describe '#create_plantings_from_source_plant_payload' do
        context 'with no custom data', skip: 'Notifies Bugsnag?' do
          let(:now) { Time.zone.now.strftime('%Y-%m-%d') }

          before do
            stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
              .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

            stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field')
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
                    },
                    'custom_data': {
                      'data': [
                        {
                          'type': 'custom_data',
                          'id': '66998'
                        }
                      ]
                    },
                    'barcodes': {
                      'data': [
                        {
                          'type': 'barcodes',
                          'id': '1A406020000E4E9000003989'
                        }
                      ]
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
                  },
                  {
                    id: '66998',
                    type: 'custom_data',
                    attributes: {
                      id: 66998,
                      value: '1A4060300003779000013229',
                      crop_batch_id: 108064,
                      custom_field_id: 407
                    },
                    relationships: {
                      custom_field: {
                        data: {
                          id: '407',
                          type: 'custom_fields'
                        }
                      },
                      crop_batch: {
                        data: {
                          id: '2002',
                          type: 'crop_batches'
                        }
                      }
                    }
                  },
                  {
                    id: '407',
                    type: 'custom_fields',
                    attributes: {
                      id: 407,
                      name: 'Source Package Id (Metrc)',
                      organization_id: 1062,
                      position: 0,
                      kind: 'text',
                      status: 'active'
                    },
                    relationships: {
                      stage: {
                        data: {
                          id: '1068',
                          type: 'stages'
                        }
                      }
                    }
                  }
                ]
              }.to_json)

            stub_request(:post, 'https://sandbox-api-ca.metrc.com/packages/v1/create/plantings?licenseNumber=LIC-0001')
              .with(body: [{Name: '1A4FF01000000220000010', Type: 'Clone', Count: 100, Strain: 'Banana Split', Location: 'Germination', PatientLicenseNumber: nil, ActualDate: now}].to_json)
              .to_return(status: 200, body: '', headers: {})
          end

          it 'returns raises an Invalid Operation exception' do
            expect { subject.send(:create_plantings_from_source_plant_payload) }.to raise_error(InvalidOperation)
          end
        end
      end

      context 'with a source plant' do
        let(:now) { Time.zone.now.strftime('%Y-%m-%d') }
        let(:transaction) { create(:transaction, :unsuccessful, type: :start_batch_from_source_plant) }
        let(:expected_payload) do
          [{
            Id: nil,
            PlantBatch: '1A4060300003B01000000838',
            Count: 100,
            Location: 'Flowering',
            Room: 'Flowering',
            Item: 'Immature Plants',
            Tag: '1A4060300003B01000000837',
            PatientLicenseNumber: nil,
            Note: nil,
            IsTradeSample: false,
            IsDonation: false,
            ActualDate: '2019-10-01'
          }]
        end

        before do
          stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568')
            .to_return(body: { data: { id: '1568', type: 'facilities', attributes: { id: 1568, name: 'Rare Dankness' } } }.to_json)

          stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/batches/2002?include=zone,zone.sub_stage,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone,custom_data.custom_field')
            .to_return(body: load_response_json('api/seed/batch-96183'))

          stub_request(:post, 'https://sandbox-api-ca.metrc.com/plantbatches/v1/create/plantings?licenseNumber=LIC-0001')
            .with(body: expected_payload.to_json)
            .to_return(status: 200, body: '', headers: {})

          stub_request(:get, 'https://portal.artemisag.com/api/v3/facilities/1568/completions?filter%5Baction_type%5D=generate&filter%5Bparent_id%5D=3000')
            .to_return(status: 204, body: '', headers: {})
        end

        it 'is successful' do
          expect_any_instance_of(described_class)
            .to receive(:get_transaction)
            .and_return transaction

          expect(subject).to be_success
        end
      end
    end
  end
end
