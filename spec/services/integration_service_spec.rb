require 'rails_helper'

RSpec.describe IntegrationService, sidekiq: :fake do
  let(:account) { create(:account) }
  let(:integration) { create(:integration, account: account, facility_id: 456) }
  let(:params) do
    ActionController::Parameters.new(
      relationships: { facility: { data: { id: 123 } } }
    ).tap(&:permit!)
  end

  subject { described_class.new(params) }

  context 'when there is no integration' do
    it 'raises an exception' do
      expect do
        subject.call
      end.to raise_error 'No integrations for this facility'
    end
  end

  context 'when the integration is not active' do
    it 'raises an exception' do
      expect do
        subject.call
      end.to raise_error 'No integrations for this facility'
    end
  end

  context 'when the integration is active' do
    let(:params) do
      ActionController::Parameters.new(
        relationships: { facility: { data: { id: integration.facility_id } } }
      ).tap(&:permit!)
    end

    subject { described_class.new(params) }

    it 'enqueues the job and does not raise an exception' do
      expect(MetrcService).not_to receive(:run_now?)
      expect(VendorJob).to receive(:perform_later)
      expect { subject.call }.not_to raise_error
    end
  end

  describe 'when #eod...' do
    let(:integration) { create(:integration, eod: "#{eod}:00") }
    let(:batch_id) { 123 }
    let(:params) do
      ActionController::Parameters.new(
        relationships: {
          facility: { data: { id: integration.facility_id } },
          batch: { data: { id: batch_id } }
        }
      ).tap(&:permit!)
    end

    subject { described_class.new(params) }

    describe 'has already passed' do
      let(:eod) { Time.now.utc.hour }
      it 'executes the job immediately' do
        expect(VendorJob).to receive(:perform_later)
        expect(Scheduler).not_to receive(:create)
        expect { subject.call }.not_to raise_error
      end
    end

    describe 'has not yet passed', skip: 'FIXME' do
      let(:eod) { Time.now.utc.hour + 1 }
      let(:completion) { double(:completion, action_type: 'start') }
      let(:seeding_unit) { double(:seeding_unit, name: 'Plant (barcoded)') }
      let(:batch) { double(:batch, id: batch_id, seeding_unit: seeding_unit)  }

      before do
        allow(batch).to receive(:completion).with(any_args).and_return(completion)
        expect_any_instance_of(MetrcService::Lookup).to receive(:batch).at_least(:once).and_return(batch)
        expect(VendorJob).not_to receive(:perform_later)
        expect(Scheduler).to receive(:create)
      end

      it 'enqueues the job' do
        expect { subject.call }.not_to raise_error
      end
    end
  end

  describe 'flushing the job queue', skip: 'FIXME' do
    let(:integration) { create(:integration, eod: "23:00") }
    let(:batch_id) { 123 }
    let(:params) do
      ActionController::Parameters.new(
        relationships: {
          facility: { data: { id: integration.facility_id } },
          batch: { data: { id: batch_id } }
        }
      ).tap(&:permit!)
    end

    let(:completion) { double(:completion, action_type: 'start') }
    let(:seeding_unit) { double(:seeding_unit, name: 'Package') }
    let(:batch) { double(:batch, id: batch_id, seeding_unit: seeding_unit)  }
    let(:service) { described_class.new(params) }

    before do
      allow(batch).to receive(:completion).with(any_args).and_return(completion)
      expect_any_instance_of(MetrcService::Lookup).to receive(:batch).at_least(:once).and_return(batch)
      expect(VendorJob).not_to receive(:perform_later)
      expect(Scheduler).not_to receive(:create)
      expect(TaskRunner).to receive(:run)

      create(
        :task,
        integration: integration,
        facility_id: integration.facility_id,
        batch_id: batch_id
      )
    end

    subject { service }

    it 'executes the job immediately' do
      expect { subject.call }.not_to raise_error
    end
  end
end
