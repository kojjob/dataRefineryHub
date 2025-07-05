class EnhancedDataPreviewComponent < ViewComponent::Base
  include ApplicationHelper

  def initialize(preview_data:, data_source:, user:)
    @preview_data = preview_data
    @data_source = data_source
    @user = user
    @success = preview_data[:success]
  end

  private

  attr_reader :preview_data, :data_source, :user, :success

  def file_info
    @file_info ||= preview_data[:file_info] || {}
  end

  def structure_summary
    @structure_summary ||= preview_data[:structure_summary] || {}
  end

  def business_insights
    @business_insights ||= preview_data[:business_insights] || {}
  end

  def data_quality
    @data_quality ||= preview_data[:data_quality] || {}
  end

  def sample_data
    @sample_data ||= preview_data[:sample_data] || {}
  end

  def transformation_suggestions
    @transformation_suggestions ||= preview_data[:transformation_suggestions] || {}
  end

  def business_impact
    @business_impact ||= preview_data[:business_impact] || {}
  end

  def next_steps
    @next_steps ||= preview_data[:next_steps] || {}
  end

  def quality_color_class(score)
    case score.to_i
    when 90..100 then "text-green-600 bg-green-100"
    when 80..89 then "text-blue-600 bg-blue-100"
    when 70..79 then "text-yellow-600 bg-yellow-100"
    when 60..69 then "text-orange-600 bg-orange-100"
    else "text-red-600 bg-red-100"
    end
  end

  def quality_grade_color(grade)
    case grade
    when "A" then "text-green-700 bg-green-200"
    when "B" then "text-blue-700 bg-blue-200"
    when "C" then "text-yellow-700 bg-yellow-200"
    when "D" then "text-orange-700 bg-orange-200"
    else "text-red-700 bg-red-200"
    end
  end

  def impact_level_color(level)
    case level&.downcase
    when "high" then "text-green-700 bg-green-200"
    when "medium" then "text-blue-700 bg-blue-200"
    when "moderate" then "text-yellow-700 bg-yellow-200"
    else "text-gray-700 bg-gray-200"
    end
  end

  def complexity_color(complexity)
    case complexity&.downcase
    when "simple" then "text-green-700 bg-green-200"
    when "moderate" then "text-blue-700 bg-blue-200"
    when "complex" then "text-orange-700 bg-orange-200"
    when "advanced" then "text-red-700 bg-red-200"
    else "text-gray-700 bg-gray-200"
    end
  end

  def business_field_category_color(category)
    colors = {
      customer: "text-blue-700 bg-blue-100 border-blue-200",
      financial: "text-green-700 bg-green-100 border-green-200",
      product: "text-purple-700 bg-purple-100 border-purple-200",
      order: "text-orange-700 bg-orange-100 border-orange-200",
      marketing: "text-pink-700 bg-pink-100 border-pink-200",
      temporal: "text-indigo-700 bg-indigo-100 border-indigo-200",
      location: "text-cyan-700 bg-cyan-100 border-cyan-200"
    }

    colors[category&.to_sym] || "text-gray-700 bg-gray-100 border-gray-200"
  end

  def transformation_confidence_color(confidence)
    case confidence.to_f
    when 0.8..1.0 then "text-green-700 bg-green-100"
    when 0.6..0.79 then "text-blue-700 bg-blue-100"
    when 0.4..0.59 then "text-yellow-700 bg-yellow-100"
    else "text-gray-700 bg-gray-100"
    end
  end

  def priority_color(priority)
    case priority&.downcase
    when "immediate" then "text-red-700 bg-red-100 border-red-200"
    when "short_term" then "text-orange-700 bg-orange-100 border-orange-200"
    when "long_term" then "text-blue-700 bg-blue-100 border-blue-200"
    else "text-gray-700 bg-gray-100 border-gray-200"
    end
  end

  def format_confidence(confidence)
    "#{(confidence.to_f * 100).round}%"
  end

  def format_metric_value(value)
    case value
    when Numeric
      value.round(1)
    when String
      value.include?("%") ? value : "#{value.to_f.round(1)}%"
    else
      value.to_s
    end
  end

  def truncate_text(text, length = 100)
    return text if text.length <= length
    "#{text[0...length]}..."
  end

  def detected_entities_list
    return [] unless business_insights[:detected_entities]

    business_insights[:detected_entities].map do |entity|
      {
        name: entity.to_s.humanize,
        icon: entity_icon(entity),
        color: business_field_category_color(entity)
      }
    end
  end

  def entity_icon(entity)
    icons = {
      customer: "👤",
      financial: "💰",
      product: "📦",
      order: "🛒",
      marketing: "📊",
      temporal: "⏰",
      location: "🌍"
    }

    icons[entity&.to_sym] || "📋"
  end

  def sample_rows
    return [] unless sample_data[:samples]

    sample_data[:samples].first(5) # Limit to first 5 rows for display
  end

  def sample_headers
    return [] if sample_rows.empty?

    sample_rows.first[:data]&.keys || []
  end

  def get_business_annotation(row_data, field)
    return nil unless row_data[:business_annotations]

    row_data[:business_annotations][field]
  end

  def has_quality_flags?(row_data)
    row_data[:quality_flags]&.any?
  end

  def quality_issues_summary
    return {} unless data_quality[:issues]

    {
      count: data_quality[:issues].length,
      critical: data_quality[:issues].count { |issue| issue.include?("critical") || issue.include?("failed") },
      warnings: data_quality[:issues].count { |issue| issue.include?("low") || issue.include?("limited") }
    }
  end

  def transformation_summary
    return {} unless transformation_suggestions[:recommended] || transformation_suggestions[:optional]

    {
      recommended_count: transformation_suggestions[:recommended]&.length || 0,
      optional_count: transformation_suggestions[:optional]&.length || 0,
      total_count: transformation_suggestions[:total_suggested] || 0
    }
  end

  def immediate_actions_count
    next_steps[:immediate_actions]&.length || 0
  end

  def short_term_opportunities_count
    next_steps[:short_term_opportunities]&.length || 0
  end

  def has_cross_reference_opportunities?
    business_insights[:cross_reference_opportunities]&.any?
  end

  def automation_opportunities_preview
    return [] unless business_insights[:automation_suggestions]

    business_insights[:automation_suggestions].first(3)
  end

  def analysis_opportunities_preview
    return [] unless business_insights[:analysis_opportunities]

    business_insights[:analysis_opportunities].first(3)
  end

  def business_outcomes_preview
    return [] unless business_impact[:business_outcomes]

    business_impact[:business_outcomes].first(4)
  end

  def error_message
    preview_data[:error] if preview_data[:error]
  end

  def error_suggestions
    preview_data[:suggestions] || []
  end

  def processing_recommendations
    return [] unless data_quality[:recommendations]

    data_quality[:recommendations].first(3)
  end

  def estimated_setup_time
    next_steps[:total_estimated_setup_time] || "30-60 minutes"
  end

  def roi_estimate
    business_impact[:roi_estimate] || "ROI analysis pending"
  end

  def data_richness_percentage
    return 0 unless business_impact[:factors]

    ((business_impact[:factors][:data_richness] || 0) * 100).round
  end

  def analytical_potential_percentage
    return 0 unless business_impact[:factors]

    ((business_impact[:factors][:analytical_potential] || 0) * 100).round
  end

  def time_to_insights
    business_impact[:factors][:time_to_insights] || "Unknown"
  end
end
