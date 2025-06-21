# frozen_string_literal: true

# ETL Orchestration Service
# Centralized service for coordinating and managing the entire ETL pipeline workflow
class EtlOrchestrationService
  include Singleton

  attr_reader :pipeline_registry, :scheduler, :dependency_manager, :monitoring

  def initialize
    @config = EtlConfigurationManager.orchestration_config
    @pipeline_registry = PipelineRegistry.new
    @scheduler = PipelineScheduler.new
    @dependency_manager = DependencyManager.new
    @monitoring = EtlMonitoringService.instance
    @logger = Rails.logger
    
    setup_default_pipelines
    setup_pipeline_dependencies
  end

  # Main orchestration methods
  def execute_pipeline(pipeline_name, options = {})
    pipeline = @pipeline_registry.get(pipeline_name)
    raise ArgumentError, "Pipeline '#{pipeline_name}' not found" unless pipeline
    
    # Check concurrent pipeline limit
    max_concurrent = @config['max_concurrent_pipelines'] || 5
    if get_active_executions_count >= max_concurrent
      raise "Maximum concurrent pipelines (#{max_concurrent}) reached"
    end
    
    execution_context = create_execution_context(pipeline, options)
    
    @logger.info "Starting pipeline execution: #{pipeline_name}", execution_context.to_log_hash
    
    begin
      # Check dependencies
      unless @dependency_manager.dependencies_satisfied?(pipeline_name, execution_context)
        raise PipelineDependencyError, "Dependencies not satisfied for pipeline: #{pipeline_name}"
      end
      
      # Set pipeline timeout
      timeout = @config['pipeline_timeout'] || 3600
      
      # Execute pipeline stages with timeout
      result = Timeout.timeout(timeout) do
        execute_pipeline_stages(pipeline, execution_context)
      end
      
      # Record success metrics
      @monitoring.record_pipeline_execution(pipeline_name, result)
      
      @logger.info "Pipeline execution completed: #{pipeline_name}", result.to_log_hash
      
      result
    rescue Timeout::Error => e
      # Record timeout failure
      @monitoring.record_pipeline_failure(pipeline_name, e, execution_context)
      
      @logger.error "Pipeline execution timed out: #{pipeline_name}", {
        timeout: timeout,
        context: execution_context.to_log_hash
      }
      
      raise
    rescue => e
      # Record failure metrics
      @monitoring.record_pipeline_failure(pipeline_name, e, execution_context)
      
      @logger.error "Pipeline execution failed: #{pipeline_name}", {
        error: e.message,
        backtrace: e.backtrace.first(10),
        context: execution_context.to_log_hash
      }
      
      raise
    end
  end

  def schedule_pipeline(pipeline_name, schedule_config)
    @scheduler.schedule(pipeline_name, schedule_config)
    @logger.info "Pipeline scheduled: #{pipeline_name}", schedule_config
  end

  def cancel_pipeline_execution(execution_id)
    execution = find_execution(execution_id)
    return false unless execution
    
    execution.cancel!
    @logger.info "Pipeline execution cancelled: #{execution_id}"
    true
  end

  def get_pipeline_status(pipeline_name = nil)
    if pipeline_name
      get_single_pipeline_status(pipeline_name)
    else
      get_all_pipelines_status
    end
  end

  def get_execution_history(pipeline_name, limit = 50)
    PipelineExecution.where(pipeline_name: pipeline_name)
                    .order(created_at: :desc)
                    .limit(limit)
                    .map(&:to_summary_hash)
  end

  # Pipeline management methods
  def register_pipeline(name, definition)
    @pipeline_registry.register(name, definition)
    @logger.info "Pipeline registered: #{name}"
  end

  def update_pipeline(name, definition)
    @pipeline_registry.update(name, definition)
    @logger.info "Pipeline updated: #{name}"
  end

  def remove_pipeline(name)
    @scheduler.unschedule(name)
    @pipeline_registry.remove(name)
    @logger.info "Pipeline removed: #{name}"
  end

  def add_pipeline_dependency(pipeline_name, dependency_name, conditions = {})
    @dependency_manager.add_dependency(pipeline_name, dependency_name, conditions)
    @logger.info "Dependency added: #{pipeline_name} depends on #{dependency_name}"
  end

  # Batch operations
  def execute_pipeline_batch(pipeline_names, options = {})
    results = {}
    errors = {}
    
    # Determine execution order based on dependencies
    execution_order = @dependency_manager.resolve_execution_order(pipeline_names)
    
    execution_order.each do |pipeline_name|
      begin
        results[pipeline_name] = execute_pipeline(pipeline_name, options)
      rescue => e
        errors[pipeline_name] = e
        
        # Stop execution if configured to do so
        if options[:stop_on_error]
          @logger.error "Batch execution stopped due to error in: #{pipeline_name}"
          break
        end
      end
    end
    
    {
      successful: results,
      failed: errors,
      execution_order: execution_order
    }
  end

  def execute_data_source_pipeline(data_source_id, pipeline_type = :full)
    data_source = DataSource.find(data_source_id)
    
    case pipeline_type
    when :extraction_only
      execute_pipeline('extraction_pipeline', { data_source_id: data_source_id })
    when :transformation_only
      execute_pipeline('transformation_pipeline', { data_source_id: data_source_id })
    when :full
      execute_pipeline('full_etl_pipeline', { data_source_id: data_source_id })
    else
      raise ArgumentError, "Unknown pipeline type: #{pipeline_type}"
    end
  end

  # Monitoring and health checks
  def get_system_health
    {
      orchestration_status: 'healthy',
      active_executions: get_active_executions_count,
      scheduled_pipelines: @scheduler.get_scheduled_count,
      recent_failures: get_recent_failures_count,
      monitoring_health: @monitoring.check_system_health,
      timestamp: Time.current
    }
  end

  def get_performance_metrics(time_range = 24.hours)
    end_time = Time.current
    start_time = end_time - time_range
    
    {
      pipeline_executions: PipelineExecution.where(created_at: start_time..end_time).count,
      success_rate: calculate_success_rate(start_time, end_time),
      average_execution_time: calculate_average_execution_time(start_time, end_time),
      throughput_metrics: @monitoring.get_performance_report(nil, time_range),
      resource_utilization: get_resource_utilization
    }
  end

  private

  def setup_default_pipelines
    # Full ETL Pipeline
    @pipeline_registry.register('full_etl_pipeline', {
      name: 'Full ETL Pipeline',
      description: 'Complete extraction, transformation, and loading pipeline',
      stages: [
        {
          name: 'extraction',
          type: 'job',
          job_class: 'ExtractionJobProcessor',
          retry_policy: { max_attempts: 3, backoff: 'exponential' },
          timeout: 30.minutes
        },
        {
          name: 'transformation',
          type: 'job',
          job_class: 'TransformationJobProcessor',
          retry_policy: { max_attempts: 3, backoff: 'exponential' },
          timeout: 45.minutes,
          depends_on: ['extraction']
        },
        {
          name: 'validation',
          type: 'service',
          service_class: 'DataQualityValidationService',
          method: 'validate_processed_data',
          depends_on: ['transformation']
        }
      ],
      error_handling: {
        strategy: 'circuit_breaker',
        max_failures: 5,
        recovery_time: 10.minutes
      }
    })
    
    # Extraction Only Pipeline
    @pipeline_registry.register('extraction_pipeline', {
      name: 'Extraction Pipeline',
      description: 'Data extraction only',
      stages: [
        {
          name: 'extraction',
          type: 'job',
          job_class: 'ExtractionJobProcessor',
          retry_policy: { max_attempts: 5, backoff: 'exponential' },
          timeout: 30.minutes
        }
      ]
    })
    
    # Transformation Only Pipeline
    @pipeline_registry.register('transformation_pipeline', {
      name: 'Transformation Pipeline',
      description: 'Data transformation only',
      stages: [
        {
          name: 'transformation',
          type: 'job',
          job_class: 'TransformationJobProcessor',
          retry_policy: { max_attempts: 3, backoff: 'exponential' },
          timeout: 45.minutes
        }
      ]
    })
    
    # Data Quality Pipeline
    @pipeline_registry.register('data_quality_pipeline', {
      name: 'Data Quality Pipeline',
      description: 'Comprehensive data quality validation and reporting',
      stages: [
        {
          name: 'quality_validation',
          type: 'service',
          service_class: 'DataQualityValidationService',
          method: 'comprehensive_validation'
        },
        {
          name: 'quality_reporting',
          type: 'service',
          service_class: 'DataQualityReportingService',
          method: 'generate_quality_report',
          depends_on: ['quality_validation']
        }
      ]
    })
  end

  def setup_pipeline_dependencies
    # Set up common dependencies
    @dependency_manager.add_dependency('transformation_pipeline', 'extraction_pipeline', {
      condition: 'successful_completion',
      max_age: 1.hour
    })
    
    @dependency_manager.add_dependency('data_quality_pipeline', 'transformation_pipeline', {
      condition: 'successful_completion',
      max_age: 30.minutes
    })
  end

  def create_execution_context(pipeline, options)
    ExecutionContext.new(
      pipeline_name: pipeline[:name],
      execution_id: SecureRandom.uuid,
      data_source_id: options[:data_source_id],
      user_id: options[:user_id],
      parameters: options[:parameters] || {},
      priority: options[:priority] || 'normal',
      created_at: Time.current
    )
  end

  def execute_pipeline_stages(pipeline, execution_context)
    result = PipelineExecutionResult.new(execution_context)
    
    # Create pipeline execution record
    pipeline_execution = PipelineExecution.create!(
      execution_id: execution_context.execution_id,
      pipeline_name: execution_context.pipeline_name,
      data_source_id: execution_context.data_source_id,
      status: 'running',
      started_at: Time.current,
      parameters: execution_context.parameters
    )
    
    begin
      # Execute stages in dependency order
      execution_order = resolve_stage_dependencies(pipeline[:stages])
      
      execution_order.each do |stage|
        stage_result = execute_stage(stage, execution_context)
        result.add_stage_result(stage[:name], stage_result)
        
        # Update execution progress
        pipeline_execution.update!(
          progress: calculate_progress(result, pipeline[:stages].size),
          current_stage: stage[:name]
        )
      end
      
      # Mark as completed
      pipeline_execution.update!(
        status: 'completed',
        completed_at: Time.current,
        result_summary: result.to_summary_hash
      )
      
      result.mark_successful
    rescue => e
      # Mark as failed
      pipeline_execution.update!(
        status: 'failed',
        completed_at: Time.current,
        error_message: e.message,
        error_details: {
          backtrace: e.backtrace.first(10),
          stage: pipeline_execution.current_stage
        }
      )
      
      result.mark_failed(e)
      raise
    end
    
    result
  end

  def execute_stage(stage, execution_context)
    @logger.info "Executing stage: #{stage[:name]}", {
      pipeline: execution_context.pipeline_name,
      execution_id: execution_context.execution_id
    }
    
    start_time = Time.current
    
    begin
      case stage[:type]
      when 'job'
        execute_job_stage(stage, execution_context)
      when 'service'
        execute_service_stage(stage, execution_context)
      else
        raise ArgumentError, "Unknown stage type: #{stage[:type]}"
      end
    rescue => e
      @logger.error "Stage execution failed: #{stage[:name]}", {
        error: e.message,
        pipeline: execution_context.pipeline_name,
        execution_id: execution_context.execution_id
      }
      raise
    ensure
      execution_time = Time.current - start_time
      @logger.info "Stage completed: #{stage[:name]}", {
        execution_time: execution_time,
        pipeline: execution_context.pipeline_name
      }
    end
  end

  def execute_job_stage(stage, execution_context)
    job_class = stage[:job_class].constantize
    
    # Execute job with timeout if specified
    if stage[:timeout]
      Timeout.timeout(stage[:timeout]) do
        job_class.perform_now(execution_context.data_source_id, execution_context.parameters)
      end
    else
      job_class.perform_now(execution_context.data_source_id, execution_context.parameters)
    end
  end

  def execute_service_stage(stage, execution_context)
    service_class = stage[:service_class].constantize
    service_instance = service_class.new
    method_name = stage[:method]
    
    # Call service method with context
    service_instance.send(method_name, execution_context.data_source_id, execution_context.parameters)
  end

  def resolve_stage_dependencies(stages)
    # Simple topological sort for stage dependencies
    sorted_stages = []
    remaining_stages = stages.dup
    
    while remaining_stages.any?
      # Find stages with no unresolved dependencies
      ready_stages = remaining_stages.select do |stage|
        dependencies = stage[:depends_on] || []
        dependencies.all? { |dep| sorted_stages.any? { |s| s[:name] == dep } }
      end
      
      if ready_stages.empty?
        raise "Circular dependency detected in pipeline stages"
      end
      
      # Add ready stages to sorted list
      sorted_stages.concat(ready_stages)
      remaining_stages -= ready_stages
    end
    
    sorted_stages
  end

  def calculate_progress(result, total_stages)
    completed_stages = result.stage_results.size
    (completed_stages.to_f / total_stages * 100).round(2)
  end

  def find_execution(execution_id)
    PipelineExecution.find_by(execution_id: execution_id)
  end

  def get_single_pipeline_status(pipeline_name)
    pipeline = @pipeline_registry.get(pipeline_name)
    return nil unless pipeline
    
    recent_executions = PipelineExecution.where(pipeline_name: pipeline_name)
                                         .order(created_at: :desc)
                                         .limit(10)
    
    {
      name: pipeline_name,
      definition: pipeline,
      status: determine_pipeline_health(recent_executions),
      last_execution: recent_executions.first&.to_summary_hash,
      success_rate: calculate_pipeline_success_rate(recent_executions),
      average_duration: calculate_pipeline_average_duration(recent_executions),
      scheduled: @scheduler.scheduled?(pipeline_name)
    }
  end

  def get_all_pipelines_status
    @pipeline_registry.all.map do |name, pipeline|
      get_single_pipeline_status(name)
    end
  end

  def get_active_executions_count
    PipelineExecution.where(status: ['running', 'pending']).count
  end

  def get_recent_failures_count(time_range = 1.hour)
    PipelineExecution.where(
      status: 'failed',
      created_at: time_range.ago..Time.current
    ).count
  end

  def calculate_success_rate(start_time, end_time)
    total = PipelineExecution.where(created_at: start_time..end_time).count
    return 100.0 if total.zero?
    
    successful = PipelineExecution.where(
      created_at: start_time..end_time,
      status: 'completed'
    ).count
    
    (successful.to_f / total * 100).round(2)
  end

  def calculate_average_execution_time(start_time, end_time)
    executions = PipelineExecution.where(
      created_at: start_time..end_time,
      status: 'completed'
    ).where.not(completed_at: nil)
    
    return 0 if executions.empty?
    
    total_time = executions.sum { |e| e.completed_at - e.started_at }
    (total_time / executions.count).round(2)
  end

  def get_resource_utilization
    {
      memory_usage: get_memory_usage,
      cpu_usage: get_cpu_usage,
      active_jobs: get_active_jobs_count,
      queue_depth: get_queue_depth
    }
  end

  def get_memory_usage
    `ps -o pid,rss -p #{Process.pid}`.split("\n")[1].split[1].to_i / 1024.0 # MB
  end

  def get_cpu_usage
    # This is a simplified CPU usage calculation
    # In production, you might want to use a more sophisticated approach
    `ps -o pid,pcpu -p #{Process.pid}`.split("\n")[1].split[1].to_f
  end

  def get_active_jobs_count
    # This depends on your job queue system (Sidekiq, DelayedJob, etc.)
    # Example for Sidekiq:
    # Sidekiq::Workers.new.size
    0 # Placeholder
  end

  def get_queue_depth
    # This depends on your job queue system
    # Example for Sidekiq:
    # Sidekiq::Queue.new.size
    0 # Placeholder
  end

  def determine_pipeline_health(recent_executions)
    return 'unknown' if recent_executions.empty?
    
    last_execution = recent_executions.first
    recent_failures = recent_executions.where(status: 'failed').count
    
    if last_execution.status == 'failed'
      'unhealthy'
    elsif recent_failures > recent_executions.count * 0.5
      'degraded'
    else
      'healthy'
    end
  end

  def calculate_pipeline_success_rate(executions)
    return 100.0 if executions.empty?
    
    successful = executions.where(status: 'completed').count
    (successful.to_f / executions.count * 100).round(2)
  end

  def calculate_pipeline_average_duration(executions)
    completed = executions.where(status: 'completed').where.not(completed_at: nil)
    return 0 if completed.empty?
    
    total_time = completed.sum { |e| e.completed_at - e.started_at }
    (total_time / completed.count).round(2)
  end

  # Supporting classes
  class PipelineRegistry
    def initialize
      @pipelines = {}
    end

    def register(name, definition)
      @pipelines[name] = definition
    end

    def update(name, definition)
      @pipelines[name] = definition
    end

    def get(name)
      @pipelines[name]
    end

    def remove(name)
      @pipelines.delete(name)
    end

    def all
      @pipelines
    end
  end

  class PipelineScheduler
    def initialize
      @scheduled_pipelines = {}
    end

    def schedule(pipeline_name, config)
      @scheduled_pipelines[pipeline_name] = config
      # Here you would integrate with your scheduling system (cron, whenever gem, etc.)
    end

    def unschedule(pipeline_name)
      @scheduled_pipelines.delete(pipeline_name)
    end

    def scheduled?(pipeline_name)
      @scheduled_pipelines.key?(pipeline_name)
    end

    def get_scheduled_count
      @scheduled_pipelines.size
    end
  end

  class DependencyManager
    def initialize
      @dependencies = {}
    end

    def add_dependency(pipeline_name, dependency_name, conditions)
      @dependencies[pipeline_name] ||= []
      @dependencies[pipeline_name] << {
        name: dependency_name,
        conditions: conditions
      }
    end

    def dependencies_satisfied?(pipeline_name, execution_context)
      dependencies = @dependencies[pipeline_name] || []
      
      dependencies.all? do |dep|
        check_dependency_condition(dep, execution_context)
      end
    end

    def resolve_execution_order(pipeline_names)
      # Simple topological sort
      sorted = []
      remaining = pipeline_names.dup
      
      while remaining.any?
        ready = remaining.select do |name|
          deps = (@dependencies[name] || []).map { |d| d[:name] }
          deps.all? { |dep| sorted.include?(dep) }
        end
        
        if ready.empty?
          # Add remaining pipelines (might have circular dependencies)
          sorted.concat(remaining)
          break
        end
        
        sorted.concat(ready)
        remaining -= ready
      end
      
      sorted
    end

    private

    def check_dependency_condition(dependency, execution_context)
      case dependency[:conditions][:condition]
      when 'successful_completion'
        check_successful_completion(dependency[:name], dependency[:conditions], execution_context)
      else
        true # Unknown condition, assume satisfied
      end
    end

    def check_successful_completion(pipeline_name, conditions, execution_context)
      max_age = conditions[:max_age] || 24.hours
      cutoff_time = Time.current - max_age
      
      recent_execution = PipelineExecution.where(
        pipeline_name: pipeline_name,
        status: 'completed',
        completed_at: cutoff_time..Time.current
      ).order(completed_at: :desc).first
      
      recent_execution.present?
    end
  end

  class ExecutionContext
    attr_reader :pipeline_name, :execution_id, :data_source_id, :user_id, :parameters, :priority, :created_at

    def initialize(attributes)
      @pipeline_name = attributes[:pipeline_name]
      @execution_id = attributes[:execution_id]
      @data_source_id = attributes[:data_source_id]
      @user_id = attributes[:user_id]
      @parameters = attributes[:parameters]
      @priority = attributes[:priority]
      @created_at = attributes[:created_at]
    end

    def to_log_hash
      {
        pipeline_name: @pipeline_name,
        execution_id: @execution_id,
        data_source_id: @data_source_id,
        user_id: @user_id,
        priority: @priority
      }
    end
  end

  class PipelineExecutionResult
    attr_reader :execution_context, :stage_results, :status, :error

    def initialize(execution_context)
      @execution_context = execution_context
      @stage_results = {}
      @status = 'running'
      @error = nil
    end

    def add_stage_result(stage_name, result)
      @stage_results[stage_name] = result
    end

    def mark_successful
      @status = 'completed'
    end

    def mark_failed(error)
      @status = 'failed'
      @error = error
    end

    def successful?
      @status == 'completed'
    end

    def to_summary_hash
      {
        execution_id: @execution_context.execution_id,
        pipeline_name: @execution_context.pipeline_name,
        status: @status,
        stages_completed: @stage_results.size,
        error_message: @error&.message
      }
    end

    def to_log_hash
      {
        execution_id: @execution_context.execution_id,
        pipeline_name: @execution_context.pipeline_name,
        status: @status,
        stages_completed: @stage_results.size,
        total_duration: calculate_total_duration
      }
    end

    private

    def calculate_total_duration
      return 0 if @stage_results.empty?
      
      # This is a simplified calculation
      # In practice, you'd track actual stage execution times
      @stage_results.size * 30 # Assume 30 seconds per stage
    end
  end

  # Custom exceptions
  class PipelineDependencyError < StandardError; end
  class PipelineExecutionError < StandardError; end
end