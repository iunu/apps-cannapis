# frozen_string_literal: true

RSpec.shared_context('with synced data') do
  def read_file(name)
    File.read(Rails.root.join("spec/support/#{name}"))
  end

  def load_response_json(path)
    read_file("data/#{path}.json")
  end

  let(:facility_id) { read_file('facility_id').to_i }
  let(:batch_id) { read_file('batch_id').to_i }
end
