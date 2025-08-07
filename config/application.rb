require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DataRefineryPlatform
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Add custom service paths to autoload
    config.autoload_paths += %W[
      #{config.root}/app/services
      #{config.root}/app/services/extractors
      #{config.root}/app/middleware
      #{config.root}/app/domain
      #{config.root}/app/application
    ]

    # Also add to eager load paths for proper constant resolution
    config.eager_load_paths += %W[
      #{config.root}/app/domain
    ]

    # Full-stack application with API capabilities
    # Enable sessions, flash, cookies, and views for dashboard functionality
    config.api_only = false

    # Asset pipeline configuration
    config.assets.enabled = true
    config.assets.version = "1.0"

    # Add security middleware
    config.middleware.use Rack::Attack
    
    # Add API rate limiting middleware
    require_relative "../app/middleware/api_rate_limiter"
    config.middleware.use ApiRateLimiter
  end
end
