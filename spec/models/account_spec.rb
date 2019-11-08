require 'rails_helper'

RSpec.describe Account, type: :model do
  subject { create(:account) }

  it { should have_many(:integrations) }
  it { should have_many(:transactions) }

  context '#client' do
    it 'raises an exception when no tokens are passed' do
      account = create(:account_with_no_tokens)
      expect { account.client }.to raise_exception(ArgumentError)
    end
  end
end
