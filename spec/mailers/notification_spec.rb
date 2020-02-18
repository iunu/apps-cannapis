require "rails_helper"

RSpec.describe NotificationMailer, type: :mailer do
  let(:account) { create(:account) }
  let(:artemis_user) { double(:artemis_user, id: 123, full_name: 'Joey Ramone', email: 'jr@somedomain.com') }
  let(:integration) { create(:integration, account: account) }
  let(:task) { double(:task, integration: integration, action_name: 'test', attempt: 2) }
  let(:error) { StandardError.new('something went wrong') }

  before do
    expect(account.client)
      .to receive(:current_user)
      .and_return(artemis_user)
  end

  describe '#report_failure_email' do
    let(:mail) do
      NotificationMailer
        .with(task: task, error: error)
        .report_failure_email
    end

    it 'renders the headers' do
      expect(mail.subject).to match(/\[Artemis -> Metrc\] Task failed: test for user 123/)
      expect(mail.to).to eq(['customersuccess@artemisag.com'])
      expect(mail.from).to eq(['support@artemisag.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match(/An error occurred.*maximum number of attempts.*Metrc.*test.*123.*Joey Ramone <jr@somedomain.com>.*something went wrong/im)
    end
  end

  describe '#report_reschedule_email' do
    let(:mail) do
      NotificationMailer
        .with(task: task, error: error)
        .report_reschedule_email
    end

    it 'renders the headers' do
      expect(mail.subject).to match(/\[Artemis -> Metrc\] Task rescheduled \(attempt 2\): test for user 123/)
      expect(mail.to).to eq(['customersuccess@artemisag.com'])
      expect(mail.from).to eq(['support@artemisag.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match(/An error occurred.*Attempt number 2 has been rescheduled.*Metrc.*test.*123.*Joey Ramone <jr@somedomain.com>.*something went wrong/im)
    end
  end
end
