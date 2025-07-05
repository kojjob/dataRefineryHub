require 'rails_helper'

RSpec.describe Api::V1::AuthenticationController, type: :controller do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }

  describe 'POST #login' do
    context 'with valid credentials' do
      it 'returns JWT tokens' do
        post :login, params: { auth: { email: user.email, password: 'password' } }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response['access_token']).to be_present
        expect(json_response['refresh_token']).to be_present
        expect(json_response['token_type']).to eq('Bearer')
        expect(json_response['user']['id']).to eq(user.id)
      end
    end

    context 'with invalid credentials' do
      it 'returns unauthorized' do
        post :login, params: { auth: { email: user.email, password: 'wrong_password' } }

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)

        expect(json_response['error']['message']).to eq('Invalid email or password')
      end
    end
  end

  describe 'GET #me' do
    let(:access_token) { JwtService.generate_access_token(user, organization) }

    context 'with valid JWT token' do
      it 'returns user information' do
        request.headers['Authorization'] = "Bearer #{access_token}"
        get :me

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response['user']['id']).to eq(user.id)
        expect(json_response['user']['email']).to eq(user.email)
      end
    end

    context 'without token' do
      it 'returns unauthorized' do
        get :me

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
