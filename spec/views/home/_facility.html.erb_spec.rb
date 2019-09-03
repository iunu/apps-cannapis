require 'rails_helper'

RSpec.describe 'home/_facility', type: :view do
  include RSpecHtmlMatchers
  # Since factory is an object created from the response of a request
  # to the Artemis API, we use an OpenStruct object to stub it
  subject do
    OpenStruct.new(id: 123, name: 'CannaBiz', state: 'NY', city: 'New York')
  end

  let(:integrations) do
    {
      '123': OpenStruct.new(vendor_id: '123-ABC', key: 'ABC', secret: 'DEF')
    }
  end

  before(:each) do
    render partial: 'facility', locals: { integrations: integrations, facility: subject }
  end

  it 'renders the form' do
    # integration = integrations[subject.id.to_s.to_sym]
    expect(rendered).to have_tag("form#facility-form-#{subject.id}", with: { action: "/v1/facility/#{subject.id}", method: 'post' }) do
      with_hidden_field 'facility[vendor]', 'metrc'
      with_hidden_field 'facility[state]', subject.state.downcase
      # with_text_field 'facility[license_number]', integration&.vendor_id
      # with_text_field 'facility[api_key]', integration&.key
      # with_text_field 'facility[api_secret]', integration&.secret
      # with_submit 'Update'
    end
  end

  it 'renders the facility name, city, and state' do
    expect(rendered).to include subject.name
    expect(rendered).to include "#{subject.city}, #{subject.state}"
  end
end