require 'rails_helper'

RSpec.describe JwtService, type: :service do
  include ActiveSupport::Testing::TimeHelpers
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }

  describe '.generate_access_token' do
    it 'generates a valid JWT token' do
      token = described_class.generate_access_token(user, organization)

      expect(token).to be_present
      expect(token).to be_a(String)

      # Verify token can be decoded
      payload = described_class.decode_token(token)
      expect(payload['user_id']).to eq(user.id)
      expect(payload['organization_id']).to eq(organization.id)
      expect(payload['type']).to eq('access')
    end
  end

  describe '.generate_refresh_token' do
    it 'generates a valid refresh token' do
      token = described_class.generate_refresh_token(user)

      expect(token).to be_present
      expect(token).to be_a(String)

      # Verify token can be decoded
      payload = described_class.decode_token(token)
      expect(payload['user_id']).to eq(user.id)
      expect(payload['type']).to eq('refresh')
    end
  end

  describe '.authenticate_token' do
    let(:access_token) { described_class.generate_access_token(user, organization) }

    it 'authenticates valid token' do
      result = described_class.authenticate_token(access_token)

      expect(result[:user]).to eq(user)
      expect(result[:organization]).to eq(organization)
    end

    it 'raises error for invalid token' do
      expect {
        described_class.authenticate_token('invalid_token')
      }.to raise_error(JwtService::TokenInvalidError)
    end

    it 'raises error for expired token' do
      # Create an expired token by manipulating the time
      travel_to(1.hour.ago) do
        @expired_token = described_class.generate_access_token(user, organization)
      end

      travel_to(3.hours.from_now) do
        expect {
          described_class.authenticate_token(@expired_token)
        }.to raise_error(JwtService::TokenExpiredError)
      end
    end
  end

  describe '.refresh_access_token' do
    let(:refresh_token) { described_class.generate_refresh_token(user) }

    it 'generates new access token from refresh token' do
      new_access_token = described_class.refresh_access_token(refresh_token)

      expect(new_access_token).to be_present
      expect(new_access_token).to be_a(String)

      # Verify new token is valid
      payload = described_class.decode_token(new_access_token)
      expect(payload['user_id']).to eq(user.id)
      expect(payload['type']).to eq('access')
    end

    it 'raises error for invalid refresh token' do
      expect {
        described_class.refresh_access_token('invalid_token')
      }.to raise_error(JwtService::TokenInvalidError)
    end
  end

  describe '.revoke_token' do
    let(:access_token) { described_class.generate_access_token(user, organization) }

    it 'revokes a token' do
      payload = described_class.decode_token(access_token)

      # Debug: Check token expiry
      expires_at = Time.at(payload['exp'])
      ttl = expires_at - Time.current
      puts "Token expires at: #{expires_at}, TTL: #{ttl}"

      # Verify token is not revoked initially
      expect(described_class.token_revoked?(payload['jti'])).to be false

      # Revoke the token
      described_class.revoke_token(access_token)

      # Debug: Check cache directly
      cache_key = "revoked_token:#{payload['jti']}"
      cache_value = Rails.cache.read(cache_key)
      puts "Cache key: #{cache_key}, Cache value: #{cache_value}"

      # Verify token is now revoked
      expect(described_class.token_revoked?(payload['jti'])).to be true
    end
  end
end
