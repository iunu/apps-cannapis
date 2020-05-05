require 'rails_helper'

RSpec.describe Common::Utils do
  describe '#normalize_barcode' do
    let(:split_barcode) { '1A4060300003B01000000838-split' }
    let(:barcode) { '1A4060300003B01000000838' }

    subject { described_class.normalize_barcode(split_barcode) }

    it { is_expected.to eq(barcode) }
  end

  describe '#normalize_zone_name' do
    let(:bracket_zone) { 'Flower 1 [Flowering]' }
    let(:zone) { 'Flower 1' }

    subject { described_class.normalize_zone_name(bracket_zone) }

    it { is_expected.to eq(zone) }
  end
end
