require 'rails_helper'

RSpec.describe 'home/index', type: :view do
  describe 'when no session is active' do
    before(:each) do
      render
    end

    it 'renders the authenticate button' do
      expect(rendered).to have_selector 'div.width'
      expect(view.content_for(:header_aux)).to include 'Connect to Artemis'
      expect(view.content_for(:header_aux)).to have_selector '#btn-authorize'
      expect(view.content_for(:header_aux)).not_to have_selector '#btn-unauthorize'
    end

    it 'does not renders the welcome text' do
      expect(rendered).not_to have_selector 'h3'
      expect(rendered).not_to have_selector 'h4'
    end
  end

  describe 'with active session' do
    before(:each) do
      assign :current_account, Account.create(name: 'Jon Snow',
                                              artemis_id: 123,
                                              access_token: 'abc-123',
                                              refresh_token: 'abc-123',
                                              access_token_expires_in: 'abc-123',
                                              access_token_created_at: 'abc-123')
      render
    end

    it 'renders the unauthenticate button' do
      expect(rendered).to have_selector 'div.width'
      expect(view.content_for(:header_aux)).to have_selector '#btn-unauthorize'
      expect(view.content_for(:header_aux)).to include 'Logout'
      expect(view.content_for(:header_aux)).not_to have_selector '#btn-authorize'
    end

    it 'renders the welcome text' do
      expect(rendered).to have_selector 'h3'
      expect(rendered).to include 'Welcome, Jon Snow'
      expect(rendered).not_to include 'These are your facilities'
      expect(rendered).not_to have_selector 'h4'
    end

    it 'does not renders facility partial' do
      expect(view).not_to render_template partial: '_facility'
    end
  end
end
