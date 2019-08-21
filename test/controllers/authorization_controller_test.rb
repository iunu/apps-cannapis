require 'test_helper'

class AuthorizationControllerTest < ActionDispatch::IntegrationTest
  test 'should get authorize' do
    get authorization_authorize_url
    assert_response :success
  end

  test 'should get callback' do
    get authorization_callback_url
    assert_response :success
  end

  test 'should get unauthorize' do
    get authorization_unauthorize_url
    assert_response :success
  end
end
