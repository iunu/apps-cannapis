require 'rails_helper'

RSpec.describe Account, type: :model do
  it { should have_many(:integrations) }
  it { should have_many(:transactions) }
end
