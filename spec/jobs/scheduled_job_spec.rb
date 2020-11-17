require 'rails_helper'

RSpec.describe ScheduledJob, type: :job do
  include ActiveJob::TestHelper

  subject { described_class.perform_later }

  let(:integration) { create(:integration) }

  let(:now) { Time.now.utc }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it 'enqueues a new scheduled job' do
    expect { subject }.to have_enqueued_job(described_class)
      .on_queue('default')
  end

  describe 'with no scheduled tasks' do
    before do
      Scheduler.delete_all
    end

    it 'does not call the vendor module' do
      beginning_of_hour = now.beginning_of_hour
      end_of_hour       = now.end_of_hour

      allow(Scheduler).to receive(:where)
        .with(hash_including(run_on: beginning_of_hour..end_of_hour))
        .and_return([])

      perform_enqueued_jobs { subject }
    end
  end

  context 'with a scheduled task' do
    let(:successful_transaction) { create(:transaction, :start, :successful) }
    let(:task) { create(:task, integration: integration, facility_id: integration.facility_id, batch_id: 3000, run_on: now) }
    let(:service_action) { double(:action, run: true, result: true) }

    it 'calls the vendor module' do
      allow_any_instance_of(MetrcService::Batch).to receive(:call)
      perform_enqueued_jobs { subject }
    end
  end

  describe 'on a failing task' do
    let(:original_error) { double(:original_error) }
    let(:mailer_with_params) { double(:mailer) }
    let(:email) { double(:email, deliver_now: nil) }
    let(:batch) { MetrcService::Batch }
    let(:mailer) { double(NotificationMailer) }

    before do
      create(:task, integration: integration, facility_id: integration.facility_id, batch_id: 3000, run_on: now)

      allow(batch)
        .to receive(:call)
        .and_raise(raised_error)
    end

    describe 'that can be rescheduled' do
      let(:raised_error) { Cannapi::RetryableError.new('something went wrong', original: original_error) }

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{integration.facility_id}")
          .to_return(body: '{}')
      end

      it 'enqueues the job' do
        perform_enqueued_jobs { subject }
      end
    end

    describe 'that can NOT be rescheduled due to too many retries' do
      let(:raised_error) { Cannapi::TooManyRetriesError.new('something went wrong too many times', original: original_error) }

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{integration.facility_id}")
          .to_return(body: '')
      end

      it 'enqueues the job' do
        expect_any_instance_of(TaskRunner)
          .to receive(:report_failed)

        perform_enqueued_jobs { subject }
      end
    end

    context 'when it can NOT be rescheduled due to non-retryable error' do
      let(:raised_error) { StandardError.new('something unexpected went wrong') }
      let(:original_error) { raised_error }

      before do
        stub_request(:get, "#{ENV['ARTEMIS_BASE_URI']}/api/v3/facilities/#{integration.facility_id}")
          .to_return(status: 200, body: '{}', headers: {})
      end

      it 'enqueues the job' do
        expect_any_instance_of(TaskRunner)
          .to receive(:report_failed)

        perform_enqueued_jobs { subject }
      end
    end
  end
end
