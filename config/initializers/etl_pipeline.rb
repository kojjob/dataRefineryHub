# ETL Pipeline Initializer
# Load and validate ETL pipeline configuration on application startup

# Require ETL services
require_relative '../../app/services/etl_configuration_manager'
require_relative '../../app/services/etl_monitoring_service'
require_relative '../../app/services/etl_orchestration_service'

# Global ETL module for easy access to configuration
module ETL
  class << self
    def config
      EtlConfigurationManager.instance.config
    end

    def circuit_breaker_config(type = :default)
      EtlConfigurationManager.circuit_breaker_config(type)
    end

    def batch_config(operation_type)
      EtlConfigurationManager.batch_config(operation_type)
    end

    def data_quality_config
      EtlConfigurationManager.data_quality_config
    end

    def error_handling_config
      EtlConfigurationManager.error_handling_config
    end

    def performance_config
      EtlConfigurationManager.performance_config
    end

    def logging_config
      EtlConfigurationManager.logging_config
    end

    def orchestration_config
      EtlConfigurationManager.orchestration_config
    end

    def monitoring_config
      EtlConfigurationManager.monitoring_config
    end

    def environment
      Rails.env
    end

    def development?
      Rails.env.development?
    end

    def production?
      Rails.env.production?
    end

    def test?
      Rails.env.test?
    end

    # Service accessors
    def orchestration
      EtlOrchestrationService.instance
    end

    def monitoring
      EtlMonitoringService.instance
    end
  end
end

begin
  # Load ETL configuration
  EtlConfigurationManager.instance
  Rails.logger.info "ETL Pipeline configuration loaded successfully"
rescue => e
  Rails.logger.error "Failed to load ETL Pipeline configuration: #{e.message}"
  raise
end

# Configure ETL-specific logging
if ETL.logging_config['structured']
  Rails.logger.formatter = proc do |severity, datetime, progname, msg|
    {
      timestamp: datetime.iso8601,
      level: severity,
      message: msg,
      component: 'etl_pipeline',
      environment: Rails.env
    }.to_json + "\n"
  end
end

# Set log level if specified
if ETL.logging_config['level']
  log_level = ETL.logging_config['level'].upcase
  Rails.logger.level = Logger.const_get(log_level) if Logger.const_defined?(log_level)
end

# Initialize ETL services
begin
  # Initialize monitoring service
  if ETL.monitoring_config['enabled']
    EtlMonitoringService.instance
    Rails.logger.info "ETL Monitoring service initialized"
  end
  
  # Initialize orchestration service
  EtlOrchestrationService.instance
  Rails.logger.info "ETL Orchestration service initialized"
rescue => e
  Rails.logger.error "Failed to initialize ETL services: #{e.message}"
  # Don't raise here to allow the application to start even if ETL services fail
end

Rails.logger.info "ETL Pipeline initialized successfully"