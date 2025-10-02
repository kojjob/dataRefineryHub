# frozen_string_literal: true

# OAuth Callbacks Controller
# Handles OAuth 2.0 authentication flows for external data sources
# Currently supports: QuickBooks Online, Google Analytics
class OauthCallbacksController < ApplicationController
  # Skip CSRF protection for OAuth callbacks since they come from external services
  skip_before_action :verify_authenticity_token, only: [:callback]

  before_action :set_data_source, only: [:authorize, :callback, :refresh_token]
  before_action :authorize_data_source_access, only: [:authorize, :callback, :refresh_token]

  # GET /oauth/:provider/authorize
  # Initiates OAuth 2.0 authorization flow with external provider
  def authorize
    case params[:provider]
    when 'quickbooks'
      redirect_to quickbooks_authorization_url, allow_other_host: true
    when 'google_analytics'
      redirect_to google_authorization_url, allow_other_host: true
    else
      redirect_to data_sources_path, alert: "Unsupported OAuth provider: #{params[:provider]}"
    end
  end

  # GET /oauth/:provider/callback
  # Handles OAuth callback from external provider with authorization code
  def callback
    case params[:provider]
    when 'quickbooks'
      handle_quickbooks_callback
    when 'google_analytics'
      handle_google_callback
    else
      redirect_to data_sources_path, alert: "Unsupported OAuth provider: #{params[:provider]}"
    end
  end

  # POST /oauth/:provider/refresh
  # Refreshes expired OAuth access tokens
  def refresh_token
    case params[:provider]
    when 'quickbooks'
      refresh_quickbooks_token
    when 'google_analytics'
      refresh_google_token
    else
      render json: { success: false, message: "Unsupported OAuth provider: #{params[:provider]}" },
             status: :unprocessable_entity
    end
  end

  private

  def set_data_source
    @data_source = if params[:data_source_id]
      current_organization.data_sources.find(params[:data_source_id])
    elsif params[:state] && session[:oauth_state] == params[:state]
      # Retrieve data source from session state for callback
      current_organization.data_sources.find(session[:oauth_data_source_id])
    else
      nil
    end

    unless @data_source
      redirect_to data_sources_path, alert: "Data source not found or invalid OAuth state"
      return false
    end
  end

  def authorize_data_source_access
    authorize @data_source, :update?
  rescue Pundit::NotAuthorizedError
    redirect_to data_sources_path, alert: "You are not authorized to modify this data source"
  end

  # QuickBooks OAuth Methods

  def quickbooks_authorization_url
    # Store state in session for CSRF protection
    state = SecureRandom.urlsafe_base64(32)
    session[:oauth_state] = state
    session[:oauth_data_source_id] = @data_source.id
    session[:oauth_provider] = 'quickbooks'

    # QuickBooks OAuth 2.0 authorization endpoint
    params = {
      client_id: quickbooks_client_id,
      redirect_uri: oauth_callback_url(provider: 'quickbooks'),
      response_type: 'code',
      scope: 'com.intuit.quickbooks.accounting',
      state: state
    }

    "https://appcenter.intuit.com/connect/oauth2?#{params.to_query}"
  end

  def handle_quickbooks_callback
    # Verify state parameter to prevent CSRF attacks
    unless params[:state] == session[:oauth_state]
      redirect_to data_sources_path, alert: "Invalid OAuth state. Please try connecting again."
      return
    end

    # Verify authorization code is present
    unless params[:code].present?
      error_message = params[:error] || "Authorization denied"
      redirect_to data_sources_path, alert: "QuickBooks authorization failed: #{error_message}"
      return
    end

    begin
      # Exchange authorization code for access token
      token_response = exchange_quickbooks_code(params[:code], params[:realmId])

      # Update data source with OAuth credentials
      @data_source.update!(
        configuration: @data_source.configuration.merge(
          realm_id: params[:realmId],
          access_token: token_response['access_token'],
          refresh_token: token_response['refresh_token'],
          token_expires_at: Time.current + token_response['expires_in'].to_i.seconds,
          token_type: token_response['token_type'],
          connected_at: Time.current
        ),
        status: 'connected'
      )

      # Clear OAuth session data
      clear_oauth_session

      # Log successful connection
      Rails.logger.info "QuickBooks OAuth successful for DataSource ##{@data_source.id}, Realm: #{params[:realmId]}"

      redirect_to data_source_path(@data_source), notice: "QuickBooks connected successfully!"
    rescue StandardError => e
      Rails.logger.error "QuickBooks OAuth callback error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      redirect_to data_sources_path, alert: "Failed to connect QuickBooks: #{e.message}"
    end
  end

  def exchange_quickbooks_code(code, realm_id)
    require 'net/http'
    require 'json'

    uri = URI('https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer')

    request = Net::HTTP::Post.new(uri)
    request['Accept'] = 'application/json'
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    request.basic_auth(quickbooks_client_id, quickbooks_client_secret)

    request.set_form_data(
      grant_type: 'authorization_code',
      code: code,
      redirect_uri: oauth_callback_url(provider: 'quickbooks')
    )

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      error_body = JSON.parse(response.body) rescue { 'error' => 'unknown' }
      raise "QuickBooks token exchange failed: #{error_body['error']} - #{error_body['error_description']}"
    end

    JSON.parse(response.body)
  end

  def refresh_quickbooks_token
    begin
      refresh_token = @data_source.configuration['refresh_token']

      unless refresh_token.present?
        render json: { success: false, message: "No refresh token available" },
               status: :unprocessable_entity
        return
      end

      # Request new access token using refresh token
      token_response = request_quickbooks_token_refresh(refresh_token)

      # Update data source with new tokens
      @data_source.update!(
        configuration: @data_source.configuration.merge(
          access_token: token_response['access_token'],
          refresh_token: token_response['refresh_token'],
          token_expires_at: Time.current + token_response['expires_in'].to_i.seconds,
          token_refreshed_at: Time.current
        )
      )

      Rails.logger.info "QuickBooks token refreshed for DataSource ##{@data_source.id}"

      render json: {
        success: true,
        message: "Token refreshed successfully",
        expires_at: @data_source.configuration['token_expires_at']
      }
    rescue StandardError => e
      Rails.logger.error "QuickBooks token refresh error: #{e.message}"

      render json: { success: false, message: "Failed to refresh token: #{e.message}" },
             status: :unprocessable_entity
    end
  end

  def request_quickbooks_token_refresh(refresh_token)
    require 'net/http'
    require 'json'

    uri = URI('https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer')

    request = Net::HTTP::Post.new(uri)
    request['Accept'] = 'application/json'
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    request.basic_auth(quickbooks_client_id, quickbooks_client_secret)

    request.set_form_data(
      grant_type: 'refresh_token',
      refresh_token: refresh_token
    )

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      error_body = JSON.parse(response.body) rescue { 'error' => 'unknown' }
      raise "QuickBooks token refresh failed: #{error_body['error']} - #{error_body['error_description']}"
    end

    JSON.parse(response.body)
  end

  def quickbooks_client_id
    Rails.application.credentials.dig(:quickbooks, :client_id) ||
      ENV['QUICKBOOKS_CLIENT_ID'] ||
      raise("QuickBooks Client ID not configured")
  end

  def quickbooks_client_secret
    Rails.application.credentials.dig(:quickbooks, :client_secret) ||
      ENV['QUICKBOOKS_CLIENT_SECRET'] ||
      raise("QuickBooks Client Secret not configured")
  end

  def oauth_callback_url(provider:)
    oauth_callback_url_for(provider: provider, host: request.base_url)
  end

  def oauth_callback_url_for(provider:, host:)
    "#{host}/oauth/#{provider}/callback"
  end

  def clear_oauth_session
    session.delete(:oauth_state)
    session.delete(:oauth_data_source_id)
    session.delete(:oauth_provider)
  end

  # Google OAuth Methods

  def google_authorization_url
    # Store state in session for CSRF protection
    state = SecureRandom.urlsafe_base64(32)
    session[:oauth_state] = state
    session[:oauth_data_source_id] = @data_source.id
    session[:oauth_provider] = 'google_analytics'

    # Google OAuth 2.0 authorization endpoint
    params = {
      client_id: google_client_id,
      redirect_uri: oauth_callback_url(provider: 'google_analytics'),
      response_type: 'code',
      scope: 'https://www.googleapis.com/auth/analytics.readonly',
      access_type: 'offline',
      prompt: 'consent',
      state: state
    }

    "https://accounts.google.com/o/oauth2/v2/auth?#{params.to_query}"
  end

  def handle_google_callback
    # Verify state parameter to prevent CSRF attacks
    unless params[:state] == session[:oauth_state]
      redirect_to data_sources_path, alert: "Invalid OAuth state. Please try connecting again."
      return
    end

    # Verify authorization code is present
    unless params[:code].present?
      error_message = params[:error] || "Authorization denied"
      redirect_to data_sources_path, alert: "Google Analytics authorization failed: #{error_message}"
      return
    end

    begin
      # Exchange authorization code for access token
      token_response = exchange_google_code(params[:code])

      # Update data source with OAuth credentials
      @data_source.update!(
        configuration: @data_source.configuration.merge(
          access_token: token_response['access_token'],
          refresh_token: token_response['refresh_token'],
          token_expires_at: (Time.current + token_response['expires_in'].to_i.seconds).iso8601,
          token_type: token_response['token_type'],
          connected_at: Time.current.iso8601
        ),
        status: 'connected'
      )

      # Clear OAuth session data
      clear_oauth_session

      # Log successful connection
      Rails.logger.info "Google Analytics OAuth successful for DataSource ##{@data_source.id}"

      redirect_to data_source_path(@data_source), notice: "Google Analytics connected successfully!"
    rescue StandardError => e
      Rails.logger.error "Google Analytics OAuth callback error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      redirect_to data_sources_path, alert: "Failed to connect Google Analytics: #{e.message}"
    end
  end

  def exchange_google_code(code)
    require 'net/http'
    require 'json'

    uri = URI('https://oauth2.googleapis.com/token')

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/x-www-form-urlencoded'

    request.set_form_data(
      client_id: google_client_id,
      client_secret: google_client_secret,
      code: code,
      redirect_uri: oauth_callback_url(provider: 'google_analytics'),
      grant_type: 'authorization_code'
    )

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      error_body = JSON.parse(response.body) rescue { 'error' => 'unknown' }
      raise "Google token exchange failed: #{error_body['error']} - #{error_body['error_description']}"
    end

    JSON.parse(response.body)
  end

  def refresh_google_token
    begin
      refresh_token = @data_source.configuration['refresh_token']

      unless refresh_token.present?
        render json: { success: false, message: "No refresh token available" },
               status: :unprocessable_entity
        return
      end

      # Request new access token using refresh token
      token_response = request_google_token_refresh(refresh_token)

      # Update data source with new token
      @data_source.update!(
        configuration: @data_source.configuration.merge(
          access_token: token_response['access_token'],
          token_expires_at: (Time.current + token_response['expires_in'].to_i.seconds).iso8601,
          token_refreshed_at: Time.current.iso8601
        )
      )

      Rails.logger.info "Google Analytics token refreshed for DataSource ##{@data_source.id}"

      render json: {
        success: true,
        message: "Token refreshed successfully",
        expires_at: @data_source.configuration['token_expires_at']
      }
    rescue StandardError => e
      Rails.logger.error "Google Analytics token refresh error: #{e.message}"

      render json: { success: false, message: "Failed to refresh token: #{e.message}" },
             status: :unprocessable_entity
    end
  end

  def request_google_token_refresh(refresh_token)
    require 'net/http'
    require 'json'

    uri = URI('https://oauth2.googleapis.com/token')

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/x-www-form-urlencoded'

    request.set_form_data(
      client_id: google_client_id,
      client_secret: google_client_secret,
      refresh_token: refresh_token,
      grant_type: 'refresh_token'
    )

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      error_body = JSON.parse(response.body) rescue { 'error' => 'unknown' }
      raise "Google token refresh failed: #{error_body['error']} - #{error_body['error_description']}"
    end

    JSON.parse(response.body)
  end

  def google_client_id
    Rails.application.credentials.dig(:google, :client_id) ||
      ENV['GOOGLE_CLIENT_ID'] ||
      raise("Google Client ID not configured")
  end

  def google_client_secret
    Rails.application.credentials.dig(:google, :client_secret) ||
      ENV['GOOGLE_CLIENT_SECRET'] ||
      raise("Google Client Secret not configured")
  end
end
