require 'rails_helper'

RSpec.describe ScheduledJob, type: :job do
  include ActiveJob::TestHelper

  subject { described_class.perform_later }
  let(:account) { Account.create(artemis_id: 'ohai', name: 'Jon Snow') }
  let(:integration) { Integration.create(secret: 'jonisdany\'snephew', key: 'jonsnow', state: :cb, account: account, facility_id: 1568, vendor: :metrc, vendor_id: 'LIC-0001') }
  let(:now) { DateTime.now.utc }

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

  context 'with a scheduled task', skip: 'Check why the vendor module returns nil' do
    it 'calls the vendor module' do
      Scheduler.create(integration: integration,
                       facility_id: integration.facility_id,
                       batch_id: 3000,
                       run_on: now)

      beginning_of_hour = now.beginning_of_hour
      end_of_hour       = now.end_of_hour
      tasks = Scheduler.all

      # allow(MetrcService::Batch).to receive(:call) { nil }

      expect(Scheduler).to receive(:where).with(hash_including(run_on: beginning_of_hour..end_of_hour))
                                          .and_return(tasks)
      expect(MetrcService::Batch).to receive(:new)

      perform_enqueued_jobs { subject }
    end
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end
end
