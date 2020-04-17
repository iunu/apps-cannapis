require 'rails_helper'

RSpec.describe MetrcService::Resource::Waste do
  METRC_API_KEY = ENV['METRC_SECRET_MD'] unless defined?(METRC_API_KEY)

  let(:account) { create(:account) }
  let(:integration) { create(:integration, account: account, state: :md) }
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
          note_content: 'And the only prescription is moar cow bell'
        }
      },
      completion_id: 1001
    }.with_indifferent_access
  end

  describe '#validate_waste_type!' do
    let(:handler) { described_class.new(ctx, integration) }

    subject { handler.send(:validate_waste_type!, waste_type) }

    before do
      stub_request(:get, 'https://sandbox-api-md.metrc.com/harvests/v1/waste/types')
        .to_return(status: 200, body: valid_types.to_json)
    end

    context 'when type is valid' do
      let(:valid_types) { [{ Name: 'Wet Waste' }] }
      let(:waste_type) { 'Wet Waste' }

      it 'should not raise an error' do
        expect { subject }.not_to raise_error
      end
    end

    context 'when type is not valid' do
      let(:valid_types) { [{ Name: 'Plants' }] }

      context 'and not similar to supported types' do
        let(:waste_type) { 'Wet Waste' }

        it 'should not raise an error' do
          expect { subject }.to raise_error(MetrcService::InvalidAttributes, /harvest waste type .* not supported .* No similar types/)
        end
      end

      context 'but similar to supported types' do
        let(:waste_type) { 'Plant' }

        it 'should not raise an error' do
          expect { subject }.to raise_error(MetrcService::InvalidAttributes, /harvest waste type .* not supported .* Did you mean "Plants"/)
        end
      end
    end
  end
end
