# frozen_string_literal: true

module DataQualityHelper
  # Quality score color classes
  def quality_score_color(score)
    case score.to_f
    when 90..100 then "text-green-600"
    when 80..89 then "text-blue-600"
    when 70..79 then "text-yellow-600"
    when 60..69 then "text-orange-600"
    else "text-red-600"
    end
  end

  # Quality progress bar color classes
  def quality_progress_color(score)
    case score.to_f
    when 90..100 then "bg-green-500"
    when 80..89 then "bg-blue-500"
    when 70..79 then "bg-yellow-500"
    when 60..69 then "bg-orange-500"
    else "bg-red-500"
    end
  end

  # Quality status badge classes
  def quality_status_badge_class(status)
    case status.to_s.downcase
    when "excellent"
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"
    when "good"
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800"
    when "fair"
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800"
    when "poor"
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-orange-100 text-orange-800"
    when "critical"
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800"
    else
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"
    end
  end

  # Data source type color classes
  def source_type_color(source_type)
    case source_type.to_s.downcase
    when "shopify"
      "bg-green-500"
    when "woocommerce"
      "bg-purple-500"
    when "amazon_seller_central"
      "bg-orange-500"
    when "file_upload"
      "bg-blue-500"
    when "api"
      "bg-indigo-500"
    when "database"
      "bg-gray-500"
    else
      "bg-gray-400"
    end
  end

  # Alert background classes
  def alert_background_class(severity)
    case severity.to_s.downcase
    when "high", "critical"
      "bg-red-50 border-red-200"
    when "medium", "warning"
      "bg-yellow-50 border-yellow-200"
    when "low", "info"
      "bg-blue-50 border-blue-200"
    else
      "bg-gray-50 border-gray-200"
    end
  end

  # Issue severity classes
  def issue_severity_class(severity)
    case severity.to_s.downcase
    when "high", "critical"
      "bg-red-100 text-red-800"
    when "medium", "warning"
      "bg-yellow-100 text-yellow-800"
    when "low", "info"
      "bg-blue-100 text-blue-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  # Recommendation priority classes
  def recommendation_priority_class(priority)
    case priority.to_s.downcase
    when "high"
      "bg-red-100 text-red-800"
    when "medium"
      "bg-yellow-100 text-yellow-800"
    when "low"
      "bg-green-100 text-green-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  # Recommendation border classes
  def recommendation_border_class(priority)
    case priority.to_s.downcase
    when "high"
      "border-red-400"
    when "medium"
      "border-yellow-400"
    when "low"
      "border-green-400"
    else
      "border-gray-400"
    end
  end

  # Trend badge classes
  def trend_badge_class(trend)
    case trend.to_s.downcase
    when "increasing"
      "bg-green-100 text-green-800"
    when "decreasing"
      "bg-red-100 text-red-800"
    when "stable"
      "bg-blue-100 text-blue-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  # Determine quality status from score
  def determine_quality_status(score)
    case score.to_f
    when 90..100 then "excellent"
    when 80..89 then "good"
    when 70..79 then "fair"
    when 60..69 then "poor"
    else "critical"
    end
  end

  # Format quality metric with icon
  def quality_metric_with_icon(metric_name, score)
    icon_class = case metric_name.to_s.downcase
    when "completeness"
                  "text-blue-500"
    when "accuracy"
                  "text-green-500"
    when "freshness"
                  "text-yellow-500"
    when "consistency"
                  "text-purple-500"
    when "validity"
                  "text-indigo-500"
    when "uniqueness"
                  "text-pink-500"
    else
                  "text-gray-500"
    end

    content_tag :div, class: "flex items-center space-x-2" do
      concat content_tag(:div, class: "w-3 h-3 rounded-full #{quality_progress_color(score)}")
      concat content_tag(:span, "#{metric_name.humanize}: #{score}%", class: "text-sm font-medium")
    end
  end

  # Format data volume with appropriate units
  def format_data_volume(count)
    case count
    when 0..999
      count.to_s
    when 1_000..999_999
      "#{(count / 1_000.0).round(1)}K"
    when 1_000_000..999_999_999
      "#{(count / 1_000_000.0).round(1)}M"
    else
      "#{(count / 1_000_000_000.0).round(1)}B"
    end
  end

  # Quality score trend indicator
  def quality_trend_indicator(current_score, previous_score)
    return content_tag(:span, "—", class: "text-gray-400") if previous_score.nil?

    difference = current_score - previous_score

    if difference > 2
      content_tag :span, class: "inline-flex items-center text-green-600" do
        concat "↗ +#{difference.round(1)}%"
      end
    elsif difference < -2
      content_tag :span, class: "inline-flex items-center text-red-600" do
        concat "↘ #{difference.round(1)}%"
      end
    else
      content_tag :span, class: "inline-flex items-center text-gray-600" do
        concat "→ #{difference >= 0 ? '+' : ''}#{difference.round(1)}%"
      end
    end
  end

  # Quality dimension explanation
  def quality_dimension_explanation(dimension)
    explanations = {
      "completeness" => "Measures the percentage of required fields that contain data across all records.",
      "accuracy" => "Evaluates how correct and precise the data values are according to business rules.",
      "freshness" => "Assesses how recent and up-to-date the data is relative to when it was created or last updated.",
      "consistency" => "Checks for uniform data formats, naming conventions, and structural patterns across records.",
      "validity" => "Verifies that data conforms to defined formats, ranges, and business constraints.",
      "uniqueness" => "Identifies and measures the presence of duplicate records in the dataset."
    }

    explanations[dimension.to_s.downcase] || "Quality metric for #{dimension.humanize.downcase}."
  end

  # Quality improvement suggestion
  def quality_improvement_suggestion(dimension, score)
    suggestions = {
      "completeness" => {
        low: "Review data extraction processes to ensure all required fields are captured.",
        medium: "Implement validation rules to prevent incomplete records from being processed.",
        high: "Consider making additional fields required to improve data richness."
      },
      "accuracy" => {
        low: "Implement data validation rules and format checks at the point of entry.",
        medium: "Set up automated data quality checks and alerts for accuracy issues.",
        high: "Fine-tune validation rules to catch edge cases and improve precision."
      },
      "freshness" => {
        low: "Increase data synchronization frequency or implement real-time updates.",
        medium: "Set up monitoring alerts for data staleness and update schedules.",
        high: "Optimize data pipeline performance for faster processing."
      },
      "consistency" => {
        low: "Standardize data formats and implement transformation rules.",
        medium: "Create data dictionaries and enforce naming conventions.",
        high: "Implement automated data normalization processes."
      }
    }

    level = case score.to_f
    when 0..60 then :low
    when 61..80 then :medium
    else :high
    end

    suggestions.dig(dimension.to_s.downcase, level) || "Continue monitoring this quality dimension."
  end

  # Format quality report summary
  def quality_report_summary(metrics)
    total_score = metrics[:overall_quality_score] || 0
    status = determine_quality_status(total_score)

    content_tag :div, class: "quality-summary" do
      concat content_tag(:div, "#{total_score}%", class: "text-3xl font-bold #{quality_score_color(total_score)}")
      concat content_tag(:div, status.humanize, class: "text-sm #{quality_status_badge_class(status)}")
    end
  end

  # Data quality chart configuration
  def quality_chart_config(data, chart_type = "line")
    {
      type: chart_type,
      data: data,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom"
          },
          tooltip: {
            mode: "index",
            intersect: false
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            max: 100,
            ticks: {
              callback: 'function(value) { return value + "%"; }'
            }
          }
        },
        interaction: {
          mode: "nearest",
          axis: "x",
          intersect: false
        }
      }
    }.to_json.html_safe
  end

  # Quality metrics comparison
  def compare_quality_metrics(current, previous)
    return {} if previous.nil?

    comparison = {}

    %w[completeness accuracy freshness consistency].each do |metric|
      current_value = current[metric.to_sym] || 0
      previous_value = previous[metric.to_sym] || 0
      difference = current_value - previous_value

      comparison[metric] = {
        current: current_value,
        previous: previous_value,
        difference: difference,
        trend: difference > 1 ? "up" : (difference < -1 ? "down" : "stable")
      }
    end

    comparison
  end

  # Quality alert priority
  def quality_alert_priority(score, threshold = 70)
    if score < threshold * 0.5
      "critical"
    elsif score < threshold * 0.7
      "high"
    elsif score < threshold
      "medium"
    else
      "low"
    end
  end

  # Format quality issue count
  def format_issue_count(count)
    case count
    when 0
      content_tag :span, "No issues", class: "text-green-600 font-medium"
    when 1
      content_tag :span, "1 issue", class: "text-yellow-600 font-medium"
    else
      content_tag :span, "#{count} issues", class: "text-red-600 font-medium"
    end
  end

  # Quality dimension icon
  def quality_dimension_icon(dimension)
    icons = {
      "completeness" => "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z",
      "accuracy" => "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z",
      "freshness" => "M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z",
      "consistency" => "M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3",
      "validity" => "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z",
      "uniqueness" => "M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"
    }

    path = icons[dimension.to_s.downcase] || icons["completeness"]

    content_tag :svg, class: "h-5 w-5", fill: "none", viewBox: "0 0 24 24", stroke: "currentColor" do
      content_tag :path, "", "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: path
    end
  end
end
