# PipelineConfiguration Model
# Stores ETL/ELT pipeline configurations created through the visual builder
class PipelineConfiguration < ApplicationRecord
  belongs_to :organization
  belongs_to :created_by, class_name: "User"
  belongs_to :last_executed_by, class_name: "User", optional: true
  has_many :pipeline_executions, dependent: :destroy

  # Enums
  enum :pipeline_type, {
    etl: "etl",
    elt: "elt",
    streaming: "streaming",
    batch: "batch",
    hybrid: "hybrid"
  }

  enum :status, {
    draft: "draft",
    active: "active",
    paused: "paused",
    archived: "archived"
  }

  # Validations
  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :pipeline_type, presence: true
  validates :source_config, presence: true
  validates :destination_config, presence: true

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :scheduled, -> { where.not(schedule_config: nil) }
  scope :by_type, ->(type) { where(pipeline_type: type) }

  # Callbacks
  before_save :validate_configuration
  after_update :update_orchestration_service, if: :saved_change_to_status?

  # Execute the pipeline
  def execute(user: nil, parameters: {})
    execution = pipeline_executions.create!(
      user: user || last_executed_by,
      status: "queued",
      started_at: Time.current,
      parameters: parameters,
      configuration_snapshot: export_config
    )

    # Update last execution info
    update!(
      last_executed_at: Time.current,
      last_executed_by: user
    )

    # Queue execution job
    PipelineExecutionJob.perform_later(execution)

    execution
  end

  # Test run with sample data
  def test_run(sample_size: 100, dry_run: true)
    test_context = {
      sample_size: sample_size,
      dry_run: dry_run,
      test_mode: true
    }

    # Extract sample data
    extractor = create_extractor
    sample_data = extractor.extract_data(limit: sample_size)

    # Apply transformations
    if transformation_rules.present?
      engine = TransformationRulesEngine.instance
      transformation_result = engine.apply_transformations(
        sample_data,
        transformation_rules,
        test_context
      )
      sample_data = transformation_result[:data]
    end

    # Simulate load (don't actually load in test mode)
    load_preview = if pipeline_type == "elt"
      simulate_elt_load(sample_data)
    else
      simulate_etl_load(sample_data)
    end

    {
      success: true,
      sample_count: sample_data.size,
      sample_data: sample_data.first(10),
      transformation_preview: transformation_result&.slice(:applied_rules),
      load_preview: load_preview,
      estimated_duration: estimate_duration(sample_data.size)
    }
  rescue => e
    {
      success: false,
      error: e.message,
      backtrace: e.backtrace.first(5)
    }
  end

  # Convert to orchestration service configuration
  def to_orchestration_config
    {
      name: name,
      description: description,
      stages: build_stages,
      error_handling: {
        strategy: error_handling_strategy || "circuit_breaker",
        max_failures: retry_policy&.dig("max_failures") || 3,
        recovery_time: retry_policy&.dig("recovery_time")&.minutes || 10.minutes
      },
      schedule: schedule_config
    }
  end

  # Export configuration
  def export_config
    {
      name: name,
      description: description,
      pipeline_type: pipeline_type,
      source_config: source_config,
      destination_config: destination_config,
      transformation_rules: transformation_rules,
      schedule_config: schedule_config,
      error_handling_strategy: error_handling_strategy,
      retry_policy: retry_policy,
      dependencies: dependencies,
      metadata: {
        version: "1.0",
        created_at: created_at,
        created_by: created_by.email
      }
    }
  end

  # Import configuration
  def import_config(config)
    self.name = config["name"]
    self.description = config["description"]
    self.pipeline_type = config["pipeline_type"]
    self.source_config = config["source_config"]
    self.destination_config = config["destination_config"]
    self.transformation_rules = config["transformation_rules"]
    self.schedule_config = config["schedule_config"]
    self.error_handling_strategy = config["error_handling_strategy"]
    self.retry_policy = config["retry_policy"]
    self.dependencies = config["dependencies"]
  end

  # Check if pipeline is scheduled
  def scheduled?
    schedule_config.present?
  end

  # Get next scheduled run time
  def next_scheduled_run
    return nil unless scheduled?

    schedule_type = schedule_config["type"]

    case schedule_type
    when "cron"
      cron_parser = Fugit::Cron.parse(schedule_config["cron_expression"])
      cron_parser.next_time
    when "interval"
      last_run = last_executed_at || created_at
      last_run + schedule_config["interval_minutes"].minutes
    when "daily"
      time = Time.parse(schedule_config["time"])
      next_day = Time.current.hour >= time.hour ? Date.tomorrow : Date.current
      next_day.to_time + time.hour.hours + time.min.minutes
    else
      nil
    end
  end

  # Get execution statistics
  def execution_stats(period = 30.days)
    executions = pipeline_executions.where(created_at: period.ago..Time.current)

    {
      total_runs: executions.count,
      successful_runs: executions.successful.count,
      failed_runs: executions.failed.count,
      average_duration: executions.successful.average(:duration_seconds),
      total_rows_processed: executions.sum(:rows_processed),
      average_rows_per_run: executions.average(:rows_processed),
      success_rate: calculate_success_rate(executions),
      common_errors: executions.failed.group(:error_message).count.first(5)
    }
  end

  private

  def validate_configuration
    # Validate source configuration
    validate_source_config

    # Validate destination configuration
    validate_destination_config

    # Validate transformation rules
    validate_transformation_rules if transformation_rules.present?

    # Validate dependencies
    validate_dependencies if dependencies.present?
  end

  def validate_source_config
    required_fields = case source_config["type"]
    when "database"
      %w[database_type host database username]
    when "api"
      %w[base_url auth_type]
    when "cloud_storage"
      %w[provider bucket]
    when "streaming"
      %w[stream_type topic]
    else
      []
    end

    missing_fields = required_fields - source_config.keys
    if missing_fields.any?
      errors.add(:source_config, "Missing required fields: #{missing_fields.join(', ')}")
    end
  end

  def validate_destination_config
    required_fields = case destination_config["type"]
    when "warehouse"
      %w[warehouse_type]
    when "database"
      %w[database_type host database]
    when "api"
      %w[endpoint method]
    when "cloud_storage"
      %w[provider bucket path]
    else
      []
    end

    missing_fields = required_fields - destination_config.keys
    if missing_fields.any?
      errors.add(:destination_config, "Missing required fields: #{missing_fields.join(', ')}")
    end
  end

  def validate_transformation_rules
    engine = TransformationRulesEngine.instance

    transformation_rules.each_with_index do |rule, index|
      validation = engine.validate_rule(rule)
      unless validation[:valid]
        errors.add(:transformation_rules, "Rule #{index + 1}: #{validation[:error]}")
      end
    end
  end

  def validate_dependencies
    # Ensure dependencies exist and no circular dependencies
    dependency_names = dependencies.map { |d| d["pipeline_name"] }

    existing_pipelines = organization.pipeline_configurations
                                    .where(name: dependency_names)
                                    .pluck(:name)

    missing = dependency_names - existing_pipelines
    if missing.any?
      errors.add(:dependencies, "Unknown pipelines: #{missing.join(', ')}")
    end
  end

  def update_orchestration_service
    if active?
      EtlOrchestrationService.instance.register_pipeline(name, to_orchestration_config)
    elsif paused?
      # Pause in orchestration service
      EtlOrchestrationService.instance.pause_pipeline(name)
    elsif archived?
      EtlOrchestrationService.instance.remove_pipeline(name)
    end
  end

  def build_stages
    stages = []

    # Extraction stage
    stages << {
      name: "extraction",
      type: "extractor",
      config: source_config,
      timeout: source_config["timeout"] || 30.minutes
    }

    # Transformation stages (for ETL)
    if pipeline_type == "etl" && transformation_rules.present?
      stages << {
        name: "transformation",
        type: "transformer",
        config: { rules: transformation_rules },
        depends_on: [ "extraction" ]
      }
    end

    # Load stage
    stages << {
      name: "load",
      type: "loader",
      config: destination_config,
      depends_on: pipeline_type == "etl" ? [ "transformation" ] : [ "extraction" ]
    }

    # Post-load transformations (for ELT)
    if pipeline_type == "elt" && transformation_rules.present?
      stages << {
        name: "post_load_transformation",
        type: "warehouse_transformer",
        config: { rules: transformation_rules },
        depends_on: [ "load" ]
      }
    end

    stages
  end

  def create_extractor
    case source_config["type"]
    when "database"
      data_source = organization.data_sources.find(source_config["data_source_id"])
      DatabaseExtractor.new(data_source)
    when "api"
      data_source = organization.data_sources.find(source_config["data_source_id"])
      ApiExtractor.new(data_source)
    when "cloud_storage"
      data_source = organization.data_sources.find(source_config["data_source_id"])
      CloudStorageExtractor.new(data_source)
    else
      raise NotImplementedError, "Extractor for #{source_config['type']} not implemented"
    end
  end

  def simulate_elt_load(data)
    warehouse_type = destination_config["warehouse_type"]
    table_name = destination_config["table_name"] || "test_#{name.parameterize.underscore}"

    {
      warehouse: warehouse_type,
      table: table_name,
      schema: infer_warehouse_schema(data),
      estimated_size: estimate_data_size(data),
      load_method: "COPY"
    }
  end

  def simulate_etl_load(data)
    destination_type = destination_config["type"]

    case destination_type
    when "warehouse"
      simulate_elt_load(data)
    when "database"
      {
        database: destination_config["database_type"],
        table: destination_config["table_name"],
        method: "batch_insert",
        batch_size: 1000
      }
    else
      { destination: destination_type, preview: "Load simulation" }
    end
  end

  def infer_warehouse_schema(data)
    return [] if data.empty?

    sample = data.first
    sample.map do |key, value|
      {
        name: key,
        type: infer_warehouse_type(value),
        nullable: true
      }
    end
  end

  def infer_warehouse_type(value)
    case value
    when Integer then "INTEGER"
    when Float then "FLOAT"
    when TrueClass, FalseClass then "BOOLEAN"
    when Date then "DATE"
    when DateTime, Time then "TIMESTAMP"
    when Hash, Array then "JSON"
    else "VARCHAR"
    end
  end

  def estimate_data_size(data)
    # Rough estimate
    avg_row_size = data.first(100).map { |row| row.to_json.bytesize }.sum / [ data.size, 100 ].min
    total_size = avg_row_size * data.size

    ActiveSupport::NumberHelper.number_to_human_size(total_size)
  end

  def estimate_duration(row_count)
    # Rough estimates based on historical data
    extraction_rate = 1000 # rows per second
    transformation_rate = 500 # rows per second
    load_rate = 2000 # rows per second

    extraction_time = row_count / extraction_rate
    transformation_time = transformation_rules.present? ? row_count / transformation_rate : 0
    load_time = row_count / load_rate

    total_seconds = extraction_time + transformation_time + load_time

    ActiveSupport::Duration.build(total_seconds).inspect
  end

  def calculate_success_rate(executions)
    return 0 if executions.empty?

    successful = executions.successful.count
    total = executions.count

    (successful.to_f / total * 100).round(2)
  end
end
