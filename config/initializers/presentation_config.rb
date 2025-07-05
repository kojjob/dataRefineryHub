# Presentation Configuration Initializer
# Loads presentation defaults from YAML configuration

class PresentationConfig
  include Singleton

  attr_reader :config

  def initialize
    @config = load_config
  end

  def self.get(key_path)
    instance.get(key_path)
  end

  def get(key_path)
    keys = key_path.split(".")
    keys.reduce(@config) { |hash, key| hash&.dig(key) }
  end

  def self.presentation_defaults
    instance.get("presentation") || {}
  end

  def self.performance_thresholds
    instance.get("presentation.performance") || {}
  end

  def self.analytics_defaults
    instance.get("presentation.analytics") || {}
  end

  def self.export_defaults
    instance.get("presentation.export") || {}
  end

  def self.monitoring_defaults
    instance.get("presentation.monitoring") || {}
  end

  private

  def load_config
    config_file = Rails.root.join("config", "presentation_defaults.yml")

    if File.exist?(config_file)
      yaml_config = YAML.load_file(config_file)
      environment_config = yaml_config[Rails.env] || yaml_config["default"] || {}

      # Allow environment variable overrides
      apply_environment_overrides(environment_config)
    else
      Rails.logger.warn "Presentation config file not found: #{config_file}"
      {}
    end
  rescue => e
    Rails.logger.error "Failed to load presentation config: #{e.message}"
    {}
  end

  def apply_environment_overrides(config)
    # Allow specific environment variables to override config values
    overrides = {
      "PRESENTATION_REFRESH_INTERVAL" => "presentation.refresh_interval",
      "PRESENTATION_MAX_EDITORS" => "presentation.max_editors",
      "PRESENTATION_LOAD_TIME_THRESHOLD" => "presentation.performance.load_time_threshold",
      "PRESENTATION_DEFAULT_TYPE" => "presentation.type"
    }

    overrides.each do |env_var, config_path|
      if ENV[env_var].present?
        set_nested_value(config, config_path, parse_env_value(ENV[env_var]))
      end
    end

    config
  end

  def set_nested_value(hash, key_path, value)
    keys = key_path.split(".")
    last_key = keys.pop

    nested_hash = keys.reduce(hash) do |h, key|
      h[key] ||= {}
      h[key]
    end

    nested_hash[last_key] = value
  end

  def parse_env_value(value)
    # Try to parse as integer, float, boolean, or keep as string
    case value.downcase
    when "true"
      true
    when "false"
      false
    when /^\d+$/
      value.to_i
    when /^\d+\.\d+$/
      value.to_f
    else
      value
    end
  end
end

# Make configuration available globally
Rails.application.config.presentation = PresentationConfig.instance
