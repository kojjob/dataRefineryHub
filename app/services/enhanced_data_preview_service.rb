class EnhancedDataPreviewService
  include ActiveModel::Model

  attr_accessor :data_source, :file, :user

  BUSINESS_FIELD_PATTERNS = {
    customer: {
      patterns: /\b(customer|client|user|contact|buyer|purchaser|name|email|phone|address)\b/i,
      icon: "👤",
      color: "blue",
      insights: ["Customer identification and segmentation", "Contact management", "Communication optimization"]
    },
    financial: {
      patterns: /\b(price|cost|revenue|profit|amount|total|value|payment|billing|tax|discount|fee)\b/i,
      icon: "💰",
      color: "green",
      insights: ["Revenue analysis", "Profitability tracking", "Financial performance"]
    },
    product: {
      patterns: /\b(product|item|sku|inventory|stock|quantity|category|brand|model|variant)\b/i,
      icon: "📦",
      color: "purple",
      insights: ["Product performance", "Inventory management", "Catalog optimization"]
    },
    order: {
      patterns: /\b(order|transaction|purchase|sale|checkout|cart|shipment|delivery|status)\b/i,
      icon: "🛒",
      color: "orange",
      insights: ["Order lifecycle tracking", "Sales funnel analysis", "Fulfillment optimization"]
    },
    marketing: {
      patterns: /\b(campaign|source|medium|utm|referrer|channel|conversion|click|impression|ad)\b/i,
      icon: "📊",
      color: "pink",
      insights: ["Marketing attribution", "Campaign effectiveness", "ROI measurement"]
    },
    temporal: {
      patterns: /\b(date|time|created|updated|timestamp|when|day|month|year|period)\b/i,
      icon: "⏰",
      color: "indigo",
      insights: ["Trend analysis", "Seasonality patterns", "Time-series forecasting"]
    },
    location: {
      patterns: /\b(address|city|state|country|zip|postal|region|location|geo|lat|lng|longitude|latitude)\b/i,
      icon: "🌍",
      color: "cyan",
      insights: ["Geographic analysis", "Regional performance", "Location-based insights"]
    }
  }.freeze

  DATA_QUALITY_THRESHOLDS = {
    excellent: { completeness: 95, uniqueness: 80, validity: 98 },
    good: { completeness: 85, uniqueness: 60, validity: 90 },
    fair: { completeness: 70, uniqueness: 40, validity: 80 },
    poor: { completeness: 0, uniqueness: 0, validity: 0 }
  }.freeze

  def initialize(data_source:, file: nil, user:)
    @data_source = data_source
    @file = file
    @user = user
    @processor = FileProcessorService.new(
      data_source: data_source,
      file: file,
      user: user
    )
  end

  def generate_enhanced_preview(limit: 20)
    begin
      # Get basic file analysis
      structure_analysis = @processor.analyze_structure
      preview_data = @processor.preview_data(limit: limit)
      
      return base_error_response("Unable to analyze file") if structure_analysis.empty? || preview_data.empty?

      # Generate enhanced insights
      {
        success: true,
        file_info: extract_file_info,
        structure_summary: enhance_structure_summary(structure_analysis),
        business_insights: generate_business_insights(structure_analysis),
        data_quality: analyze_data_quality(structure_analysis, preview_data),
        sample_data: enhance_sample_data(preview_data),
        transformation_suggestions: generate_smart_transformations(structure_analysis),
        business_impact: calculate_business_impact(structure_analysis),
        next_steps: generate_next_steps(structure_analysis)
      }
    rescue => e
      Rails.logger.error "Enhanced preview generation failed: #{e.message}"
      base_error_response("Failed to generate preview: #{e.message}")
    end
  end

  def quick_business_scan(sample_limit: 5)
    begin
      preview_data = @processor.preview_data(limit: sample_limit)
      return { business_fields: [], confidence: 0 } if preview_data.empty?

      detected_fields = detect_business_fields(preview_data.first&.keys || [])
      
      {
        business_fields: detected_fields,
        confidence: calculate_detection_confidence(detected_fields),
        estimated_value: estimate_business_value(detected_fields),
        quick_insights: generate_quick_insights(detected_fields)
      }
    rescue => e
      Rails.logger.error "Quick business scan failed: #{e.message}"
      { business_fields: [], confidence: 0, error: e.message }
    end
  end

  private

  def extract_file_info
    {
      name: @file&.original_filename || "Unknown",
      size: format_file_size(@file&.size || 0),
      type: @file&.content_type || "Unknown",
      extension: File.extname(@file&.original_filename || "").downcase,
      uploaded_at: Time.current,
      processing_complexity: estimate_processing_complexity
    }
  end

  def enhance_structure_summary(structure_analysis)
    base_summary = {
      total_rows: structure_analysis[:total_rows] || structure_analysis[:total_items] || 0,
      total_columns: structure_analysis[:total_columns] || structure_analysis[:total_fields] || 0,
      estimated_processing_time: estimate_processing_time(structure_analysis),
      data_density: calculate_data_density(structure_analysis),
      structure_quality: assess_structure_quality(structure_analysis)
    }

    # Add format-specific enhancements
    case structure_analysis[:structure_type]
    when "array"
      base_summary[:structure_notes] = ["JSON array structure", "Consistent field mapping recommended"]
    when "object"
      base_summary[:structure_notes] = ["Single object structure", "May need transformation for analysis"]
    else
      base_summary[:structure_notes] = ["Tabular structure", "Ready for analysis"]
    end

    base_summary
  end

  def generate_business_insights(structure_analysis)
    headers = extract_headers(structure_analysis)
    detected_fields = detect_business_fields(headers)
    
    insights = {
      primary_business_area: determine_primary_business_area(detected_fields),
      detected_entities: detected_fields.map { |field| field[:category] }.uniq,
      analysis_opportunities: generate_analysis_opportunities(detected_fields),
      integration_potential: assess_integration_potential(detected_fields),
      automation_suggestions: suggest_automation_opportunities(detected_fields)
    }

    # Add contextual recommendations based on organization's existing data
    if @data_source.organization.data_sources.any?
      insights[:cross_reference_opportunities] = identify_cross_reference_opportunities(detected_fields)
    end

    insights
  end

  def analyze_data_quality(structure_analysis, preview_data)
    return basic_quality_assessment if preview_data.empty?

    quality_metrics = {
      completeness: calculate_completeness(preview_data),
      uniqueness: calculate_uniqueness(preview_data),
      validity: calculate_validity(preview_data),
      consistency: calculate_consistency(preview_data),
      freshness: assess_data_freshness(preview_data)
    }

    overall_score = (quality_metrics.values.sum / quality_metrics.size).round(1)
    quality_grade = determine_quality_grade(overall_score)

    {
      overall_score: overall_score,
      grade: quality_grade,
      metrics: quality_metrics,
      issues: identify_quality_issues(quality_metrics, preview_data),
      recommendations: generate_quality_recommendations(quality_metrics),
      impact_assessment: assess_quality_impact(quality_grade)
    }
  end

  def enhance_sample_data(preview_data)
    return [] if preview_data.empty?

    sample_data = preview_data.first(10)
    
    enhanced_samples = sample_data.map.with_index do |row, index|
      {
        row_index: index + 1,
        data: row,
        business_annotations: annotate_business_fields(row),
        quality_flags: identify_row_quality_issues(row),
        potential_transformations: suggest_row_transformations(row)
      }
    end

    {
      samples: enhanced_samples,
      row_insights: generate_row_insights(enhanced_samples),
      pattern_detection: detect_data_patterns(sample_data)
    }
  end

  def generate_smart_transformations(structure_analysis)
    headers = extract_headers(structure_analysis)
    column_analysis = structure_analysis[:column_analysis] || {}
    
    transformations = []

    headers.each do |header|
      column_info = column_analysis[header] || {}
      business_context = detect_field_business_context(header)
      
      # Business-context driven transformations
      case business_context[:category]
      when :customer
        transformations += suggest_customer_transformations(header, column_info)
      when :financial
        transformations += suggest_financial_transformations(header, column_info)
      when :temporal
        transformations += suggest_temporal_transformations(header, column_info)
      when :location
        transformations += suggest_location_transformations(header, column_info)
      end

      # Data quality driven transformations
      transformations += suggest_quality_transformations(header, column_info)
    end

    {
      recommended: transformations.select { |t| t[:confidence] > 0.7 },
      optional: transformations.select { |t| t[:confidence] <= 0.7 && t[:confidence] > 0.4 },
      total_suggested: transformations.length,
      estimated_improvement: calculate_transformation_impact(transformations)
    }
  end

  def calculate_business_impact(structure_analysis)
    headers = extract_headers(structure_analysis)
    detected_fields = detect_business_fields(headers)
    
    impact_factors = {
      data_richness: calculate_data_richness(detected_fields),
      analytical_potential: assess_analytical_potential(detected_fields),
      automation_value: estimate_automation_value(detected_fields),
      integration_value: calculate_integration_value(detected_fields),
      time_to_insights: estimate_time_to_insights(structure_analysis)
    }

    overall_impact = (impact_factors.values.sum / impact_factors.size * 100).round

    {
      overall_score: overall_impact,
      impact_level: determine_impact_level(overall_impact),
      factors: impact_factors,
      business_outcomes: predict_business_outcomes(detected_fields),
      roi_estimate: estimate_roi_potential(impact_factors)
    }
  end

  def generate_next_steps(structure_analysis)
    headers = extract_headers(structure_analysis)
    detected_fields = detect_business_fields(headers)
    
    steps = []

    # Immediate actions
    steps << {
      priority: "immediate",
      action: "Process and validate data",
      description: "Import your data to start generating insights",
      estimated_time: "2-5 minutes",
      icon: "⚡"
    }

    # Short-term opportunities
    if detected_fields.any? { |f| f[:category] == :customer }
      steps << {
        priority: "short_term",
        action: "Set up customer segmentation",
        description: "Create customer groups for targeted analysis",
        estimated_time: "10-15 minutes",
        icon: "👥"
      }
    end

    if detected_fields.any? { |f| f[:category] == :financial }
      steps << {
        priority: "short_term",
        action: "Configure financial tracking",
        description: "Set up revenue and profitability monitoring",
        estimated_time: "5-10 minutes",
        icon: "📈"
      }
    end

    # Long-term strategies
    if @data_source.organization.data_sources.count < 3
      steps << {
        priority: "long_term",
        action: "Connect additional data sources",
        description: "Enhance insights with integrated data",
        estimated_time: "30-60 minutes",
        icon: "🔗"
      }
    end

    steps << {
      priority: "long_term",
      action: "Set up automated reporting",
      description: "Create scheduled insights and alerts",
      estimated_time: "20-30 minutes",
      icon: "🤖"
    }

    {
      immediate_actions: steps.select { |s| s[:priority] == "immediate" },
      short_term_opportunities: steps.select { |s| s[:priority] == "short_term" },
      long_term_strategies: steps.select { |s| s[:priority] == "long_term" },
      total_estimated_setup_time: calculate_total_setup_time(steps)
    }
  end

  # Helper methods for business field detection
  def detect_business_fields(headers)
    return [] unless headers

    headers.map do |header|
      business_context = detect_field_business_context(header)
      next unless business_context[:category]

      {
        field_name: header,
        category: business_context[:category],
        confidence: business_context[:confidence],
        icon: business_context[:icon],
        color: business_context[:color],
        insights: business_context[:insights],
        suggested_use_cases: generate_field_use_cases(header, business_context[:category])
      }
    end.compact
  end

  def detect_field_business_context(field_name)
    return { category: nil, confidence: 0 } unless field_name

    field_lower = field_name.to_s.downcase

    BUSINESS_FIELD_PATTERNS.each do |category, config|
      if field_lower.match?(config[:patterns])
        confidence = calculate_pattern_confidence(field_lower, config[:patterns])
        return {
          category: category,
          confidence: confidence,
          icon: config[:icon],
          color: config[:color],
          insights: config[:insights]
        }
      end
    end

    { category: nil, confidence: 0 }
  end

  def calculate_pattern_confidence(field_name, pattern)
    # Check if the field name matches the pattern
    if field_name.match?(pattern)
      # Base confidence higher for exact matches
      base_confidence = 0.7
      
      # Bonus for shorter, clearer field names
      clarity_bonus = field_name.length < 20 ? 0.2 : 0.1
      
      # Bonus for common patterns
      common_patterns_bonus = field_name.match?(/\b(email|name|date|time|address|city|price|total)\b/i) ? 0.1 : 0
      
      [(base_confidence + clarity_bonus + common_patterns_bonus), 1.0].min
    else
      0
    end
  end

  def generate_field_use_cases(field_name, category)
    use_cases = {
      customer: ["Customer segmentation", "Personalization", "Retention analysis"],
      financial: ["Revenue tracking", "Profitability analysis", "Budget planning"],
      product: ["Performance monitoring", "Inventory optimization", "Catalog management"],
      order: ["Sales funnel analysis", "Conversion tracking", "Fulfillment optimization"],
      marketing: ["Campaign ROI", "Attribution modeling", "Channel performance"],
      temporal: ["Trend analysis", "Forecasting", "Seasonality detection"],
      location: ["Geographic analysis", "Regional performance", "Market expansion"]
    }

    use_cases[category] || ["Data analysis", "Reporting", "Business intelligence"]
  end

  # Quality assessment methods
  def calculate_completeness(preview_data)
    return 0 if preview_data.empty?

    total_cells = 0
    filled_cells = 0

    preview_data.each do |row|
      row.each do |_, value|
        total_cells += 1
        filled_cells += 1 unless value.blank?
      end
    end

    return 0 if total_cells == 0
    (filled_cells.to_f / total_cells * 100).round(1)
  end

  def calculate_uniqueness(preview_data)
    return 0 if preview_data.empty?

    uniqueness_scores = []

    if preview_data.first.is_a?(Hash)
      preview_data.first.keys.each do |key|
        values = preview_data.map { |row| row[key] }.compact
        next if values.empty?
        
        unique_ratio = values.uniq.length.to_f / values.length
        uniqueness_scores << unique_ratio * 100
      end
    end

    return 0 if uniqueness_scores.empty?
    (uniqueness_scores.sum / uniqueness_scores.length).round(1)
  end

  def calculate_validity(preview_data)
    return 0 if preview_data.empty?

    validity_scores = []

    if preview_data.first.is_a?(Hash)
      preview_data.first.keys.each do |key|
        values = preview_data.map { |row| row[key] }.compact
        next if values.empty?
        
        valid_count = values.count { |v| is_valid_value?(v) }
        validity_scores << (valid_count.to_f / values.length * 100)
      end
    end

    return 0 if validity_scores.empty?
    (validity_scores.sum / validity_scores.length).round(1)
  end

  def calculate_consistency(preview_data)
    return 0 if preview_data.empty?

    consistency_scores = []

    if preview_data.first.is_a?(Hash)
      preview_data.first.keys.each do |key|
        values = preview_data.map { |row| row[key] }.compact
        next if values.empty?
        
        # Check format consistency
        formats = values.map { |v| detect_value_format(v) }.uniq
        consistency_score = formats.length == 1 ? 100 : (100 - (formats.length - 1) * 20)
        consistency_scores << [consistency_score, 0].max
      end
    end

    return 0 if consistency_scores.empty?
    (consistency_scores.sum / consistency_scores.length).round(1)
  end

  def assess_data_freshness(preview_data)
    date_fields = find_date_fields(preview_data)
    return 50 if date_fields.empty? # Default score if no date fields

    latest_dates = date_fields.map { |field| extract_latest_date(preview_data, field) }.compact
    return 50 if latest_dates.empty?

    days_old = latest_dates.map { |date| (Time.current - date).to_i / 1.day }.min
    
    case days_old
    when 0..7 then 100
    when 8..30 then 80
    when 31..90 then 60
    when 91..365 then 40
    else 20
    end
  end

  # Utility methods
  def extract_headers(structure_analysis)
    structure_analysis[:headers] || 
    structure_analysis[:fields] || 
    structure_analysis.dig(:column_analysis)&.keys || 
    []
  end

  def format_file_size(size_bytes)
    return "0 B" if size_bytes.zero?

    units = %w[B KB MB GB]
    size = size_bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end

  def estimate_processing_complexity
    return "Unknown" unless @file

    file_size = @file.size || 0
    file_extension = File.extname(@file.original_filename || "").downcase

    complexity_score = 0

    # Size factor
    complexity_score += case file_size
                       when 0..1.megabyte then 1
                       when 1.megabyte..10.megabytes then 2
                       when 10.megabytes..50.megabytes then 3
                       else 4
                       end

    # Format factor
    complexity_score += case file_extension
                       when ".csv", ".tsv" then 1
                       when ".xlsx", ".xls" then 2
                       when ".json", ".yaml" then 2
                       when ".xml" then 3
                       else 2
                       end

    case complexity_score
    when 1..3 then "Simple"
    when 4..5 then "Moderate"
    when 6..7 then "Complex"
    else "Advanced"
    end
  end

  def estimate_processing_time(structure_analysis)
    total_rows = structure_analysis[:total_rows] || structure_analysis[:total_items] || 0
    
    # Base time estimate: 1000 rows per second
    base_seconds = [(total_rows / 1000.0).ceil, 1].max
    
    # Add complexity factors
    complexity_multiplier = case estimate_processing_complexity
                           when "Simple" then 1.0
                           when "Moderate" then 1.5
                           when "Complex" then 2.0
                           else 3.0
                           end

    estimated_seconds = (base_seconds * complexity_multiplier).ceil

    if estimated_seconds < 60
      "#{estimated_seconds} seconds"
    elsif estimated_seconds < 3600
      "#{(estimated_seconds / 60.0).ceil} minutes"
    else
      "#{(estimated_seconds / 3600.0).ceil} hours"
    end
  end

  def base_error_response(message)
    {
      success: false,
      error: message,
      file_info: extract_file_info,
      suggestions: [
        "Check file format and structure",
        "Ensure file is not corrupted",
        "Try a smaller sample file first"
      ]
    }
  end

  # Additional helper methods for quality assessment
  def is_valid_value?(value)
    return false if value.blank?
    return false if value.to_s.length > 10000 # Suspiciously long
    return false if value.to_s.match?(/[<>]/) && value.to_s.match?(/<script|<iframe/) # Basic XSS check
    true
  end

  def detect_value_format(value)
    return "null" if value.blank?
    return "integer" if value.to_s.match?(/^\d+$/)
    return "decimal" if value.to_s.match?(/^\d+\.\d+$/)
    return "date" if value.to_s.match?(/^\d{4}-\d{2}-\d{2}/)
    return "email" if value.to_s.match?(/^[^@]+@[^@]+\.[^@]+$/)
    return "phone" if value.to_s.match?(/^\+?[\d\s\-\(\)]+$/)
    "text"
  end

  def find_date_fields(preview_data)
    return [] if preview_data.empty? || !preview_data.first.is_a?(Hash)

    preview_data.first.keys.select do |key|
      sample_values = preview_data.map { |row| row[key] }.compact.first(5)
      sample_values.any? { |v| detect_value_format(v) == "date" }
    end
  end

  def extract_latest_date(preview_data, field)
    dates = preview_data.map { |row| row[field] }.compact.map do |date_str|
      Date.parse(date_str.to_s) rescue nil
    end.compact

    dates.max
  end

  # Business impact calculation helpers
  def determine_primary_business_area(detected_fields)
    return "General Data" if detected_fields.empty?

    category_counts = detected_fields.group_by { |f| f[:category] }.transform_values(&:count)
    primary_category = category_counts.max_by { |_, count| count }&.first

    {
      customer: "Customer Management",
      financial: "Financial Analytics",
      product: "Product Intelligence",
      order: "Sales Operations",
      marketing: "Marketing Analytics",
      temporal: "Time-Series Analysis",
      location: "Geographic Intelligence"
    }[primary_category] || "Business Intelligence"
  end

  def calculate_data_richness(detected_fields)
    return 0.1 if detected_fields.empty?
    
    unique_categories = detected_fields.map { |f| f[:category] }.uniq.length
    total_possible_categories = BUSINESS_FIELD_PATTERNS.keys.length
    
    (unique_categories.to_f / total_possible_categories).round(2)
  end

  def determine_quality_grade(score)
    case score
    when 90..100 then "A"
    when 80..89 then "B"
    when 70..79 then "C"
    when 60..69 then "D"
    else "F"
    end
  end

  def determine_impact_level(score)
    case score
    when 80..100 then "High"
    when 60..79 then "Medium"
    when 40..59 then "Moderate"
    else "Low"
    end
  end

  # Stub methods for comprehensive functionality
  def calculate_detection_confidence(detected_fields)
    return 0 if detected_fields.empty?
    (detected_fields.sum { |f| f[:confidence] } / detected_fields.length * 100).round
  end

  def estimate_business_value(detected_fields)
    value_weights = {
      customer: 0.9, financial: 1.0, product: 0.8, 
      order: 0.9, marketing: 0.7, temporal: 0.6, location: 0.5
    }
    
    detected_fields.sum { |f| value_weights[f[:category]] || 0.3 }.round(1)
  end

  def generate_quick_insights(detected_fields)
    insights = detected_fields.map { |f| f[:insights] }.flatten.uniq.first(3)
    insights.empty? ? ["Data analysis ready", "Business intelligence potential"] : insights
  end

  def calculate_data_density(structure_analysis)
    total_cells = (structure_analysis[:total_rows] || 0) * (structure_analysis[:total_columns] || 0)
    return 0 if total_cells == 0
    
    [total_cells / 1000.0, 1.0].min.round(2)
  end

  def assess_structure_quality(structure_analysis)
    score = 0
    score += 25 if (structure_analysis[:total_columns] || 0) > 2
    score += 25 if (structure_analysis[:total_rows] || 0) > 10
    score += 25 if structure_analysis[:headers]&.any?
    score += 25 if structure_analysis[:column_analysis]&.any?
    
    case score
    when 75..100 then "Excellent"
    when 50..74 then "Good"
    when 25..49 then "Fair"
    else "Poor"
    end
  end

  def basic_quality_assessment
    {
      overall_score: 50,
      grade: "C",
      metrics: { completeness: 50, uniqueness: 50, validity: 50, consistency: 50, freshness: 50 },
      issues: ["Unable to analyze data quality"],
      recommendations: ["Process file to enable quality analysis"],
      impact_assessment: "Quality analysis will be available after processing"
    }
  end

  def identify_quality_issues(metrics, preview_data)
    issues = []
    
    issues << "Low data completeness" if metrics[:completeness] < 80
    issues << "Limited data uniqueness" if metrics[:uniqueness] < 60
    issues << "Data validity concerns" if metrics[:validity] < 90
    issues << "Inconsistent data formats" if metrics[:consistency] < 70
    issues << "Data may be outdated" if metrics[:freshness] < 60
    
    issues.empty? ? ["No significant quality issues detected"] : issues
  end

  def generate_quality_recommendations(metrics)
    recommendations = []
    
    recommendations << "Review and clean missing data" if metrics[:completeness] < 80
    recommendations << "Check for duplicate records" if metrics[:uniqueness] < 60
    recommendations << "Validate data formats and values" if metrics[:validity] < 90
    recommendations << "Standardize data formats" if metrics[:consistency] < 70
    recommendations << "Consider data refresh schedule" if metrics[:freshness] < 60
    
    recommendations.empty? ? ["Data quality is good - ready for analysis"] : recommendations
  end

  def assess_quality_impact(grade)
    impact_messages = {
      "A" => "Excellent data quality - high confidence in insights",
      "B" => "Good data quality - reliable for most analysis",
      "C" => "Fair data quality - some cleanup may improve results",
      "D" => "Poor data quality - cleanup recommended before analysis",
      "F" => "Critical data quality issues - significant cleanup required"
    }
    
    impact_messages[grade] || "Quality assessment pending"
  end

  # Additional stub methods for transformation suggestions
  def suggest_customer_transformations(header, column_info)
    transformations = []
    
    if header.match?(/email/i)
      transformations << {
        type: "extract_domain",
        description: "Extract email domains for customer segmentation",
        confidence: 0.9,
        business_value: "Customer analysis by organization"
      }
    end
    
    if header.match?(/name/i)
      transformations << {
        type: "split_name",
        description: "Split full names into first and last name",
        confidence: 0.8,
        business_value: "Personalized communications"
      }
    end
    
    transformations
  end

  def suggest_financial_transformations(header, column_info)
    transformations = []
    
    if header.to_s.match?(/price|amount|cost|total|value|payment|billing|revenue|profit/i)
      transformations << {
        type: "normalize_currency",
        description: "Standardize currency format for #{header}",
        confidence: 0.9,
        business_value: "Accurate financial calculations"
      }
    end
    
    transformations
  end

  def suggest_temporal_transformations(header, column_info)
    transformations = []
    
    if header.to_s.match?(/date|time|created|updated|when|timestamp|period/i)
      transformations << {
        type: "parse_datetime",
        description: "Parse #{header} for trend analysis",
        confidence: 0.95,
        business_value: "Time-series insights and forecasting"
      }
    end
    
    transformations
  end

  def suggest_location_transformations(header, column_info)
    transformations = []
    
    if header.match?(/address|city|state/i)
      transformations << {
        type: "geocode_location",
        description: "Convert addresses to geographic coordinates",
        confidence: 0.7,
        business_value: "Geographic analysis and mapping"
      }
    end
    
    transformations
  end

  def suggest_quality_transformations(header, column_info)
    []
  end

  def calculate_transformation_impact(transformations)
    return 0 if transformations.empty?
    
    impact_score = transformations.sum { |t| t[:confidence] * 20 }
    "#{impact_score.round}% improvement in data usability"
  end

  # Business outcome prediction stubs
  def generate_analysis_opportunities(detected_fields)
    opportunities = []
    
    categories = detected_fields.map { |f| f[:category] }.uniq
    
    opportunities << "Customer lifecycle analysis" if categories.include?(:customer) && categories.include?(:temporal)
    opportunities << "Revenue trend analysis" if categories.include?(:financial) && categories.include?(:temporal)
    opportunities << "Product performance tracking" if categories.include?(:product) && categories.include?(:financial)
    opportunities << "Geographic sales analysis" if categories.include?(:location) && categories.include?(:financial)
    
    opportunities.empty? ? ["General business intelligence"] : opportunities
  end

  def assess_integration_potential(detected_fields)
    categories = detected_fields.map { |f| f[:category] }.uniq
    
    potential = case categories.length
               when 4..7 then "High - Rich dataset for comprehensive analysis"
               when 2..3 then "Medium - Good for targeted insights"
               when 1 then "Low - Single-domain analysis"
               else "Minimal - Limited analytical scope"
               end
    
    potential
  end

  def suggest_automation_opportunities(detected_fields)
    categories = detected_fields.map { |f| f[:category] }.uniq
    suggestions = []
    
    suggestions << "Automated customer segmentation" if categories.include?(:customer)
    suggestions << "Financial performance alerts" if categories.include?(:financial)
    suggestions << "Inventory monitoring" if categories.include?(:product)
    suggestions << "Marketing campaign tracking" if categories.include?(:marketing)
    
    suggestions.empty? ? ["General data monitoring"] : suggestions
  end

  def identify_cross_reference_opportunities(detected_fields)
    existing_sources = @data_source.organization.data_sources.where.not(id: @data_source.id)
    return [] if existing_sources.empty?
    
    ["Customer data enrichment", "Cross-platform analytics", "Unified reporting"]
  end

  def annotate_business_fields(row)
    return {} unless row.is_a?(Hash)
    
    annotations = {}
    row.each do |key, value|
      business_context = detect_field_business_context(key)
      if business_context[:category]
        annotations[key] = {
          category: business_context[:category],
          icon: business_context[:icon],
          insights: business_context[:insights].first
        }
      end
    end
    
    annotations
  end

  def identify_row_quality_issues(row)
    return [] unless row.is_a?(Hash)
    
    issues = []
    row.each do |key, value|
      issues << "Missing #{key}" if value.blank?
      issues << "Invalid #{key} format" unless is_valid_value?(value)
    end
    
    issues.first(3) # Limit to top 3 issues
  end

  def suggest_row_transformations(row)
    return [] unless row.is_a?(Hash)
    
    suggestions = []
    row.each do |key, value|
      next if value.blank?
      
      if key.to_s.match?(/email/i) && value.to_s.match?(/^[^@]+@[^@]+\.[^@]+$/)
        suggestions << "Extract domain from #{key}"
      end
      
      if key.to_s.match?(/date/i) && value.to_s.match?(/\d{4}-\d{2}-\d{2}/)
        suggestions << "Parse #{key} for time analysis"
      end
    end
    
    suggestions.first(2) # Limit suggestions
  end

  def generate_row_insights(enhanced_samples)
    return {} if enhanced_samples.empty?
    
    total_business_fields = enhanced_samples.sum { |s| s[:business_annotations].keys.length }
    total_quality_issues = enhanced_samples.sum { |s| s[:quality_flags].length }
    
    {
      business_field_coverage: "#{((total_business_fields.to_f / (enhanced_samples.length * enhanced_samples.first[:data].keys.length)) * 100).round}%",
      quality_issue_rate: "#{((total_quality_issues.to_f / enhanced_samples.length) * 100).round}%",
      transformation_opportunities: enhanced_samples.sum { |s| s[:potential_transformations].length }
    }
  end

  def detect_data_patterns(sample_data)
    return {} if sample_data.empty?
    
    patterns = {}
    
    if sample_data.first.is_a?(Hash)
      sample_data.first.keys.each do |key|
        values = sample_data.map { |row| row[key] }.compact
        next if values.empty?
        
        # Detect common patterns
        if values.all? { |v| v.to_s.match?(/^\d+$/) }
          patterns[key] = "Sequential numbers detected"
        elsif values.uniq.length < values.length * 0.5
          patterns[key] = "Limited unique values - potential categories"
        elsif values.all? { |v| v.to_s.length > 50 }
          patterns[key] = "Long text content - potential descriptions"
        end
      end
    end
    
    patterns
  end

  def assess_analytical_potential(detected_fields)
    categories = detected_fields.map { |f| f[:category] }.uniq
    
    score = 0
    score += 0.3 if categories.include?(:customer)
    score += 0.3 if categories.include?(:financial) 
    score += 0.2 if categories.include?(:temporal)
    score += 0.1 if categories.include?(:product)
    score += 0.1 if categories.include?(:location)
    
    score.round(2)
  end

  def estimate_automation_value(detected_fields)
    automation_score = detected_fields.count { |f| [:customer, :financial, :order, :marketing].include?(f[:category]) }
    (automation_score * 0.25).round(2)
  end

  def calculate_integration_value(detected_fields)
    existing_source_count = @data_source.organization.data_sources.count
    integration_multiplier = [existing_source_count * 0.1, 1.0].min
    
    base_value = detected_fields.length * 0.1
    (base_value * (1 + integration_multiplier)).round(2)
  end

  def estimate_time_to_insights(structure_analysis)
    complexity = estimate_processing_complexity
    
    case complexity
    when "Simple" then "5-10 minutes"
    when "Moderate" then "15-30 minutes" 
    when "Complex" then "30-60 minutes"
    else "1-2 hours"
    end
  end

  def predict_business_outcomes(detected_fields)
    categories = detected_fields.map { |f| f[:category] }.uniq
    outcomes = []
    
    outcomes << "Improved customer insights" if categories.include?(:customer)
    outcomes << "Enhanced financial visibility" if categories.include?(:financial)
    outcomes << "Better product performance tracking" if categories.include?(:product)
    outcomes << "Optimized marketing ROI" if categories.include?(:marketing)
    outcomes << "Data-driven decision making" if categories.length >= 3
    
    outcomes.empty? ? ["General business intelligence"] : outcomes
  end

  def estimate_roi_potential(impact_factors)
    total_score = impact_factors.values.sum
    
    case total_score
    when 3.5..5.0 then "High ROI potential (300%+ within 6 months)"
    when 2.5..3.4 then "Good ROI potential (200%+ within 1 year)"
    when 1.5..2.4 then "Moderate ROI potential (100%+ within 1 year)"
    else "Basic ROI potential (50%+ within 1 year)"
    end
  end

  def calculate_total_setup_time(steps)
    time_estimates = steps.map { |step| extract_time_minutes(step[:estimated_time]) }
    total_minutes = time_estimates.sum
    
    if total_minutes < 60
      "#{total_minutes} minutes"
    else
      hours = total_minutes / 60
      remaining_minutes = total_minutes % 60
      "#{hours}h #{remaining_minutes}m"
    end
  end

  def extract_time_minutes(time_string)
    # Extract minutes from strings like "10-15 minutes", "30-60 minutes", "1-2 hours"
    if time_string.include?("hour")
      # Extract first number and convert to minutes
      hours = time_string.match(/(\d+)/)[1].to_i
      hours * 60
    else
      # Extract first number as minutes
      time_string.match(/(\d+)/)[1].to_i
    end
  rescue
    30 # Default fallback
  end
end