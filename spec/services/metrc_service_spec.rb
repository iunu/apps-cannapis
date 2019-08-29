require 'rails_helper'

RSpec.describe MetrcService do
  subject { described_class.call }

  it.skip { expect(subject).to be_a(MetrcService) }
end
