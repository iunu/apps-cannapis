# frozen_string_literal: true

require 'rails_helper'

RSpec.describe(TaskRunner) do
  def load_response_json(path)
    File.read("spec/support/data/#{path}.json")
  end

  describe '.run' do
    let(:batch_id) { 374 }
    let(:facility_id) { 2 }
    let(:task) { create(:task, batch_id: batch_id, facility_id: facility_id) }

    subject { described_class.run(task) }

    before do
      stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}")
        .to_return(status: 200, body: load_response_json('task_runner/facility'))

      stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}/batches/#{batch_id}?include=zone,zone.sub_stage,barcodes,completions,custom_data,seeding_unit,harvest_unit,sub_zone")
        .to_return(status: 200, body: load_response_json('task_runner/batch'))

      stub_request(:get, "https://portal.artemisag.com/api/v3/facilities/#{facility_id}/completions?filter%5Bcrop_batch_ids%5D%5B0%5D=#{batch_id}")
        .to_return(status: 200, body: load_response_json('task_runner/batch-completions'))
    end

    context 'when job completes successfully' do
      before do
        expect(MetrcService::Plant::Start)
          .to receive(:call)
          .and_return(successful_transaction)
      end

      let(:successful_transaction) { create(:transaction, :start, :successful) }

      it { is_expected.to be_an(Array) }

      it 'returns a successful transaction' do
        expect(subject.all?(&:success?)).to eq(true)
      end
    end

    context 'when job fails with retryable error' do
      before do
        expect(Bugsnag)
          .to receive(:notify)

        expect_any_instance_of(Metrc::Client)
          .to receive(:send)
          .and_raise(Metrc::RequestError)

        expect_any_instance_of(NotificationMailer)
          .to receive(:report_reschedule_email)

        stub_request(:get, 'https://portal.artemisag.com/api/v3/user')
          .to_return(status: 200, body: { data: { attributes: { full_name: 'Jimmy Two Times', email: 'jtt@cosanostra.it' } } }.to_json)
      end

      it 'raises an error' do
        expect { subject }.to raise_error(Cannapi::TaskError)
      end
    end
  end
end
