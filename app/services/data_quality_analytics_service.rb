# frozen_string_literal: true

class DataQualityAnalyticsService
  def initialize(organization = nil)
    @organization = organization
  end

  def generate_dashboard_metrics
    {
      overall_metrics: calculate_overall_metrics,
      quality_trends: calculate_quality_trends,
      data_source_summary: generate_data_source_summary,
      alerts: generate_quality_alerts,
      recommendations: generate_global_recommendations
    }
  end

  def calculate_data_source_quality(data_source, options = {})
    reports = data_source.data_quality_reports.completed

    return default_quality_metrics if reports.empty?

    latest_report = reports.order(:created_at).last
    previous_report = reports.where("created_at < ?", latest_report.created_at).order(:created_at).last

    {
      current_score: latest_report.overall_score,
      previous_score: previous_report&.overall_score,
      trend: calculate_trend(latest_report.overall_score, previous_report&.overall_score),
      dimension_scores: {
        completeness: latest_report.completeness_score,
        accuracy: latest_report.accuracy_score,
        consistency: latest_report.consistency_score,
        validity: latest_report.validity_score,
        timeliness: latest_report.timeliness_score,
        uniqueness: latest_report.respond_to?(:uniqueness_score) ? latest_report.uniqueness_score : nil,
        freshness: latest_report.respond_to?(:freshness_score) ? latest_report.freshness_score : nil
      }.compact,
      last_validation: latest_report.created_at,
      issues_count: latest_report.issues_count,
      status: determine_status(latest_report.overall_score),
      recommendations_count: latest_report.recommendations.count
    }
  end

  def generate_quality_trends(days = 30)
    end_date = Date.current
    start_date = end_date - days.days

    # Get daily quality scores
    daily_scores = DataQualityReport.completed
                                   .joins(:data_source)
                                   .where(data_sources: organization_scope)
                                   .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
                                   .group_by_day(:created_at, range: start_date..end_date)
                                   .average(:overall_score)

    # Fill missing days with previous day's value or 0
    filled_scores = {}
    previous_score = 0

    (start_date..end_date).each do |date|
      score = daily_scores[date]&.round(1) || previous_score
      filled_scores[date.strftime("%Y-%m-%d")] = score
      previous_score = score if score > 0
    end

    {
      daily_scores: filled_scores,
      average_score: daily_scores.values.compact.sum / [ daily_scores.values.compact.count, 1 ].max,
      trend_direction: calculate_trend_direction(filled_scores.values.last(7)),
      improvement: calculate_improvement(filled_scores.values.first(7), filled_scores.values.last(7))
    }
  end

  def generate_data_source_rankings
    data_sources = DataSource.joins(:data_quality_reports)
                            .where(data_quality_reports: { status: "completed" })
                            .where(organization_scope)
                            .includes(:data_quality_reports)
                            .distinct

    rankings = data_sources.map do |ds|
      latest_report = ds.data_quality_reports.completed.order(:created_at).last
      next unless latest_report

      {
        data_source: ds,
        current_score: latest_report.overall_score,
        trend: calculate_data_source_trend(ds),
        last_validation: latest_report.created_at,
        issues_count: latest_report.issues_count,
        records_count: latest_report.total_records
      }
    end.compact

    # Sort by score descending
    rankings.sort_by { |r| -r[:current_score] }
  end

  def identify_quality_issues_patterns
    reports = DataQualityReport.completed
                              .joins(:data_source)
                              .where(data_sources: organization_scope)
                              .where("created_at > ?", 30.days.ago)
                              .includes(:data_source)

    # Aggregate issues by type and data source type
    issue_patterns = {}

    reports.each do |report|
      source_type = report.data_source.source_type

      report.issues.each do |issue|
        pattern_key = "#{source_type}:#{issue['type']}"
        issue_patterns[pattern_key] ||= {
          source_type: source_type,
          issue_type: issue["type"],
          occurrences: 0,
          affected_sources: Set.new,
          severity_distribution: Hash.new(0)
        }

        issue_patterns[pattern_key][:occurrences] += issue["count"] || 1
        issue_patterns[pattern_key][:affected_sources] << report.data_source.id
        issue_patterns[pattern_key][:severity_distribution][issue["severity"]] += 1
      end
    end

    # Convert to array and sort by impact
    issue_patterns.values.map do |pattern|
      pattern[:affected_sources] = pattern[:affected_sources].count
      pattern[:impact_score] = calculate_issue_impact(pattern)
      pattern
    end.sort_by { |p| -p[:impact_score] }
  end

  def generate_improvement_recommendations
    # Analyze patterns and generate actionable recommendations
    issue_patterns = identify_quality_issues_patterns
    data_source_rankings = generate_data_source_rankings

    recommendations = []

    # Recommendations based on common issues
    issue_patterns.first(3).each do |pattern|
      recommendations << {
        type: "issue_pattern",
        priority: determine_recommendation_priority(pattern[:impact_score]),
        title: "Address #{pattern[:issue_type].humanize} Issues in #{pattern[:source_type].humanize} Sources",
        description: "#{pattern[:occurrences]} occurrences across #{pattern[:affected_sources]} data sources",
        action: generate_issue_action(pattern[:issue_type]),
        affected_sources: pattern[:affected_sources],
        estimated_impact: "Medium to High"
      }
    end

    # Recommendations for low-performing data sources
    low_performers = data_source_rankings.select { |r| r[:current_score] < 70 }
    if low_performers.any?
      recommendations << {
        type: "performance",
        priority: "high",
        title: "Improve Low-Performing Data Sources",
        description: "#{low_performers.count} data sources have quality scores below 70%",
        action: "Review data collection and validation processes for these sources",
        affected_sources: low_performers.count,
        estimated_impact: "High"
      }
    end

    # Recommendations for trending down sources
    declining_sources = data_source_rankings.select { |r| r[:trend] == "declining" }
    if declining_sources.any?
      recommendations << {
        type: "trend",
        priority: "medium",
        title: "Address Declining Quality Trends",
        description: "#{declining_sources.count} data sources show declining quality trends",
        action: "Investigate recent changes in data sources or processing pipelines",
        affected_sources: declining_sources.count,
        estimated_impact: "Medium"
      }
    end

    recommendations
  end

  def calculate_quality_score_distribution
    reports = DataQualityReport.completed
                              .joins(:data_source)
                              .where(data_sources: organization_scope)
                              .where("created_at > ?", 30.days.ago)

    distribution = {
      "excellent" => reports.where("overall_score >= 90").count,
      "good" => reports.where("overall_score >= 80 AND overall_score < 90").count,
      "fair" => reports.where("overall_score >= 70 AND overall_score < 80").count,
      "poor" => reports.where("overall_score >= 50 AND overall_score < 70").count,
      "critical" => reports.where("overall_score < 50").count
    }

    total = distribution.values.sum
    return distribution if total == 0

    # Convert to percentages
    distribution.transform_values { |count| ((count.to_f / total) * 100).round(1) }
  end

  private

  def calculate_overall_metrics
    reports = recent_reports

    return default_overall_metrics if reports.empty?

    {
      average_quality_score: reports.average(:overall_score)&.round(1) || 0,
      total_data_sources: reports.joins(:data_source).distinct.count(:data_source_id),
      total_issues: reports.sum(:issues_count),
      data_sources_needing_attention: reports.where("overall_score < 70").joins(:data_source).distinct.count(:data_source_id),
      last_updated: reports.maximum(:created_at)
    }
  end

  def calculate_quality_trends
    generate_quality_trends(7) # Last 7 days
  end

  def generate_data_source_summary
    generate_data_source_rankings.first(10) # Top 10 data sources
  end

  def generate_quality_alerts
    alerts = []

    # Critical quality scores
    critical_sources = DataSource.joins(:data_quality_reports)
                                 .where(data_quality_reports: { status: "completed" })
                                 .where(organization_scope)
                                 .where("data_quality_reports.overall_score < 50")
                                 .where("data_quality_reports.created_at > ?", 24.hours.ago)
                                 .distinct

    critical_sources.each do |source|
      alerts << {
        type: "critical_quality",
        severity: "high",
        title: "Critical Quality Issues in #{source.name}",
        description: "Quality score below 50%",
        data_source_id: source.id,
        created_at: Time.current
      }
    end

    # Declining trends
    declining_sources = generate_data_source_rankings.select { |r| r[:trend] == "declining" }
    declining_sources.first(3).each do |source_data|
      alerts << {
        type: "declining_trend",
        severity: "medium",
        title: "Quality Declining for #{source_data[:data_source].name}",
        description: "Quality score has been decreasing over recent validations",
        data_source_id: source_data[:data_source].id,
        created_at: Time.current
      }
    end

    alerts.sort_by { |a| a[:severity] == "high" ? 0 : 1 }
  end

  def generate_global_recommendations
    generate_improvement_recommendations.first(5)
  end

  def recent_reports
    @recent_reports ||= DataQualityReport.completed
                                         .joins(:data_source)
                                         .where(data_sources: organization_scope)
                                         .where("data_quality_reports.created_at > ?", 7.days.ago)
  end

  def organization_scope
    @organization ? { organization: @organization } : {}
  end

  def default_quality_metrics
    {
      current_score: 0,
      previous_score: nil,
      trend: "no_data",
      dimension_scores: {},
      last_validation: nil,
      issues_count: 0,
      status: "unknown",
      recommendations_count: 0
    }
  end

  def default_overall_metrics
    {
      average_quality_score: 0,
      total_data_sources: 0,
      total_issues: 0,
      data_sources_needing_attention: 0,
      last_updated: nil
    }
  end

  def calculate_trend(current_score, previous_score)
    return "no_data" unless previous_score

    diff = current_score - previous_score

    case diff
    when 5..Float::INFINITY then "improving"
    when -5..5 then "stable"
    else "declining"
    end
  end

  def determine_status(score)
    case score
    when 90..100 then "excellent"
    when 80..89 then "good"
    when 70..79 then "fair"
    when 50..69 then "poor"
    else "critical"
    end
  end

  def calculate_trend_direction(values)
    return "stable" if values.count < 2

    recent_avg = values.last(3).sum / [ values.last(3).count, 1 ].max
    earlier_avg = values.first(3).sum / [ values.first(3).count, 1 ].max

    if recent_avg > earlier_avg * 1.05
      "improving"
    elsif recent_avg < earlier_avg * 0.95
      "declining"
    else
      "stable"
    end
  end

  def calculate_improvement(earlier_values, recent_values)
    return 0 if earlier_values.empty? || recent_values.empty?

    earlier_avg = earlier_values.sum / earlier_values.count
    recent_avg = recent_values.sum / recent_values.count

    ((recent_avg - earlier_avg) / [ earlier_avg, 1 ].max * 100).round(1)
  end

  def calculate_data_source_trend(data_source)
    reports = data_source.data_quality_reports.completed.order(:created_at).last(5)
    return "no_data" if reports.count < 2

    scores = reports.map(&:overall_score)
    calculate_trend_direction(scores)
  end

  def calculate_issue_impact(pattern)
    # Impact based on occurrences, affected sources, and severity
    base_score = pattern[:occurrences] * pattern[:affected_sources]

    severity_multiplier = case pattern[:severity_distribution].max_by { |_, count| count }&.first
    when "critical" then 3.0
    when "high" then 2.0
    when "medium" then 1.5
    else 1.0
    end

    (base_score * severity_multiplier).round(1)
  end

  def determine_recommendation_priority(impact_score)
    case impact_score
    when 0..10 then "low"
    when 10..50 then "medium"
    else "high"
    end
  end

  def generate_issue_action(issue_type)
    case issue_type
    when "presence"
      "Review data collection processes to ensure required fields are captured"
    when "format"
      "Implement data validation and standardization rules"
    when "data_type"
      "Update data parsing and type conversion logic"
    when "consistency"
      "Establish data format standards and validation rules"
    when "accuracy"
      "Implement data quality checks and validation processes"
    else
      "Review and improve data quality processes"
    end
  end
end
