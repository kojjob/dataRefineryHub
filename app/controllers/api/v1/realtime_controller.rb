class Api::V1::RealtimeController < Api::V1::BaseController
  include ActionController::Live
  
  # GET /api/v1/realtime/metrics_stream
  def metrics_stream
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['Connection'] = 'keep-alive'
    response.headers['X-Accel-Buffering'] = 'no' # Disable Nginx buffering
    
    # Start streaming real-time metrics
    begin
      loop do
        # Gather current metrics
        metrics = gather_real_time_metrics
        
        # Send as Server-Sent Event
        response.stream.write("data: #{metrics.to_json}\n\n")
        
        # Update every 5 seconds
        sleep 5
        
        # Check if client is still connected
        break unless response.stream.closed?
      end
    rescue IOError, Errno::ECONNRESET => e
      # Client disconnected
      Rails.logger.info "Client disconnected from metrics stream: #{e.message}"
    ensure
      response.stream.close
    end
  end
  
  # GET /api/v1/realtime/job_status_stream
  def job_status_stream
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['Connection'] = 'keep-alive'
    response.headers['X-Accel-Buffering'] = 'no'
    
    # Filter by specific job IDs if provided
    job_ids = params[:job_ids]&.split(',')
    
    begin
      loop do
        # Get current job statuses
        job_updates = gather_job_status_updates(job_ids)
        
        if job_updates.any?
          response.stream.write("data: #{job_updates.to_json}\n\n")
        end
        
        # Update every 2 seconds for job status
        sleep 2
        
        break unless response.stream.closed?
      end
    rescue IOError, Errno::ECONNRESET => e
      Rails.logger.info "Client disconnected from job status stream: #{e.message}"
    ensure
      response.stream.close
    end
  end
  
  # GET /api/v1/realtime/notifications_stream
  def notifications_stream
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['Connection'] = 'keep-alive'
    response.headers['X-Accel-Buffering'] = 'no'
    
    begin
      # Send initial connection confirmation
      response.stream.write("data: #{connection_established_message.to_json}\n\n")
      
      loop do
        # Check for new notifications
        notifications = gather_notifications_for_user(current_user)
        
        notifications.each do |notification|
          response.stream.write("data: #{notification.to_json}\n\n")
        end
        
        # Update every 3 seconds for notifications
        sleep 3
        
        break unless response.stream.closed?
      end
    rescue IOError, Errno::ECONNRESET => e
      Rails.logger.info "Client disconnected from notifications stream: #{e.message}"
    ensure
      response.stream.close
    end
  end
  
  private
  
  def gather_real_time_metrics
    {
      timestamp: Time.current.iso8601,
      organization_id: @current_organization.id,
      metrics: {
        active_jobs: @current_organization.extraction_jobs.running.count,
        queued_jobs: @current_organization.extraction_jobs.where(status: 'queued').count,
        connected_sources: @current_organization.data_sources.connected.count,
        total_sources: @current_organization.data_sources.count,
        recent_records: @current_organization.raw_data_records
                                          .where('created_at >= ?', 1.hour.ago)
                                          .count,
        system_health: calculate_system_health,
        processing_rate: calculate_current_processing_rate
      },
      alerts: gather_current_alerts
    }
  end
  
  def gather_job_status_updates(job_ids = nil)
    # Get jobs that have been updated recently
    jobs_query = @current_organization.extraction_jobs
                                     .where('updated_at >= ?', 30.seconds.ago)
    
    jobs_query = jobs_query.where(id: job_ids) if job_ids.present?
    
    jobs = jobs_query.includes(:data_source).limit(50)
    
    jobs.map do |job|
      {
        type: 'job_update',
        timestamp: Time.current.iso8601,
        job: serialize_job_for_stream(job),
        event_type: determine_job_event_type(job)
      }
    end
  end
  
  def gather_notifications_for_user(user)
    # Get unread notifications for the user (implement notification system)
    notifications = []
    
    # Check for completed jobs in the last minute
    recent_completed = @current_organization.extraction_jobs
                                           .completed
                                           .where('completed_at >= ?', 1.minute.ago)
    
    recent_completed.each do |job|
      notifications << {
        type: 'job_completed',
        timestamp: job.completed_at.iso8601,
        message: "Sync completed for #{job.data_source.name}",
        data: {
          job_id: job.id,
          data_source_name: job.data_source.name,
          records_processed: job.records_processed,
          duration: job.duration&.round(2)
        },
        priority: 'info'
      }
    end
    
    # Check for failed jobs
    recent_failed = @current_organization.extraction_jobs
                                        .failed
                                        .where('updated_at >= ?', 1.minute.ago)
    
    recent_failed.each do |job|
      notifications << {
        type: 'job_failed',
        timestamp: job.updated_at.iso8601,
        message: "Sync failed for #{job.data_source.name}",
        data: {
          job_id: job.id,
          data_source_name: job.data_source.name,
          error_message: job.error_message
        },
        priority: 'error'
      }
    end
    
    # Check for usage warnings
    usage_warnings = check_usage_warnings
    notifications.concat(usage_warnings)
    
    notifications
  end
  
  def calculate_system_health
    recent_jobs = @current_organization.extraction_jobs
                                      .where('created_at >= ?', 24.hours.ago)
    
    return 'unknown' if recent_jobs.empty?
    
    success_rate = recent_jobs.completed.count.to_f / recent_jobs.count
    
    case success_rate
    when 0.95..1.0 then 'excellent'
    when 0.85..0.94 then 'good'
    when 0.70..0.84 then 'fair'
    else 'poor'
    end
  end
  
  def calculate_current_processing_rate
    # Calculate records processed in the last hour
    recent_records = @current_organization.raw_data_records
                                         .where('created_at >= ?', 1.hour.ago)
                                         .count
    
    # Records per minute
    (recent_records / 60.0).round(2)
  end
  
  def gather_current_alerts
    alerts = []
    
    # Check for stuck jobs (running for more than 2 hours)
    stuck_jobs = @current_organization.extraction_jobs
                                     .running
                                     .where('started_at < ?', 2.hours.ago)
    
    if stuck_jobs.any?
      alerts << {
        type: 'stuck_jobs',
        severity: 'warning',
        message: "#{stuck_jobs.count} job(s) running for over 2 hours",
        count: stuck_jobs.count
      }
    end
    
    # Check for high failure rate
    recent_jobs = @current_organization.extraction_jobs
                                      .where('created_at >= ?', 1.hour.ago)
    
    if recent_jobs.count >= 5
      failure_rate = recent_jobs.failed.count.to_f / recent_jobs.count
      if failure_rate > 0.5
        alerts << {
          type: 'high_failure_rate',
          severity: 'error',
          message: "High failure rate: #{(failure_rate * 100).round(1)}% in last hour",
          failure_rate: failure_rate
        }
      end
    end
    
    # Check usage limits
    usage_alerts = check_usage_limits
    alerts.concat(usage_alerts)
    
    alerts
  end
  
  def serialize_job_for_stream(job)
    {
      id: job.id,
      data_source_id: job.data_source_id,
      data_source_name: job.data_source.name,
      status: job.status,
      records_processed: job.records_processed || 0,
      progress_percentage: calculate_job_progress(job),
      started_at: job.started_at&.iso8601,
      updated_at: job.updated_at.iso8601,
      duration: job.duration&.round(2),
      error_message: job.error_message
    }
  end
  
  def determine_job_event_type(job)
    case job.status
    when 'running'
      job.started_at > 1.minute.ago ? 'started' : 'progress'
    when 'completed'
      'completed'
    when 'failed'
      'failed'
    when 'cancelled'
      'cancelled'
    else
      'updated'
    end
  end
  
  def calculate_job_progress(job)
    return 100 if job.completed?
    return 0 unless job.running?
    
    # Basic progress calculation
    if job.extraction_metadata&.dig('total_records_estimate')
      total = job.extraction_metadata['total_records_estimate']
      processed = job.records_processed || 0
      [(processed.to_f / total * 100).round(1), 95].min
    else
      # Default progress for running jobs without estimates
      50
    end
  end
  
  def check_usage_warnings
    warnings = []
    
    # Check monthly record limits
    current_month_records = @current_organization.raw_data_records
                                                .where('created_at >= ?', Date.current.beginning_of_month)
                                                .count
    
    plan_limits = get_plan_limits(@current_organization.plan)
    
    if plan_limits[:max_monthly_records] != Float::INFINITY
      usage_percentage = (current_month_records.to_f / plan_limits[:max_monthly_records] * 100)
      
      if usage_percentage > 90
        warnings << {
          type: 'usage_limit_warning',
          timestamp: Time.current.iso8601,
          message: "Approaching monthly record limit: #{usage_percentage.round(1)}% used",
          data: {
            current_usage: current_month_records,
            limit: plan_limits[:max_monthly_records],
            percentage: usage_percentage.round(1)
          },
          priority: usage_percentage > 95 ? 'error' : 'warning'
        }
      end
    end
    
    warnings
  end
  
  def check_usage_limits
    alerts = []
    plan_limits = get_plan_limits(@current_organization.plan)
    
    # Check data source limits
    if @current_organization.data_sources.count >= plan_limits[:max_data_sources] * 0.9
      alerts << {
        type: 'approaching_data_source_limit',
        severity: 'warning',
        message: "Approaching data source limit for your plan",
        current: @current_organization.data_sources.count,
        limit: plan_limits[:max_data_sources]
      }
    end
    
    alerts
  end
  
  def get_plan_limits(plan)
    case plan
    when 'free_trial'
      { max_data_sources: 2, max_monthly_records: 10000 }
    when 'starter'
      { max_data_sources: 5, max_monthly_records: 100000 }
    when 'growth'
      { max_data_sources: 20, max_monthly_records: 1000000 }
    when 'scale'
      { max_data_sources: 100, max_monthly_records: 10000000 }
    else
      { max_data_sources: Float::INFINITY, max_monthly_records: Float::INFINITY }
    end
  end
  
  def connection_established_message
    {
      type: 'connection_established',
      timestamp: Time.current.iso8601,
      message: 'Real-time notifications connected',
      user_id: current_user.id,
      organization_id: @current_organization.id
    }
  end
end