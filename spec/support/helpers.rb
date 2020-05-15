module Helpers
  def load_response_json(path)
    File.read("spec/support/data/#{path}.json")
  end
end
