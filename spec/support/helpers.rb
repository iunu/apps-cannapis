module Helpers
  def load_response_json(path)
    File.read("spec/support/data/#{path}.json")
  end

  def artemis_client
    @artemis_client ||= ArtemisApi::Client.new(
      access_token: 'abc.def.ghi',
      refresh_token: '123abc',
      expires_at: (Time.now + 2.days).to_i
    )
  end

  def create_response(path, status = 200)
    body = load_response_json(path)
    instance_double('Response', body: body, status: status)
  end
end
