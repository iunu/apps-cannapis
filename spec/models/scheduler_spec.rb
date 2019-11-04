require 'rails_helper'

RSpec.describe Scheduler, type: :model do
  it { should belong_to(:integration) }
  it { should validate_presence_of(:facility_id) }
  it { should validate_presence_of(:batch_id) }
  it { should validate_presence_of(:integration_id) }
  it { should validate_presence_of(:run_on) }
end
