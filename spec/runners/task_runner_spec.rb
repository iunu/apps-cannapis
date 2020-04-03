# frozen_string_literal: true

require 'rails_helper'

RSpec.describe(TaskRunner) do
  def load_response_json(path)
    File.read("spec/support/data/#{path}.json")
  end

  describe '.run' do
    subject { described_class.run(task) }

    before do
      stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}")
        .to_return(status: 200, body: load_response_json('task_runner/facility'))

      stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,barcodes,completions,custom_data,seeding_unit,harvest_unit,sub_zone")
        .to_return(status: 200, body: load_response_json('task_runner/batch'))

      expect(MetrcService::Plant::Start)
        .to receive(:call)
        .and_return(successful_transaction)
    end

    let(:batch_id) { 374 }
    let(:facility_id) { 2 }
    let(:task) { create(:task, batch_id: batch_id, facility_id: facility_id) }
    let(:successful_transaction) { create(:transaction, :start, :successful) }

    it { is_expected.to be_an(Array) }

    it 'returns a successful transaction' do
      expect(subject.all?(&:success?)).to eq(true)
    end
  end
end
