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
      '123': OpenStruct.new(vendor_id: '123-ABC', secret: 'DEF')
    }
  end

  before do
    render partial: 'facility', locals: { integrations: integrations, facility: subject }
  end

  it 'renders the form' do
    # integration = integrations[subject.id.to_s.to_sym]
    expect(rendered).to have_tag("form#facility-form-#{subject.id}", with: { action: "/v1/facility/#{subject.id}", method: 'post' }) do
      with_hidden_field 'facility[vendor]', 'metrc'
      with_hidden_field 'facility[state]', subject.state.downcase

      # with_tag :section do
      #   with_button 'Update'

      #   with_tag 'div.my', count: 3 do
      #     with_text_field 'facility[license_number]', integration&.vendor_id
      #     with_text_field 'facility[api_secret]', integration&.secret
      #   end
      # end
    end
  end

  it 'renders the facility name' do
    expect(rendered).to include subject.name
  end

  it 'renders the facility state' do
    expect(rendered).to include subject.state.to_s
  end
end
