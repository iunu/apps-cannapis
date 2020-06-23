require 'rails_helper'

RSpec.describe Event, type: :model do
  it { is_expected.to validate_presence_of(:facility_id) }
  it { is_expected.to validate_presence_of(:batch_id) }
  it { is_expected.to validate_presence_of(:user_id) }
end
