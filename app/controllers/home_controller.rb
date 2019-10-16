class HomeController < ApplicationController
  def index
    @current_account = Account.find_by(id: session[:current_account_id])
    return unless @current_account

    begin
      client = @current_account.client
      @current_account.refresh_token_if_needed

      @facilities   = client.facilities
      @integrations = Integration.active.where(account_id: @current_account.id).index_by(&:facility_id)
    rescue OAuth2::Error
      @current_account.update(access_token: nil,
                              refresh_token: nil,
                              access_token_expires_in: nil,
                              access_token_created_at: nil)

      session[:current_account_id] = nil
      redirect_to root_path
    end
  end
end
