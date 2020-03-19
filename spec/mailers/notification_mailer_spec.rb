require 'rails_helper'

RSpec.describe NotificationMailer, type: :mailer do
  let(:account) { create(:account) }
  let(:artemis_user) { double(:artemis_user, id: 123, full_name: 'Joey Ramone', email: 'jr@somedomain.com') }
  let(:integration) { create(:integration, account: account) }
  let(:task) { create(:task, integration: integration, attempts: 2, batch_id: 420, current_action: 'metrc_service/plant/start') }
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
      expect(mail.subject).to eq('[Artemis -> Metrc] Task failed: metrc_service/plant/start for user 123')
      expect(mail.to).to eq([ENV['NOTIFICATION_RECIPIENT']])
      expect(mail.from).to eq(['support@artemisag.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match(%r{An error occurred.*maximum number of attempts.*Metrc.*420.*123.*Joey Ramone <jr@somedomain.com>.*metrc_service/plant/start.*something went wrong}im)
    end
  end

  describe '#report_reschedule_email' do
    let(:mail) do
      NotificationMailer
        .with(task: task, error: error)
        .report_reschedule_email
    end

    it 'renders the headers' do
      expect(mail.subject).to eq('[Artemis -> Metrc] Task rescheduled (attempts 2): metrc_service/plant/start for user 123')
      expect(mail.to).to eq([ENV['NOTIFICATION_RECIPIENT']])
      expect(mail.from).to eq(['support@artemisag.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match(%r{An error occurred.*Attempt number 2 has been scheduled.*Metrc.*420.*123.*Joey Ramone <jr@somedomain.com>.*metrc_service/plant/start.*something went wrong}im)
    end
  end
end
