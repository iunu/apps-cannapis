require 'rails_helper'

RSpec.describe ApplicationService do
  subject { described_class.call }

  it.skip { expect(subject).to be_a(ApplicationService) }
end
