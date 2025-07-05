# frozen_string_literal: true

# Configure session store for better persistence
Rails.application.config.session_store :cookie_store,
  key: "_data_refinery_platform_session",
  expire_after: 2.weeks,
  secure: Rails.env.production?, # Use secure cookies in production
  httponly: true, # Prevent XSS attacks
  same_site: :lax # Balance security and functionality
