require 'rails_helper'

RSpec.describe Integration, type: :model do
  it { should belong_to(:account) }
  it { should have_many(:transactions) }
  it { should have_many(:schedulers) }

  it { should validate_presence_of(:account_id) }
  it { should validate_presence_of(:state) }
  it { should validate_presence_of(:vendor) }
  it { should validate_presence_of(:license) }
  it { should validate_presence_of(:facility_id) }
  it { should validate_presence_of(:eod) }

  describe 'after_create' do
    describe 'runs the set_activated_at callback' do
      it 'sets activated_at to created_at if nil' do
        integration = described_class.create
        integration.activated_at.should == integration.created_at
      end

      it 'activated_at is not overwritten if defined on create' do
        time = Time.now.utc - 1.year
        integration = described_class.create(activated_at: time)
        integration.activated_at.should == time
      end
    end
  end
end
