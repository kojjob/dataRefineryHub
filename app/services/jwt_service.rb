# Service for handling JWT token generation and validation
class JwtService
  # Use Rails secret key base for signing
  SECRET_KEY = Rails.application.credentials.secret_key_base || Rails.application.secret_key_base

  # Token expiration times
  ACCESS_TOKEN_EXPIRY = 2.hours
  REFRESH_TOKEN_EXPIRY = 30.days

  # Algorithms
  ALGORITHM = "HS256"

  class << self
    # Generate an access token for API authentication
    def generate_access_token(user, organization = nil)
      payload = build_access_payload(user, organization)
      encode_token(payload, ACCESS_TOKEN_EXPIRY)
    end

    # Generate a refresh token for obtaining new access tokens
    def generate_refresh_token(user)
      payload = build_refresh_payload(user)
      encode_token(payload, REFRESH_TOKEN_EXPIRY)
    end

    # Decode and validate a token
    def decode_token(token)
      begin
        decoded = JWT.decode(
          token,
          SECRET_KEY,
          true,
          { algorithm: ALGORITHM }
        ).first

        HashWithIndifferentAccess.new(decoded)
      rescue JWT::ExpiredSignature
        raise TokenExpiredError, "Token has expired"
      rescue JWT::InvalidIatError
        raise TokenInvalidError, "Token issued at future time"
      rescue JWT::VerificationError
        raise TokenInvalidError, "Token signature verification failed"
      rescue JWT::DecodeError => e
        raise TokenInvalidError, "Token decode failed: #{e.message}"
      end
    end

    # Verify token and return user
    def authenticate_token(token)
      payload = decode_token(token)

      # Check token type
      unless payload["type"] == "access"
        raise TokenInvalidError, "Invalid token type"
      end

      # Find user
      user = User.find_by(id: payload["user_id"])
      raise TokenInvalidError, "User not found" unless user

      # Verify user is still active
      unless user.active_for_authentication?
        raise TokenInvalidError, "User account is not active"
      end

      # Return user and organization
      organization = if payload["organization_id"]
                      user.organization_id == payload["organization_id"] ? user.organization : nil
      else
                      user.organization
      end

      { user: user, organization: organization }
    end

    # Refresh an access token using a refresh token
    def refresh_access_token(refresh_token)
      payload = decode_token(refresh_token)

      # Check token type
      unless payload["type"] == "refresh"
        raise TokenInvalidError, "Invalid token type for refresh"
      end

      # Find user
      user = User.find_by(id: payload["user_id"])
      raise TokenInvalidError, "User not found" unless user

      # Check if refresh token is still valid (could be revoked)
      if user.respond_to?(:refresh_token_valid?) && !user.refresh_token_valid?(payload["jti"])
        raise TokenInvalidError, "Refresh token has been revoked"
      end

      # Generate new access token
      generate_access_token(user, user.organization)
    end

    # Revoke a token (add to blacklist)
    def revoke_token(token)
      payload = decode_token(token)

      # Store in Rails cache
      cache_key = "revoked_token:#{payload['jti']}"
      expires_at = Time.at(payload["exp"])
      ttl = expires_at - Time.current

      if ttl > 0
        Rails.cache.write(cache_key, true, expires_in: ttl)
        Rails.logger.info "Token revoked: #{payload['jti']}, TTL: #{ttl}"
      end
    end

    # Check if token is revoked
    def token_revoked?(jti)
      cache_key = "revoked_token:#{jti}"
      value = Rails.cache.read(cache_key)
      result = value == true
      Rails.logger.info "Checking token revocation: #{jti}, value: #{value}, revoked: #{result}"
      result
    end

    private

    def build_access_payload(user, organization)
      {
        user_id: user.id,
        email: user.email,
        organization_id: organization&.id,
        organization_name: organization&.name,
        role: user.role,
        permissions: user_permissions(user, organization),
        type: "access",
        jti: SecureRandom.uuid, # JWT ID for revocation
        iat: Time.current.to_i,
        exp: ACCESS_TOKEN_EXPIRY.from_now.to_i
      }
    end

    def build_refresh_payload(user)
      {
        user_id: user.id,
        type: "refresh",
        jti: SecureRandom.uuid,
        iat: Time.current.to_i,
        exp: REFRESH_TOKEN_EXPIRY.from_now.to_i
      }
    end

    def encode_token(payload, expiry)
      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    def user_permissions(user, organization)
      # Return simplified permissions for the token
      return [] unless organization

      permissions = []

      # Add role-based permissions
      case user.role
      when "owner"
        permissions = [ "*" ] # All permissions
      when "admin"
        permissions = %w[
          data_sources.manage
          pipelines.manage
          users.view
          reports.manage
          api.full_access
        ]
      when "member"
        permissions = %w[
          data_sources.view
          data_sources.create
          pipelines.view
          pipelines.create
          reports.view
          api.read_write
        ]
      when "viewer"
        permissions = %w[
          data_sources.view
          pipelines.view
          reports.view
          api.read_only
        ]
      end

      permissions
    end
  end

  # Custom error classes
  class TokenError < StandardError; end
  class TokenExpiredError < TokenError; end
  class TokenInvalidError < TokenError; end
end
