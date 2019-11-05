require 'rails_helper'

RSpec.describe SubscriptionJob, type: :job do
  include ActiveJob::TestHelper

  let(:account) { Account.create(artemis_id: 'ohai', name: 'Jon Snow') }
  let(:client) { account.client }
  let(:integration) { Integration.create(secret: 'jonisdany\'snephew', key: 'jonsnow', state: :cb, account: account, facility_id: 1568, vendor: :metrc, vendor_id: 'LIC-0001') }
  subject { described_class.perform_later('http://localhost:8080', integration) }

  before :all do
    ActiveJob::Base.queue_adapter = :test
  end

  it 'enqueues a new vendor job' do
    expect { subject }.to have_enqueued_job(described_class)
      .on_queue('default')
  end

  it 'calls the subscription API' do
    integration.account.client
    expect(ArtemisApi::Subscription).to receive(:create).with(facility_id: integration.facility_id,
                                                              subject: :completions,
                                                              destination: 'http://localhost:8080/v1/webhook',
                                                              client: client)
                                                        .and_return(nil)

    perform_enqueued_jobs { subject }
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end
end
