require 'rails_helper'

RSpec.describe Account, type: :model do
  subject { create(:account) }

  it { should have_many(:integrations) }
  it { should have_many(:transactions) }

  describe '#client' do
    subject { create(:account, :no_tokens) }

    it 'raises an exception when no tokens are passed' do
      expect { subject.client }.to raise_exception(ArgumentError)
    end
  end
end
