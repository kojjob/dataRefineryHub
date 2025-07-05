source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Asset Pipeline and Frontend
gem "sprockets-rails"
gem "importmap-rails"

# Frontend and Styling
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "view_component"

# Authentication and Authorization
gem "devise"
gem "pundit"
gem "bcrypt", "~> 3.1.7"
gem "jwt"

# API and HTTP clients
gem "httparty"
gem "faraday"
gem "faraday-retry"
gem "rack-cors"
gem "rack-attack"

# Background Jobs and Caching - Using Rails 8 native Solid gems

# Data Processing and Analytics
gem "activerecord-import"
gem "kaminari"
gem "ransack"
gem "groupdate"
gem "chartkick"

# File Processing
gem "roo"           # Excel and CSV parsing
gem "roo-xls"       # Legacy Excel support
gem "creek"         # Streaming Excel parsing for large files
gem "smarter_csv"   # Advanced CSV parsing

# External API Integrations
gem "shopify_api"
gem "stripe"
gem "google-analytics-data"
gem "mailchimp_api_v3"

# Encryption and Security
gem "lockbox"
gem "blind_index"
gem "rbnacl"

# Utilities
gem "money-rails"
gem "friendly_id"
gem "paranoia"
gem "paper_trail"
gem "validate_url"
gem "chronic"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Testing framework
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "webmock"
  gem "vcr"
  gem "timecop"

  # Code quality and security
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "simplecov", require: false

  # Database testing
  gem "database_cleaner-active_record"
end

group :development do
  # Development tools
  gem "annotate"
  gem "letter_opener"
  gem "listen"
  gem "spring"
  gem "spring-watcher-listen"

  # Performance and profiling
  gem "bullet"
  gem "rack-mini-profiler"
  gem "memory_profiler"
  gem "stackprof"
end

group :test do
  gem "shoulda-matchers"
  gem "rails-controller-testing"
end
