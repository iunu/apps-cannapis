class HomeController < ApplicationController
  def index
    @current_account = Account.find_by(id: session[:current_account_id])
    return unless @current_account

    begin
      client = @current_account.client

      @facilities   = client.facilities
      @integrations = Integration.active.where(account_id: @current_account.id).index_by(&:facility_id)
    rescue OAuth2::Error
      session[:current_account_id] = nil
      redirect_to root_path
    end
  end
end
