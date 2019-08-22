class AuthorizationController < ApplicationController
  require 'oauth2'

  def authorize
    client = oauth_client
    url = client.auth_code.authorize_url(redirect_uri: oauth_callback_url)
    redirect_to url
  end

  def callback
    return render json: {}, status: :bad_request unless params[:code]

    client = oauth_client
    token = client.auth_code.get_token(params[:code], redirect_uri: oauth_callback_url)
    account = AuthorizationService.create(token)
    session[:current_account_id] = account.id

    redirect_to root_path
  end

  def unauthorize
    return render json: {}, status: :bad_request unless params[:id]

    account = Account.find(params[:id])
    account.update(access_token: nil,
                   refresh_token: nil,
                   access_token_expires_in: nil,
                   access_token_created_at: nil)
    session[:current_account_id] = nil
    redirect_to root_path
  end

  private

  def oauth_client
    OAuth2::Client.new(ENV['ARTEMIS_OAUTH_APP_ID'], ENV['ARTEMIS_OAUTH_APP_SECRET'], site: ENV['ARTEMIS_BASE_URI'])
  end
end
