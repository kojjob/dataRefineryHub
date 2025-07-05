class FileProcessingJob < ApplicationJob
  queue_as :extraction

  retry_on StandardError, wait: :exponentially_longer, attempts: 5
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  retry_on Net::TimeoutError, wait: :exponentially_longer, attempts: 3

  # Include real-time broadcasting capabilities
  include RealTimeBroadcastable

  def perform(extraction_job_id)
    @extraction_job = ExtractionJob.find(extraction_job_id)
    @data_source = @extraction_job.data_source
    @user = @data_source.user
    @organization = @data_source.organization

    # Initialize circuit breaker for this data source
    @circuit_breaker = CircuitBreakerService.for("file_processing_#{@data_source.id}")

    Rails.logger.info "Starting file processing for extraction job #{@extraction_job.id}"

    # Log job start metrics
    ProcessingMetricsService.log_job_started(@organization.id, @extraction_job)

    begin
      # Initialize progress tracking
      initialize_progress_tracking

      # Mark extraction job as running with start time
      @extraction_job.update!(
        status: "running",
        started_at: Time.current,
        progress_percentage: 0
      )

      # Broadcast start event
      broadcast_job_status("started", "File processing started")

      # Mark data source as syncing
      @data_source.update!(status: "syncing")

      # Process the file with circuit breaker protection
      result = @circuit_breaker.call do
        processor = FileProcessorService.new(
          data_source: @data_source,
          extraction_job: @extraction_job,
          user: @user,
          progress_callback: method(:update_progress)
        )

        processor.process!
      end

      # Update extraction job with results
      @extraction_job.update!(
        status: "completed",
        completed_at: Time.current,
        records_processed: result[:total_records],
        processing_summary: result[:processing_summary],
        progress_percentage: 100
      )

      # Update data source status
      @data_source.update!(
        status: "connected",
        last_sync_at: Time.current,
        next_sync_at: @data_source.calculate_next_sync
      )

      # Broadcast completion
      broadcast_job_status("completed", "File processing completed successfully", {
        total_records: result[:total_records],
        processing_summary: result[:processing_summary]
      })

      # Send success notification
      send_completion_notification(result)

      # Log completion metrics
      ProcessingMetricsService.log_job_completed(@organization.id, @extraction_job, result)

      Rails.logger.info "File processing completed successfully for extraction job #{@extraction_job.id}"

    rescue CircuitBreakerService::CircuitBreakerOpenError => e
      Rails.logger.warn "Circuit breaker open for data source #{@data_source.id}: #{e.message}"

      # Mark extraction job as circuit breaker delayed
      @extraction_job.update!(
        status: "delayed",
        error_message: "Circuit breaker protection: #{e.message}",
        progress_percentage: 0
      )

      # Broadcast circuit breaker delay
      broadcast_job_status("delayed", "Processing delayed due to circuit breaker protection", {
        error: e.message,
        error_type: "CircuitBreakerProtection",
        retry_info: "Will retry when service health improves"
      })

      # Don't re-raise - let job retry later when circuit breaker resets

    rescue => e
      Rails.logger.error "File processing failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Enhanced error categorization
      error_category = categorize_error(e)
      should_retry = determine_retry_strategy(e, error_category)

      # Mark extraction job as failed
      @extraction_job.update!(
        status: "failed",
        error_message: e.message,
        error_metadata: {
          error_class: e.class.name,
          error_category: error_category,
          backtrace: e.backtrace.first(10),
          retry_recommended: should_retry,
          circuit_breaker_state: @circuit_breaker&.current_state
        },
        completed_at: Time.current,
        progress_percentage: 0
      )

      # Mark data source as error
      @data_source.update!(status: "error", error_message: e.message)

      # Broadcast failure with enhanced error info
      broadcast_job_status("failed", "File processing failed: #{e.message}", {
        error: e.message,
        error_type: e.class.name,
        error_category: error_category,
        retry_recommended: should_retry,
        circuit_breaker_metrics: @circuit_breaker&.metrics
      })

      # Send error notification
      send_error_notification(e, error_category)

      # Log failure metrics
      ProcessingMetricsService.log_job_failed(@organization.id, @extraction_job, e)

      # Re-raise for retry mechanism (only for retryable errors)
      raise e if should_retry
    end
  end

  private

  def initialize_progress_tracking
    @start_time = Time.current
    @last_progress_update = Time.current
    @total_records_estimate = estimate_total_records

    # Initialize metadata
    @extraction_job.update!(
      extraction_metadata: {
        started_at: @start_time,
        total_records_estimate: @total_records_estimate,
        processing_stages: [ "parsing", "validation", "transformation", "storage" ]
      }
    )
  end

  def update_progress(stage, processed_count, total_count = nil, message = nil)
    now = Time.current

    # Throttle progress updates to avoid overwhelming the broadcast system
    return if now - @last_progress_update < 1.second

    @last_progress_update = now

    # Calculate progress percentage
    progress_percentage = if total_count && total_count > 0
                           [ (processed_count.to_f / total_count * 100), 99 ].min.round(1)
    else
                           determine_stage_progress(stage, processed_count)
    end

    # Update extraction job progress
    @extraction_job.update!(
      progress_percentage: progress_percentage,
      records_processed: processed_count,
      extraction_metadata: @extraction_job.extraction_metadata.merge({
        current_stage: stage,
        last_updated: now,
        processing_rate: calculate_processing_rate(processed_count),
        estimated_completion: estimate_completion_time(progress_percentage)
      })
    )

    # Broadcast progress update
    broadcast_progress_update(stage, progress_percentage, processed_count, total_count, message)
  end

  def determine_stage_progress(stage, processed_count)
    base_progress = case stage
    when "parsing" then 25
    when "validation" then 50
    when "transformation" then 75
    when "storage" then 90
    else 0
    end

    # Add sub-progress within stage
    if @total_records_estimate && @total_records_estimate > 0
      stage_progress = (processed_count.to_f / @total_records_estimate) * 25
      [ base_progress + stage_progress, 99 ].min.round(1)
    else
      base_progress
    end
  end

  def calculate_processing_rate(processed_count)
    elapsed_seconds = Time.current - @start_time
    return 0 if elapsed_seconds <= 0

    (processed_count.to_f / elapsed_seconds).round(2) # records per second
  end

  def estimate_completion_time(progress_percentage)
    return nil if progress_percentage <= 0

    elapsed_time = Time.current - @start_time
    total_estimated_time = (elapsed_time / progress_percentage) * 100
    remaining_time = total_estimated_time - elapsed_time

    Time.current + remaining_time.seconds
  end

  def estimate_total_records
    # Get file from data source configuration
    file_path = @data_source.configuration.dig("storage_path")
    return 1000 unless file_path && File.exist?(file_path)

    # Quick estimate based on file size and type
    file_size = File.size(file_path)
    file_extension = File.extname(@extraction_job.config["filename"]).downcase

    case file_extension
    when ".csv", ".tsv"
      # Estimate ~100 bytes per row for CSV
      [ file_size / 100, 1 ].max
    when ".json"
      # Estimate ~200 bytes per JSON object
      [ file_size / 200, 1 ].max
    when ".xlsx", ".xls"
      # Estimate ~80 bytes per Excel row
      [ file_size / 80, 1 ].max
    else
      # Default estimate
      [ file_size / 150, 1 ].max
    end
  end

  def send_completion_notification(result)
    # Create enhanced completion notification
    NotificationService.create_notification(
      user: @user,
      type: "file_processing_completed",
      title: "File Processing Completed",
      message: "Successfully processed #{@extraction_job.config['filename']} with #{result[:total_records]} records",
      data: {
        data_source_id: @data_source.id,
        extraction_job_id: @extraction_job.id,
        filename: @extraction_job.config["filename"],
        total_records: result[:total_records],
        processing_time: Time.current - @start_time,
        success_rate: result.dig(:processing_summary, :success_rate)
      }
    )

    # Also broadcast notification to real-time channels
    broadcast_data = {
      type: "notification",
      notification_type: "success",
      title: "Processing Complete",
      message: "#{@extraction_job.config['filename']} processed successfully",
      data: {
        records_processed: result[:total_records],
        data_source_name: @data_source.name
      },
      timestamp: Time.current.iso8601
    }

    ActionCable.server.broadcast("user_#{@user.id}", broadcast_data)
    ActionCable.server.broadcast("dashboard_#{@organization.id}", broadcast_data)
  end

  def send_error_notification(error, error_category = nil)
    # Create enhanced error notification
    NotificationService.create_notification(
      user: @user,
      type: "file_processing_failed",
      title: "File Processing Failed",
      message: "Failed to process #{@extraction_job.config['filename']}: #{error.message}",
      data: {
        data_source_id: @data_source.id,
        extraction_job_id: @extraction_job.id,
        filename: @extraction_job.config["filename"],
        error_message: error.message,
        error_type: error.class.name,
        error_category: error_category,
        retry_count: @extraction_job.retry_count || 0,
        circuit_breaker_state: @circuit_breaker&.current_state
      }
    )

    # Broadcast error notification
    broadcast_data = {
      type: "notification",
      notification_type: "error",
      title: "Processing Failed",
      message: "#{@extraction_job.config['filename']} processing failed",
      data: {
        error: error.message,
        error_category: error_category,
        data_source_name: @data_source.name,
        can_retry: (@extraction_job.retry_count || 0) < 5,
        retry_recommendation: get_retry_recommendation(error_category)
      },
      timestamp: Time.current.iso8601
    }

    ActionCable.server.broadcast("user_#{@user.id}", broadcast_data)
    ActionCable.server.broadcast("dashboard_#{@organization.id}", broadcast_data)
  end

  def categorize_error(error)
    case error
    when NoMethodError, NameError
      "code_error"
    when ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
      "data_error"
    when Timeout::Error, Net::TimeoutError
      "timeout_error"
    when Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError
      "network_error"
    when JSON::ParserError, CSV::MalformedCSVError
      "format_error"
    when FileProcessorService::FileSizeError
      "file_size_error"
    when FileProcessorService::UnsupportedFileTypeError
      "file_type_error"
    when ActiveRecord::Deadlocked
      "database_error"
    when StandardError
      if error.message.include?("memory")
        "memory_error"
      elsif error.message.include?("disk") || error.message.include?("space")
        "storage_error"
      else
        "unknown_error"
      end
    else
      "unknown_error"
    end
  end

  def determine_retry_strategy(error, error_category)
    case error_category
    when "code_error", "file_type_error", "file_size_error"
      false # Don't retry permanent errors
    when "timeout_error", "network_error", "database_error"
      true # Retry transient errors
    when "data_error", "format_error"
      (@extraction_job.retry_count || 0) < 2 # Limited retries for data issues
    when "memory_error", "storage_error"
      false # Don't retry resource exhaustion
    else
      (@extraction_job.retry_count || 0) < 3 # Default retry strategy
    end
  end

  def get_retry_recommendation(error_category)
    case error_category
    when "code_error"
      "Contact support - this appears to be a system issue"
    when "file_type_error"
      "Please use a supported file format (CSV, Excel, JSON, etc.)"
    when "file_size_error"
      "Please reduce file size to under 50MB or contact support"
    when "timeout_error", "network_error"
      "This appears to be a temporary issue - retrying automatically"
    when "data_error", "format_error"
      "Please check your file format and data structure"
    when "memory_error", "storage_error"
      "System resource issue - please try again later or contact support"
    else
      "Will retry automatically if appropriate"
    end
  end
end
