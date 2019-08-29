require 'rails_helper'

RSpec.describe AuthorizationService do
  subject { described_class.call }

  it.skip { expect(subject).to be_a(AuthorizationService) }
end
