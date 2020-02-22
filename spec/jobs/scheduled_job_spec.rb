require 'rails_helper'

RSpec.describe ScheduledJob, type: :job do
  include ActiveJob::TestHelper

  subject { described_class.perform_later }
  let(:integration) { create(:integration) }
  let(:now) { Time.now.utc }

  before :all do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'enqueues a new scheduled job' do
    expect { subject }.to have_enqueued_job(described_class)
      .on_queue('default')
  end

  context 'with no scheduled tasks' do
    before :all do
      Scheduler.delete_all
    end

    it 'does not call the vendor module' do
      beginning_of_hour = now.beginning_of_hour
      end_of_hour       = now.end_of_hour

      expect(Scheduler).to receive(:where).with(hash_including(run_on: beginning_of_hour..end_of_hour))
                                          .and_return([])

      perform_enqueued_jobs { subject }
    end
  end

  context 'with a scheduled task' do
    let(:task) { create(:task, integration: integration, facility_id: integration.facility_id, batch_id: 3000, run_on: now) }

    it 'calls the vendor module' do
      beginning_of_hour = now.beginning_of_hour
      end_of_hour       = now.end_of_hour

      # allow(MetrcService::Batch).to receive(:new)
      allow_any_instance_of(MetrcService::Batch).to receive(:call)
      expect(Scheduler).to receive(:where).with(hash_including(run_on: beginning_of_hour..end_of_hour))
                                          .and_return([task])

      service_action = double(:action, run: true, result: true)
      expect(MetrcService::Batch).to receive(:new).and_return(service_action)

      perform_enqueued_jobs { subject }
    end
  end

  context 'with a failing task' do
    let(:task) { create(:task, integration: integration, facility_id: integration.facility_id, batch_id: 3000, run_on: now) }
    let(:original_error) { double(:original_error) }
    let(:mailer_with_params) { double(:mailer) }
    let(:email) { double(:email, deliver_now: nil) }

    before do
      expect(MetrcService::Batch)
        .to receive(:call)
        .and_raise(raised_error)

      expect(NotificationMailer)
        .to receive(:with)
        .with(task: task, error: original_error)
        .and_return(mailer_with_params)
    end

    context 'that can be rescheduled' do
      let(:raised_error) { ScheduledJob::RetryableError.new('something went wrong', original: original_error) }

      before do
        expect(mailer_with_params)
          .to receive(:report_reschedule_email)
          .and_return(email)
      end

      it 'should execute' do
        perform_enqueued_jobs { subject }
      end
    end

    context 'that can NOT be rescheduled due to too many retries' do
      let(:raised_error) { ScheduledJob::TooManyRetriesError.new('something went wrong too many times', original: original_error) }

      before do
        expect(mailer_with_params)
          .to receive(:report_failure_email)
          .and_return(email)
      end

      it 'should execute' do
        perform_enqueued_jobs { subject }
      end
    end

    context 'that can NOT be rescheduled due to non-retryable error' do
      let(:raised_error) { StandardError.new('something unexpected went wrong') }
      let(:original_error) { raised_error }

      before do
        expect(mailer_with_params)
          .to receive(:report_failure_email)
          .and_return(email)
      end

      it 'should execute' do
        perform_enqueued_jobs { subject }
      end
    end
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end
end
