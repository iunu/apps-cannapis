require 'rails_helper'

RSpec.describe PackageJob, type: :job do
  include ActiveJob::TestHelper

  def dummy_method
    1 + 1
  end

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  subject { described_class.perform_later(:dummy_method) }

  it 'queues the job' do
    expect { subject }
      .to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
  end

  it 'calls the method passed as argument' do
    expect { subject }.to have_enqueued_job(described_class)
      .with(:dummy_method)
      .on_queue('default')
  end

  it 'is in urgent queue' do
    expect(described_class.new.queue_name).to eq('default')
  end

  it 'has a wait time of 5 minutes' do
    expect(described_class::WAIT_TIME).to eq(5.minutes)
  end
end
