# frozen_string_literal: true

class DataQualityController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_member
  before_action :set_data_source, only: [:show, :validate, :report]

  def index
    @organization = current_organization
    @data_sources = policy_scope(DataSource).includes(:extraction_jobs, :data_quality_reports)
    @overall_metrics = calculate_comprehensive_quality_metrics
    @quality_trends = calculate_quality_trends_detailed
    @recent_reports = policy_scope(DataQualityReport).recent.limit(10)
    @alerts = calculate_quality_alerts
  end

  def show
    authorize @data_source, :show?
    @quality_metrics = calculate_source_quality_metrics(@data_source)
    @validation_history = @data_source.data_quality_reports.recent.limit(20)
    @quality_issues = get_quality_issues(@data_source)
    @recommendations = generate_quality_recommendations(@data_source)
  end

  def validate
    authorize @data_source, :update?
    
    validation_job = DataQualityValidationJob.perform_later(
      data_source: @data_source,
      user: current_user,
      validation_type: params[:validation_type] || 'full'
    )

    respond_to do |format|
      format.json do
        render json: {
          status: 'success',
          message: 'Data quality validation started',
          job_id: validation_job.job_id
        }
      end
      format.html do
        redirect_to data_quality_path(@data_source), 
                   notice: 'Data quality validation started. Results will be available shortly.'
      end
    end
  end

  def report
    authorize @data_source, :show?
    @report = @data_source.data_quality_reports.find(params[:report_id])
    
    respond_to do |format|
      format.html
      format.json { render json: @report.as_json(include: [:quality_issues, :recommendations]) }
      format.pdf do
        pdf = generate_quality_report_pdf(@report)
        send_data pdf.render, 
                 filename: "data_quality_report_#{@data_source.name}_#{@report.created_at.strftime('%Y%m%d')}.pdf",
                 type: 'application/pdf',
                 disposition: 'attachment'
      end
    end
  end

  def metrics_api
    metrics = calculate_real_time_metrics
    
    respond_to do |format|
      format.json { render json: metrics }
    end
  end

  private

  def set_data_source
    @data_source = policy_scope(DataSource).find(params[:data_source_id] || params[:id])
  end

  def calculate_comprehensive_quality_metrics
    # Enhanced version of dashboard quality metrics with more detail
    recent_records = policy_scope(RawDataRecord)
      .includes(:data_source)
      .where(created_at: 7.days.ago..Time.current)

    return default_comprehensive_metrics if recent_records.empty?

    quality_service = DataQualityValidationService.new
    
    # Group by data source and time periods for trend analysis
    metrics_by_source = {}
    daily_trends = {}
    
    @data_sources.each do |data_source|
      source_records = recent_records.where(data_source: data_source)
      next if source_records.empty?

      source_data = source_records.map { |r| parse_record_data(r.raw_data) }
      validation_result = quality_service.validate_data(source_data, context: data_source.source_type)

      metrics_by_source[data_source.id] = {
        data_source: data_source,
        completeness: calculate_completeness_score(source_data),
        accuracy: validation_result.quality_metrics&.accuracy_score || 85,
        freshness: calculate_freshness_score(source_records),
        consistency: validation_result.quality_metrics&.consistency_score || 90,
        validity: calculate_validity_score(source_data, data_source.source_type),
        uniqueness: calculate_uniqueness_score(source_data),
        issues_count: validation_result.errors.count,
        total_records: source_records.count,
        last_updated: source_records.maximum(:created_at)
      }

      # Calculate daily trends for the past 7 days
      (0..6).each do |days_ago|
        date = days_ago.days.ago.to_date
        day_records = source_records.where(created_at: date.beginning_of_day..date.end_of_day)
        
        if day_records.any?
          day_data = day_records.map { |r| parse_record_data(r.raw_data) }
          day_validation = quality_service.validate_data(day_data, context: data_source.source_type)
          
          daily_trends[date] ||= []
          daily_trends[date] << {
            data_source_id: data_source.id,
            completeness: calculate_completeness_score(day_data),
            accuracy: day_validation.quality_metrics&.accuracy_score || 85,
            record_count: day_records.count
          }
        end
      end
    end

    # Calculate overall metrics
    overall_metrics = calculate_overall_metrics(metrics_by_source.values)
    
    {
      overall: overall_metrics,
      by_source: metrics_by_source,
      daily_trends: daily_trends,
      summary: {
        total_sources_monitored: metrics_by_source.count,
        sources_with_issues: metrics_by_source.count { |_, m| m[:issues_count] > 0 },
        average_quality_score: overall_metrics[:overall_quality_score],
        last_analysis: Time.current
      }
    }
  rescue => e
    Rails.logger.error "Error calculating comprehensive quality metrics: #{e.message}"
    default_comprehensive_metrics
  end

  def calculate_source_quality_metrics(data_source)
    recent_records = policy_scope(RawDataRecord)
      .where(data_source: data_source)
      .where(created_at: 30.days.ago..Time.current)
      .order(created_at: :desc)
      .limit(1000)

    return default_source_metrics if recent_records.empty?

    quality_service = DataQualityValidationService.new
    source_data = recent_records.map { |r| parse_record_data(r.raw_data) }
    validation_result = quality_service.validate_data(source_data, context: data_source.source_type)

    {
      completeness: calculate_completeness_score(source_data),
      accuracy: validation_result.quality_metrics&.accuracy_score || 85,
      freshness: calculate_freshness_score(recent_records),
      consistency: validation_result.quality_metrics&.consistency_score || 90,
      validity: calculate_validity_score(source_data, data_source.source_type),
      uniqueness: calculate_uniqueness_score(source_data),
      total_records: recent_records.count,
      issues: validation_result.errors,
      last_validation: Time.current,
      data_volume_trend: calculate_volume_trend(data_source),
      schema_stability: calculate_schema_stability(source_data)
    }
  end

  def calculate_quality_trends_detailed
    # Calculate quality trends over the past 30 days
    trends = []
    
    (0..29).each do |days_ago|
      date = days_ago.days.ago.to_date
      day_records = policy_scope(RawDataRecord)
        .where(created_at: date.beginning_of_day..date.end_of_day)
      
      if day_records.any?
        quality_service = DataQualityValidationService.new
        day_data = day_records.map { |r| parse_record_data(r.raw_data) }
        validation_result = quality_service.validate_data(day_data)
        
        trends << {
          date: date,
          completeness: calculate_completeness_score(day_data),
          accuracy: validation_result.quality_metrics&.accuracy_score || 85,
          record_count: day_records.count,
          issues_count: validation_result.errors.count
        }
      else
        trends << {
          date: date,
          completeness: 0,
          accuracy: 0,
          record_count: 0,
          issues_count: 0
        }
      end
    end
    
    trends.reverse
  end

  def calculate_quality_alerts
    alerts = []
    
    @data_sources.each do |data_source|
      # Check for data freshness issues
      last_record = data_source.raw_data_records.order(:created_at).last
      if last_record && last_record.created_at < 24.hours.ago
        alerts << {
          type: 'warning',
          severity: 'medium',
          data_source: data_source,
          message: "No new data received in the last 24 hours",
          created_at: Time.current
        }
      end
      
      # Check for recent quality issues
      recent_report = data_source.data_quality_reports.recent.first
      if recent_report && recent_report.overall_score < 70
        alerts << {
          type: 'error',
          severity: 'high',
          data_source: data_source,
          message: "Data quality score below threshold (#{recent_report.overall_score}%)",
          created_at: recent_report.created_at
        }
      end
    end
    
    alerts.sort_by { |a| [a[:severity] == 'high' ? 0 : 1, a[:created_at]] }.reverse
  end

  def get_quality_issues(data_source)
    recent_records = data_source.raw_data_records
      .where(created_at: 7.days.ago..Time.current)
      .limit(500)
    
    return [] if recent_records.empty?
    
    quality_service = DataQualityValidationService.new
    source_data = recent_records.map { |r| parse_record_data(r.raw_data) }
    validation_result = quality_service.validate_data(source_data, context: data_source.source_type)
    
    validation_result.errors.map do |error|
      {
        type: error.type,
        field: error.field,
        message: error.message,
        severity: error.severity,
        count: error.occurrences || 1,
        examples: error.examples || []
      }
    end
  end

  def generate_quality_recommendations(data_source)
    issues = get_quality_issues(data_source)
    recommendations = []
    
    # Analyze issues and generate recommendations
    if issues.any? { |i| i[:type] == 'missing_required_field' }
      recommendations << {
        priority: 'high',
        category: 'completeness',
        title: 'Address Missing Required Fields',
        description: 'Some records are missing required fields. Review data extraction logic.',
        action: 'Review and update data extraction mappings'
      }
    end
    
    if issues.any? { |i| i[:type] == 'invalid_format' }
      recommendations << {
        priority: 'medium',
        category: 'validity',
        title: 'Fix Data Format Issues',
        description: 'Data format validation failures detected. Standardize data formats.',
        action: 'Implement data transformation rules'
      }
    end
    
    # Add general recommendations based on data source type
    case data_source.source_type
    when 'shopify'
      recommendations << {
        priority: 'low',
        category: 'optimization',
        title: 'Optimize Shopify Webhook Configuration',
        description: 'Consider using webhooks for real-time data updates.',
        action: 'Configure Shopify webhooks'
      }
    when 'file_upload'
      recommendations << {
        priority: 'medium',
        category: 'automation',
        title: 'Automate File Processing',
        description: 'Set up automated file processing schedules.',
        action: 'Configure scheduled uploads'
      }
    end
    
    recommendations
  end

  def calculate_real_time_metrics
    # Real-time metrics for API endpoints and live dashboards
    {
      timestamp: Time.current.iso8601,
      overall_health: calculate_system_health,
      active_sources: @data_sources.connected.count,
      total_records_today: policy_scope(RawDataRecord).where(created_at: Date.current.beginning_of_day..Time.current).count,
      quality_score: @overall_metrics&.dig(:overall, :overall_quality_score) || 0,
      active_jobs: ExtractionJob.running.count,
      alerts_count: calculate_quality_alerts.count
    }
  end

  # Helper methods from dashboard controller
  def parse_record_data(raw_data)
    return {} unless raw_data.present?

    case raw_data
    when String
      JSON.parse(raw_data) rescue {}
    when Hash
      raw_data
    else
      {}
    end
  end

  def calculate_completeness_score(data)
    return 0 if data.empty?

    total_fields = 0
    filled_fields = 0

    data.each do |record|
      next unless record.is_a?(Hash)
      
      record.each do |key, value|
        total_fields += 1
        filled_fields += 1 if value.present?
      end
    end

    return 0 if total_fields == 0
    ((filled_fields.to_f / total_fields) * 100).round(1)
  end

  def calculate_freshness_score(records)
    return 0 if records.empty?
    
    latest_record = records.maximum(:created_at)
    hours_since_latest = ((Time.current - latest_record) / 1.hour).round(1)
    
    case hours_since_latest
    when 0..1 then 100
    when 1..6 then 90
    when 6..24 then 75
    when 24..72 then 50
    else 25
    end
  end

  def calculate_validity_score(data, source_type)
    return 0 if data.empty?
    
    valid_records = 0
    total_records = data.count
    
    data.each do |record|
      next unless record.is_a?(Hash)
      
      # Basic validation based on source type
      case source_type
      when 'shopify', 'woocommerce'
        valid_records += 1 if record['id'].present? && record['created_at'].present?
      when 'amazon_seller_central'
        valid_records += 1 if record['order_id'].present? || record['asin'].present?
      else
        valid_records += 1 if record.keys.any?
      end
    end
    
    ((valid_records.to_f / total_records) * 100).round(1)
  end

  def calculate_uniqueness_score(data)
    return 0 if data.empty?
    
    # Simple uniqueness check based on record content
    unique_records = data.uniq.count
    total_records = data.count
    
    ((unique_records.to_f / total_records) * 100).round(1)
  end

  def calculate_volume_trend(data_source)
    # Calculate 7-day volume trend
    daily_counts = (0..6).map do |days_ago|
      date = days_ago.days.ago.to_date
      data_source.raw_data_records
        .where(created_at: date.beginning_of_day..date.end_of_day)
        .count
    end.reverse
    
    {
      daily_counts: daily_counts,
      trend: calculate_trend_direction(daily_counts),
      average: daily_counts.sum / 7.0
    }
  end

  def calculate_schema_stability(data)
    return { stability: 100, variations: 0 } if data.empty?
    
    # Analyze schema variations across records
    schemas = data.map { |record| record.keys.sort if record.is_a?(Hash) }.compact.uniq
    
    {
      stability: schemas.count == 1 ? 100 : [100 - (schemas.count * 10), 0].max,
      variations: schemas.count,
      common_schema: schemas.first || []
    }
  end

  def calculate_trend_direction(values)
    return 'stable' if values.count < 2
    
    recent_avg = values.last(3).sum / 3.0
    earlier_avg = values.first(3).sum / 3.0
    
    if recent_avg > earlier_avg * 1.1
      'increasing'
    elsif recent_avg < earlier_avg * 0.9
      'decreasing'
    else
      'stable'
    end
  end

  def calculate_overall_metrics(source_metrics)
    return default_overall_metrics if source_metrics.empty?
    
    total_records = source_metrics.sum { |m| m[:total_records] }
    total_issues = source_metrics.sum { |m| m[:issues_count] }
    
    avg_completeness = source_metrics.sum { |m| m[:completeness] } / source_metrics.count
    avg_accuracy = source_metrics.sum { |m| m[:accuracy] } / source_metrics.count
    avg_freshness = source_metrics.sum { |m| m[:freshness] } / source_metrics.count
    avg_consistency = source_metrics.sum { |m| m[:consistency] } / source_metrics.count
    
    overall_score = (avg_completeness + avg_accuracy + avg_freshness + avg_consistency) / 4.0
    
    {
      completeness_score: avg_completeness.round(1),
      accuracy_score: avg_accuracy.round(1),
      freshness_score: avg_freshness.round(1),
      consistency_score: avg_consistency.round(1),
      overall_quality_score: overall_score.round(1),
      total_records_analyzed: total_records,
      quality_issues: total_issues,
      quality_status: determine_quality_status(overall_score),
      last_quality_check: Time.current
    }
  end

  def determine_quality_status(score)
    case score
    when 90..100 then "excellent"
    when 80..89 then "good"
    when 70..79 then "fair"
    when 60..69 then "poor"
    else "critical"
    end
  end

  def calculate_system_health
    connected_sources = @data_sources.connected.count
    total_sources = @data_sources.count
    
    return 'critical' if total_sources == 0
    
    health_percentage = (connected_sources.to_f / total_sources) * 100
    
    case health_percentage
    when 90..100 then 'excellent'
    when 75..89 then 'good'
    when 50..74 then 'fair'
    when 25..49 then 'poor'
    else 'critical'
    end
  end

  def default_comprehensive_metrics
    {
      overall: default_overall_metrics,
      by_source: {},
      daily_trends: {},
      summary: {
        total_sources_monitored: 0,
        sources_with_issues: 0,
        average_quality_score: 0,
        last_analysis: Time.current
      }
    }
  end

  def default_overall_metrics
    {
      completeness_score: 0,
      accuracy_score: 0,
      freshness_score: 0,
      consistency_score: 0,
      overall_quality_score: 0,
      total_records_analyzed: 0,
      quality_issues: 0,
      quality_status: "unknown",
      last_quality_check: Time.current
    }
  end

  def default_source_metrics
    {
      completeness: 0,
      accuracy: 0,
      freshness: 0,
      consistency: 0,
      validity: 0,
      uniqueness: 0,
      total_records: 0,
      issues: [],
      last_validation: Time.current,
      data_volume_trend: { daily_counts: [], trend: 'stable', average: 0 },
      schema_stability: { stability: 100, variations: 0 }
    }
  end

  def generate_quality_report_pdf(report)
    # This would integrate with a PDF generation library like Prawn
    # For now, return a placeholder
    require 'prawn'
    
    Prawn::Document.new do |pdf|
      pdf.text "Data Quality Report", size: 24, style: :bold
      pdf.move_down 20
      pdf.text "Generated: #{Time.current.strftime('%B %d, %Y at %I:%M %p')}"
      pdf.move_down 10
      pdf.text "Overall Score: #{report.overall_score}%"
      # Add more report content here
    end
  end
end