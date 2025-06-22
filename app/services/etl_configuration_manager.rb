# ETL Configuration Manager
# Centralized configuration management for the ETL pipeline

class EtlConfigurationManager
  include Singleton

  attr_reader :config

  def initialize
    load_configuration
  end

  # Get configuration for a specific service
  def self.get(key_path)
    instance.get(key_path)
  end

  # Get circuit breaker configuration for a service
  def self.circuit_breaker_config(service_type)
    instance.circuit_breaker_config(service_type)
  end

  # Get batch processing configuration
  def self.batch_config(operation_type)
    instance.batch_config(operation_type)
  end

  # Get data quality configuration
  def self.data_quality_config
    instance.data_quality_config
  end

  # Get error handling configuration
  def self.error_handling_config
    instance.error_handling_config
  end

  # Get performance configuration
  def self.performance_config
    instance.performance_config
  end

  # Get logging configuration
  def self.logging_config
    instance.logging_config
  end

  def self.orchestration_config
    instance.config["orchestration"] || {}
  end

  def self.monitoring_config
    instance.config["monitoring"] || {}
  end

  # Reload configuration (useful for development)
  def self.reload!
    instance.reload!
  end

  def get(key_path)
    keys = key_path.to_s.split(".")
    keys.reduce(@config) { |config, key| config&.dig(key) }
  end

  def circuit_breaker_config(service_type)
    base_config = @config.dig("circuit_breaker", service_type.to_s) || {}

    {
      failure_threshold: base_config["failure_threshold"] || 5,
      success_threshold: base_config["success_threshold"] || 3,
      timeout: base_config["timeout"] || 300,
      exponential_backoff_base: base_config["exponential_backoff_base"] || 2,
      max_backoff: base_config["max_backoff"] || 3600,
      jitter: base_config["jitter"] || true,
      service_name: "#{service_type}_circuit_breaker"
    }
  end

  def batch_config(operation_type)
    base_config = @config.dig("batch_processing", operation_type.to_s) || {}
    adaptive_config = @config.dig("batch_processing", "adaptive_sizing") || {}

    {
      default_size: base_config["default_size"] || 1000,
      max_size: base_config["max_size"] || 5000,
      min_size: base_config["min_size"] || 100,
      adaptive_sizing_enabled: adaptive_config["enabled"] || true,
      performance_threshold: adaptive_config["performance_threshold"] || 0.8,
      memory_threshold: adaptive_config["memory_threshold"] || 0.7,
      adjustment_factor: adaptive_config["adjustment_factor"] || 0.2
    }
  end

  def data_quality_config
    base_config = @config["data_quality"] || {}

    {
      validation_rules: parse_validation_rules(base_config["validation_rules"] || {}),
      quality_thresholds: parse_quality_thresholds(base_config["quality_thresholds"] || {}),
      reporting: parse_reporting_config(base_config["reporting"] || {})
    }
  end

  def error_handling_config
    base_config = @config["error_handling"] || {}

    {
      retry_strategies: base_config["retry_strategies"] || { "default" => "exponential" },
      retry_limits: base_config["retry_limits"] || { "transient_errors" => 5 },
      dead_letter_queue: parse_dlq_config(base_config["dead_letter_queue"] || {})
    }
  end

  def performance_config
    base_config = @config["performance"] || {}

    {
      monitoring: base_config["monitoring"] || { "enabled" => true },
      memory_management: base_config["memory_management"] || { "memory_limit_mb" => 1024 },
      timeouts: base_config["timeouts"] || { "extraction_timeout" => 1800 }
    }
  end

  def logging_config
    base_config = @config["logging"] || {}

    {
      level: base_config["level"] || "info",
      structured_logging: base_config["structured_logging"] || true,
      include_metrics: base_config["include_metrics"] || true,
      log_batch_progress: base_config["log_batch_progress"] || true,
      log_validation_details: base_config["log_validation_details"] || false
    }
  end

  def reload!
    load_configuration
  end

  # Check if a feature is enabled
  def feature_enabled?(feature_path)
    value = get(feature_path)
    return false if value.nil?

    case value
    when TrueClass, FalseClass
      value
    when String
      %w[true yes on enabled 1].include?(value.downcase)
    when Integer
      value > 0
    else
      false
    end
  end

  # Get environment-specific configuration
  def environment
    Rails.env
  end

  # Validate configuration on load
  def validate_configuration!
    required_keys = [
      "circuit_breaker",
      "batch_processing",
      "data_quality",
      "error_handling"
    ]

    missing_keys = required_keys.select { |key| @config[key].nil? }

    if missing_keys.any?
      raise ConfigurationError, "Missing required configuration keys: #{missing_keys.join(', ')}"
    end

    validate_circuit_breaker_config!
    validate_batch_processing_config!
    validate_data_quality_config!
  end

  private

  def load_configuration
    config_file = Rails.root.join("config", "etl_pipeline.yml")

    unless File.exist?(config_file)
      raise ConfigurationError, "ETL configuration file not found: #{config_file}"
    end

    begin
      all_configs = YAML.load_file(config_file, aliases: true)
      @config = all_configs[Rails.env] || all_configs["default"] || {}

      validate_configuration!

      Rails.logger.info "ETL configuration loaded for environment: #{Rails.env}"
    rescue Psych::SyntaxError => e
      raise ConfigurationError, "Invalid YAML in ETL configuration: #{e.message}"
    rescue => e
      raise ConfigurationError, "Failed to load ETL configuration: #{e.message}"
    end
  end

  def parse_validation_rules(rules_config)
    {
      presence: {
        enabled: rules_config.dig("presence", "enabled") || true,
        required_fields: rules_config.dig("presence", "required_fields") || []
      },
      format: {
        enabled: rules_config.dig("format", "enabled") || true,
        email_validation: rules_config.dig("format", "email_validation") || true,
        phone_validation: rules_config.dig("format", "phone_validation") || true,
        url_validation: rules_config.dig("format", "url_validation") || true
      },
      range: {
        enabled: rules_config.dig("range", "enabled") || true,
        numeric_ranges: rules_config.dig("range", "numeric_ranges") || {},
        date_ranges: rules_config.dig("range", "date_ranges") || {}
      },
      uniqueness: {
        enabled: rules_config.dig("uniqueness", "enabled") || true,
        check_within_batch: rules_config.dig("uniqueness", "check_within_batch") || true,
        check_across_batches: rules_config.dig("uniqueness", "check_across_batches") || false
      },
      referential_integrity: {
        enabled: rules_config.dig("referential_integrity", "enabled") || true,
        foreign_key_checks: rules_config.dig("referential_integrity", "foreign_key_checks") || true
      },
      data_type: {
        enabled: rules_config.dig("data_type", "enabled") || true,
        strict_typing: rules_config.dig("data_type", "strict_typing") || false
      },
      business_rules: {
        enabled: rules_config.dig("business_rules", "enabled") || true,
        custom_validators: rules_config.dig("business_rules", "custom_validators") || []
      },
      statistical: {
        enabled: rules_config.dig("statistical", "enabled") || true,
        outlier_detection: rules_config.dig("statistical", "outlier_detection") || true,
        distribution_checks: rules_config.dig("statistical", "distribution_checks") || false
      }
    }
  end

  def parse_quality_thresholds(thresholds_config)
    {
      completeness: thresholds_config["completeness"] || 0.95,
      accuracy: thresholds_config["accuracy"] || 0.90,
      consistency: thresholds_config["consistency"] || 0.85,
      validity: thresholds_config["validity"] || 0.90,
      uniqueness: thresholds_config["uniqueness"] || 0.98,
      timeliness: thresholds_config["timeliness"] || 0.80,
      integrity: thresholds_config["integrity"] || 0.95
    }
  end

  def parse_reporting_config(reporting_config)
    {
      enabled: reporting_config["enabled"] || true,
      detailed_errors: reporting_config["detailed_errors"] || true,
      quality_metrics: reporting_config["quality_metrics"] || true,
      trend_analysis: reporting_config["trend_analysis"] || false
    }
  end

  def parse_dlq_config(dlq_config)
    {
      enabled: dlq_config["enabled"] || true,
      max_retries: dlq_config["max_retries"] || 10,
      retention_days: dlq_config["retention_days"] || 30
    }
  end

  def validate_circuit_breaker_config!
    %w[extraction transformation].each do |service|
      config = @config.dig("circuit_breaker", service)
      next unless config

      if config["failure_threshold"] && config["failure_threshold"] <= 0
        raise ConfigurationError, "Invalid failure_threshold for #{service}: must be > 0"
      end

      if config["timeout"] && config["timeout"] <= 0
        raise ConfigurationError, "Invalid timeout for #{service}: must be > 0"
      end
    end
  end

  def validate_batch_processing_config!
    %w[extraction transformation validation storage].each do |operation|
      config = @config.dig("batch_processing", operation)
      next unless config

      if config["default_size"] && config["default_size"] <= 0
        raise ConfigurationError, "Invalid default_size for #{operation}: must be > 0"
      end

      if config["max_size"] && config["min_size"] && config["max_size"] < config["min_size"]
        raise ConfigurationError, "Invalid batch sizes for #{operation}: max_size must be >= min_size"
      end
    end
  end

  def validate_data_quality_config!
    thresholds = @config.dig("data_quality", "quality_thresholds")
    return unless thresholds

    thresholds.each do |metric, threshold|
      if threshold < 0 || threshold > 1
        raise ConfigurationError, "Invalid quality threshold for #{metric}: must be between 0 and 1"
      end
    end
  end

  class ConfigurationError < StandardError; end
end
