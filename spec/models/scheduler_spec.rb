require 'rails_helper'

RSpec.describe Scheduler, type: :model do
  it { should belong_to(:integration) }
  it { should validate_presence_of(:facility_id) }
  it { should validate_presence_of(:batch_id) }
  it { should validate_presence_of(:integration_id) }
  it { should validate_presence_of(:run_on) }

  context '#attempts' do
    subject { create(:task) }
    it { is_expected.to have_attributes(attempts: 0) }

    context 'after reschedule' do
      before { subject.reschedule! }
      it { is_expected.to have_attributes(attempts: 1) }
    end

    context 'too many reschedules' do
      before do
        subject.update!(attempts: Scheduler::MAX_ATTEMPTS - 1)
      end

      it 'should raise an error' do
        expect { subject.reschedule! }.to raise_error(ScheduledJob::TooManyRetriesError)
      end
    end
  end
end
