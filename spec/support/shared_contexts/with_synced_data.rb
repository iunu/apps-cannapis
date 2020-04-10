# frozen_string_literal: true

RSpec.shared_context('with synced data') do
  def read_file(name)
    File.read(Rails.root.join("spec/support/#{name}"))
  end

  def load_response_json(path)
    read_file("data/#{path}.json")
  end

  let(:facility_id) { raise 'define +facility_id+ in your context' }
  let(:batch_id) { raise 'define +batch_id+ in your context' }
end
