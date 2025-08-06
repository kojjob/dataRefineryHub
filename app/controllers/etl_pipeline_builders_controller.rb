# ETL Pipeline Builder Controller
# Visual interface for building and managing ETL/ELT pipelines
class EtlPipelineBuildersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_pipeline, only: [ :show, :edit, :update, :destroy, :execute, :test ]
  before_action :authorize_pipeline

  def index
    @pipelines = current_organization.pipelines
                                   .includes(:created_by, :last_executed_by)
                                   .order(created_at: :desc)
                                   .page(params[:page])

    @pipeline_templates = load_pipeline_templates
    @recent_executions = recent_pipeline_executions
  end

  def new
    @pipeline = current_organization.pipelines.build
    @data_sources = current_organization.data_sources
    @warehouses = available_warehouses
    @transformation_functions = TransformationRulesEngine.instance.get_available_functions
  end

  def create
    @pipeline = current_organization.pipelines.build(pipeline_params)
    @pipeline.created_by = current_user

    # Set default values for draft pipeline
    @pipeline.status = "draft"
    @pipeline.source_config ||= {}
    @pipeline.destination_config ||= {}
    @pipeline.transformation_rules ||= []

    respond_to do |format|
      if @pipeline.save
        # Register pipeline with orchestration service
        begin
          EtlOrchestrationService.instance.register_pipeline(
            @pipeline.name,
            @pipeline.to_orchestration_config
          )
        rescue => e
          Rails.logger.error "Failed to register pipeline with orchestration service: #{sanitize_error_message(e.message)}"
        end

        format.html {
          redirect_to etl_pipeline_builder_path(@pipeline),
                      notice: "Pipeline created successfully"
        }
        format.json {
          render json: {
            success: true,
            message: "Pipeline created successfully",
            redirect_url: etl_pipeline_builder_path(@pipeline),
            pipeline: @pipeline.as_json(only: [ :id, :name, :pipeline_type ])
          }, status: :created
        }
      else
        format.html {
          load_form_data
          render :new
        }
        format.json {
          render json: {
            success: false,
            message: "Failed to create pipeline",
            errors: @pipeline.errors.full_messages
          }, status: :unprocessable_entity
        }
      end
    end
  end

  def show
    @executions = PipelineExecution.where(
                    organization: current_organization,
                    pipeline_name: @pipeline.name
                  )
                  .includes(:user)
                  .order(created_at: :desc)
                  .limit(10)

    @metrics = calculate_pipeline_metrics
    @next_scheduled_run = @pipeline.next_scheduled_run if @pipeline.scheduled?
  end

  def edit
    load_form_data
  end

  def update
    if @pipeline.update(pipeline_params)
      # Update orchestration service
      begin
        EtlOrchestrationService.instance.update_pipeline(
          @pipeline.name,
          @pipeline.to_orchestration_config
        )
      rescue => e
        Rails.logger.error "Failed to update pipeline in orchestration service: #{sanitize_error_message(e.message)}"
      end

      redirect_to etl_pipeline_builder_path(@pipeline),
                  notice: "Pipeline updated successfully"
    else
      load_form_data
      render :edit
    end
  end

  def destroy
    # Remove from orchestration service
    begin
      EtlOrchestrationService.instance.remove_pipeline(@pipeline.name)
    rescue => e
      Rails.logger.error "Failed to remove pipeline from orchestration service: #{sanitize_error_message(e.message)}"
    end

    @pipeline.destroy
    redirect_to etl_pipeline_builders_path,
                notice: "Pipeline deleted successfully"
  end

  def execute
    execution = @pipeline.execute(
      user: current_user,
      parameters: execution_params
    )

    redirect_to etl_pipeline_builder_path(@pipeline),
                notice: "Pipeline execution started"
  rescue => e
    redirect_to etl_pipeline_builder_path(@pipeline),
                alert: "Execution failed: #{e.message}"
  end

  def test
    # Run pipeline in test mode with sample data
    test_result = @pipeline.test_run(
      sample_size: params[:sample_size] || 100,
      dry_run: true
    )

    render json: test_result
  end

  # AJAX endpoints for pipeline builder

  def available_extractors
    source_type = params[:source_type]
    
    # Whitelist validation for source types
    valid_sources = %w[database api cloud_storage streaming file_upload]
    unless valid_sources.include?(source_type)
      return render json: { error: "Invalid source type" }, status: :bad_request
    end

    extractors = case source_type
    when "database"
      [ "postgresql", "mysql", "sql_server", "oracle", "mongodb" ]
    when "api"
      [ "rest", "graphql", "soap" ]
    when "cloud_storage"
      [ "aws_s3", "google_cloud_storage", "azure_blob" ]
    when "streaming"
      [ "kafka", "kinesis", "pubsub" ]
    when "file_upload"
      get_file_extractors
    else
      []
    end

    render json: { extractors: extractors }
  end

  def transformation_preview
    # Validate and sanitize transformation rule
    rule = params.require(:rule).permit(:type, :name, :on_error, config: {}, mapping: {})
    sample_data = params[:sample_data] || []
    
    # Validate transformation type against whitelist
    allowed_types = TransformationRulesEngine::RULE_TYPES
    unless allowed_types.include?(rule[:type])
      return render json: { error: "Invalid transformation type" }, status: :bad_request
    end
    
    # Limit sample data size to prevent DoS
    if sample_data.length > 1000
      return render json: { error: "Sample data too large (max 1000 records)" }, status: :bad_request
    end

    engine = TransformationRulesEngine.instance
    result = engine.apply_transformations(sample_data, [ rule ])

    render json: {
      preview: result[:data].first(10),
      row_count: result[:row_count]
    }
  rescue => e
    Rails.logger.error "Transformation preview failed: #{sanitize_error_message(e.message)}"
    render json: { error: "Transformation preview failed" }, status: :unprocessable_entity
  end

  def validate_transformation
    transformation_config = params.require(:transformation).permit(
      :type, :name, :description, :order,
      config: {},
      field_mappings: [ :from, :to, :type ],
      conditions: [ :field, :operator, :value, :condition_type ]
    )

    validator = TransformationValidator.new(transformation_config)
    validation_result = validator.validate

    render json: {
      valid: validation_result[:valid],
      errors: validation_result[:errors] || [],
      warnings: validation_result[:warnings] || [],
      suggestions: validation_result[:suggestions] || []
    }
  rescue => e
    Rails.logger.error "Transformation validation failed: #{sanitize_error_message(e.message)}"
    render json: {
      valid: false,
      errors: [ "Validation failed" ],
      warnings: [],
      suggestions: []
    }, status: :unprocessable_entity
  end

  def validate_pipeline
    config = params[:pipeline_config]

    validator = PipelineValidator.new(config)
    validation_result = validator.validate

    render json: validation_result
  end

  def export_pipeline
    format = params[:format] || "json"

    respond_to do |format|
      format.json { render json: @pipeline.export_config }
      format.yaml { render plain: @pipeline.export_config.to_yaml }
      format.xml { render xml: @pipeline.export_config }
    end
  end

  def import_pipeline
    file = params[:file]
    
    # Validate file presence and type
    unless file.present?
      return render json: { success: false, error: "No file provided" }, status: :bad_request
    end
    
    # Check file size (10MB limit)
    if file.size > 10.megabytes
      return render json: { success: false, error: "File too large (max 10MB)" }, status: :bad_request
    end
    
    # Validate content type
    allowed_types = ["application/json", "application/x-yaml", "text/yaml", "application/xml", "text/xml"]
    unless allowed_types.include?(file.content_type)
      return render json: { success: false, error: "Invalid file type" }, status: :bad_request
    end

    begin
      config = parse_pipeline_file(file)
      @pipeline = current_organization.pipelines.build
      @pipeline.import_config(config)
      @pipeline.created_by = current_user

      if @pipeline.save
        render json: { success: true, pipeline_id: @pipeline.id }
      else
        render json: { success: false, errors: @pipeline.errors.full_messages }
      end
    rescue => e
      Rails.logger.error "Pipeline import failed: #{sanitize_error_message(e.message)}"
      render json: { success: false, error: "Import failed" }, status: :unprocessable_entity
    end
  end

  def save_draft
    draft_key = "pipeline_builder_draft_#{current_user.id}"
    draft_data = {
      step: params[:step],
      pipeline_data: params[:pipeline_data],
      transformations: params[:transformations] || [],
      timestamp: Time.current.iso8601,
      expires_at: 7.days.from_now.iso8601
    }

    Rails.cache.write(draft_key, draft_data, expires_in: 7.days)

    render json: {
      success: true,
      message: "Draft saved successfully",
      timestamp: draft_data[:timestamp]
    }
  rescue => e
    render json: {
      success: false,
      error: "Failed to save draft",
      details: e.message
    }, status: :unprocessable_entity
  end

  def load_draft
    draft_key = "pipeline_builder_draft_#{current_user.id}"
    draft_data = Rails.cache.read(draft_key)

    if draft_data
      # Check if draft has expired
      if Time.current > Time.parse(draft_data[:expires_at])
        Rails.cache.delete(draft_key)
        render json: {
          success: false,
          error: "Draft has expired",
          expired: true
        }
      else
        render json: {
          success: true,
          draft: draft_data,
          message: "Draft loaded successfully"
        }
      end
    else
      render json: {
        success: false,
        error: "No draft found",
        no_draft: true
      }
    end
  rescue => e
    render json: {
      success: false,
      error: "Failed to load draft",
      details: e.message
    }, status: :unprocessable_entity
  end

  def clear_draft
    draft_key = "pipeline_builder_draft_#{current_user.id}"
    Rails.cache.delete(draft_key)

    render json: {
      success: true,
      message: "Draft cleared successfully"
    }
  rescue => e
    render json: {
      success: false,
      error: "Failed to clear draft",
      details: e.message
    }, status: :unprocessable_entity
  end

  private

  def set_pipeline
    @pipeline = current_organization.pipelines.find(params[:id])
  end

  def authorize_pipeline
    authorize(@pipeline || Pipeline)
  end

  def pipeline_params
    params.require(:pipeline).permit(
      :name, :description, :pipeline_type, :schedule_config,
      :error_handling_strategy, :retry_policy, :notification_settings,
      # Explicitly define allowed source config keys
      source_config: [
        :type, :connection_string, :database_name, :table_name, :schema,
        :host, :port, :username, :api_key, :endpoint, :bucket_name,
        :region, :query, :collection, :topic, :subscription
      ],
      # Explicitly define allowed destination config keys  
      destination_config: [
        :type, :warehouse_id, :connection_string, :database_name, 
        :table_name, :schema, :host, :port, :username, :api_key,
        :endpoint, :bucket_name, :region, :format, :compression
      ],
      # Strictly control transformation rules structure
      transformation_rules: [
        :type, :name, :order, :enabled, :on_error,
        config: {},
        mapping: {}
      ],
      dependencies: [],
      transformations: [
        :id, :type, :name, :description, :order,
        config: {},
        field_mappings: [ :from, :to, :type ],
        conditions: [ :field, :operator, :value, :condition_type ],
        calculations: [ :name, :formula, :output_type ]
      ]
    )
  end

  def execution_params
    params.permit(:mode, :sample_size, :force_full_sync, parameters: {})
  end

  def load_form_data
    @data_sources = current_organization.data_sources
    @warehouses = available_warehouses
    @transformation_functions = TransformationRulesEngine.instance.get_available_functions
    @pipeline_templates = load_pipeline_templates
  end

  def available_warehouses
    # For now, just return all supported warehouses
    # Later we can filter based on organization configuration
    [ "snowflake", "bigquery", "redshift", "databricks", "synapse" ]
  end

  def load_pipeline_templates
    [
      {
        name: "Database to Warehouse ETL",
        description: "Extract from database, transform, and load to warehouse",
        config: {
          pipeline_type: "etl",
          source: { type: "database" },
          destination: { type: "warehouse" }
        }
      },
      {
        name: "API to Database ELT",
        description: "Extract from API, load to database, transform in place",
        config: {
          pipeline_type: "elt",
          source: { type: "api" },
          destination: { type: "database" }
        }
      },
      {
        name: "Cloud Storage Processing",
        description: "Process files from cloud storage",
        config: {
          pipeline_type: "etl",
          source: { type: "cloud_storage" },
          destination: { type: "warehouse" }
        }
      },
      {
        name: "Real-time Streaming",
        description: "Stream data processing pipeline",
        config: {
          pipeline_type: "streaming",
          source: { type: "streaming" },
          destination: { type: "warehouse" }
        }
      }
    ]
  end

  def recent_pipeline_executions
    PipelineExecution.where(organization: current_organization)
                     .includes(:data_source, :user)
                     .order(created_at: :desc)
                     .limit(5)
  end

  def calculate_pipeline_metrics
    executions = PipelineExecution.where(
      organization: current_organization,
      pipeline_name: @pipeline.name
    ).where("created_at > ?", 30.days.ago)

    {
      total_runs: executions.count,
      successful_runs: executions.successful.count,
      failed_runs: executions.failed.count,
      average_duration: calculate_average_duration(executions.successful),
      average_rows_processed: executions.successful.average("records_processed") || 0,
      last_run: executions.order(created_at: :desc).first,
      success_rate: executions.any? ? (executions.successful.count.to_f / executions.count * 100).round(2) : 0
    }
  end

  def parse_pipeline_file(file)
    # Size limit already checked in import_pipeline
    content = file.read

    case file.content_type
    when "application/json"
      # Parse JSON with size limit
      parsed = JSON.parse(content)
      validate_pipeline_config_structure(parsed)
      parsed
    when "application/x-yaml", "text/yaml"
      # Safe YAML loading
      parsed = YAML.safe_load(content, permitted_classes: [Date, Time, DateTime, Symbol])
      validate_pipeline_config_structure(parsed)
      parsed
    when "application/xml", "text/xml"
      # Secure XML parsing - prevent XXE attacks
      require 'nokogiri'
      doc = Nokogiri::XML(content) do |config|
        config.strict
        config.nonet  # Disable network connections
        config.noent  # Disable entity substitution
        config.nodtdload  # Disable DTD loading
      end
      parsed = Hash.from_xml(doc.to_s)
      validate_pipeline_config_structure(parsed)
      parsed
    else
      raise ArgumentError, "Unsupported file format"
    end
  rescue JSON::ParserError, Psych::SyntaxError, Nokogiri::XML::SyntaxError => e
    raise ArgumentError, "Invalid file format or syntax"
  end
  
  def validate_pipeline_config_structure(config)
    # Validate that the imported config has expected structure
    required_keys = %w[name pipeline_type]
    missing_keys = required_keys - config.keys.map(&:to_s)
    
    if missing_keys.any?
      raise ArgumentError, "Missing required fields: #{missing_keys.join(', ')}"
    end
    
    # Validate pipeline type
    valid_types = Pipeline.pipeline_types.keys
    unless valid_types.include?(config['pipeline_type'] || config[:pipeline_type])
      raise ArgumentError, "Invalid pipeline type"
    end
    
    true
  end
  
  def sanitize_error_message(message)
    # Remove sensitive information from error messages
    sanitized = message.dup
    
    # Remove passwords
    sanitized.gsub!(/password[=:].\S+/i, 'password=[REDACTED]')
    
    # Remove API keys
    sanitized.gsub!(/api[_-]?key[=:].\S+/i, 'api_key=[REDACTED]')
    
    # Remove tokens
    sanitized.gsub!(/token[=:].\S+/i, 'token=[REDACTED]')
    
    # Remove connection strings with credentials
    sanitized.gsub!(/(postgresql|mysql|mongodb):\/\/[^@]+@/, '\1://[REDACTED]@')
    
    # Limit length to prevent log flooding
    sanitized.truncate(500)
  end

  def get_file_extractors
    data_source_config = Rails.application.config_for(:data_sources)
    file_config = data_source_config["file_upload"]

    return [] unless file_config&.dig("settings", "accepted_types")

    file_config["settings"]["accepted_types"].map do |type|
      {
        "name" => type.upcase,
        "type" => type.downcase,
        "description" => get_file_type_description(type)
      }
    end
  end

  def get_file_type_description(type)
    descriptions = {
      "csv" => "Comma-separated values files",
      "xlsx" => "Microsoft Excel spreadsheets (2007+)",
      "xls" => "Legacy Microsoft Excel files",
      "json" => "JavaScript Object Notation files",
      "txt" => "Plain text files",
      "tsv" => "Tab-separated values files"
    }
    descriptions[type.downcase] || "#{type.upcase} files"
  end

  def calculate_average_duration(executions)
    completed_executions = executions.where.not(started_at: nil, completed_at: nil)
    return 0 unless completed_executions.any?

    durations = completed_executions.pluck(:started_at, :completed_at)
                                   .map { |start_time, end_time| (end_time - start_time).to_i }

    durations.sum.to_f / durations.count
  end
end
