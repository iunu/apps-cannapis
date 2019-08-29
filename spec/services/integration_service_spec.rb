require 'rails_helper'

RSpec.describe IntegrationService do
  subject { described_class.call }

  it.skip { expect(subject).to be_a(IntegrationService) }
end
