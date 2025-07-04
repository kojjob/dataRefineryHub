# AI Insights Service
# Handles AI-generated insights and recommendations for presentations and data

module Ai
  class InsightsService
    include Singleton
    
    attr_reader :organization, :ai_client
    
    def initialize(organization:)
      @organization = organization
      @ai_client = initialize_ai_client
    end
    
    # Fetch latest AI insights for the organization
    def fetch_latest_insights(limit: 5)
      insights = organization.ai_insights
                            .recent
                            .includes(:data_source, :presentation, :user)
                            .order(created_at: :desc)
                            .limit(limit)
      
      insights.map do |insight|
        {
          id: insight.id,
          type: insight.insight_type,
          title: insight.title,
          description: insight.description,
          confidence: insight.confidence_score,
          impact: insight.impact_level,
          source: insight.data_source&.name || insight.presentation&.title || 'System',
          created_at: insight.created_at,
          actionable: insight.actionable?,
          metadata: insight.metadata
        }
      end
    rescue => e
      Rails.logger.error "Failed to fetch AI insights: #{e.message}"
      []
    end
    
    # Generate insights for a specific presentation
    def generate_presentation_insights(presentation_id)
      presentation = organization.presentations.find_by(id: presentation_id)
      return [] unless presentation
      
      insights = []
      
      # Analyze presentation performance
      performance_insight = analyze_presentation_performance(presentation)
      insights << performance_insight if performance_insight
      
      # Analyze audience engagement
      engagement_insight = analyze_audience_engagement(presentation)
      insights << engagement_insight if engagement_insight
      
      # Analyze content effectiveness
      content_insight = analyze_content_effectiveness(presentation)
      insights << content_insight if content_insight
      
      # Save insights to database
      insights.each { |insight| save_insight(insight, presentation) }
      
      insights
    rescue => e
      Rails.logger.error "Failed to generate presentation insights for #{presentation_id}: #{e.message}"
      []
    end
    
    # Generate data insights for organization
    def generate_data_insights
      insights = []
      
      organization.data_sources.active.each do |data_source|
        # Analyze data trends
        trend_insight = analyze_data_trends(data_source)
        insights << trend_insight if trend_insight
        
        # Analyze data quality
        quality_insight = analyze_data_quality(data_source)
        insights << quality_insight if quality_insight
        
        # Analyze data usage patterns
        usage_insight = analyze_data_usage(data_source)
        insights << usage_insight if usage_insight
      end
      
      # Save insights to database
      insights.each { |insight| save_insight(insight) }
      
      insights
    rescue => e
      Rails.logger.error "Failed to generate data insights: #{e.message}"
      []
    end
    
    # Generate AI recommendations
    def generate_recommendations(context_type, context_id)
      case context_type
      when 'presentation'
        generate_presentation_recommendations(context_id)
      when 'data_source'
        generate_data_source_recommendations(context_id)
      when 'organization'
        generate_organization_recommendations
      else
        []
      end
    rescue => e
      Rails.logger.error "Failed to generate recommendations for #{context_type}:#{context_id}: #{e.message}"
      []
    end
    
    # Analyze presentation content and suggest improvements
    def analyze_presentation_content(presentation_id)
      presentation = organization.presentations.find_by(id: presentation_id)
      return nil unless presentation
      
      content_analysis = {
        readability_score: calculate_readability_score(presentation),
        visual_balance: analyze_visual_balance(presentation),
        narrative_flow: analyze_narrative_flow(presentation),
        data_density: calculate_data_density(presentation),
        accessibility_score: calculate_accessibility_score(presentation)
      }
      
      # Generate AI-powered suggestions
      suggestions = generate_content_suggestions(content_analysis, presentation)
      
      {
        analysis: content_analysis,
        suggestions: suggestions,
        overall_score: calculate_overall_content_score(content_analysis)
      }
    rescue => e
      Rails.logger.error "Failed to analyze presentation content for #{presentation_id}: #{e.message}"
      nil
    end
    
    # Predict presentation performance
    def predict_presentation_performance(presentation_id)
      presentation = organization.presentations.find_by(id: presentation_id)
      return nil unless presentation
      
      # Gather features for prediction
      features = extract_presentation_features(presentation)
      
      # Use AI model to predict performance metrics
      prediction = ai_client.predict_performance(features)
      
      {
        predicted_views: prediction[:views],
        predicted_engagement: prediction[:engagement],
        predicted_completion_rate: prediction[:completion_rate],
        confidence_interval: prediction[:confidence],
        factors: prediction[:key_factors]
      }
    rescue => e
      Rails.logger.error "Failed to predict presentation performance for #{presentation_id}: #{e.message}"
      nil
    end
    
    private
    
    def initialize_ai_client
      # Initialize AI client based on configuration
      provider = PresentationConfig.get('ai.default_provider', 'openai')
      
      case provider
      when 'openai'
        OpenAI::Client.new(
          access_token: ENV['OPENAI_API_KEY'],
          request_timeout: PresentationConfig.get('ai.request_timeout', 30)
        )
      when 'anthropic'
        # Initialize Anthropic client
        nil # Placeholder
      else
        Rails.logger.warn "Unknown AI provider: #{provider}"
        nil
      end
    rescue => e
      Rails.logger.error "Failed to initialize AI client: #{e.message}"
      nil
    end
    
    # Presentation analysis methods
    def analyze_presentation_performance(presentation)
      performance_logs = presentation.performance_logs.recent
      return nil if performance_logs.empty?
      
      avg_load_time = performance_logs.average(:load_time)
      error_rate = performance_logs.where(status: 'error').count.to_f / performance_logs.count
      
      if avg_load_time > PresentationConfig.get('performance.load_time_threshold', 3.0)
        {
          type: 'performance',
          title: 'Performance Optimization Opportunity',
          description: "Presentation load time (#{avg_load_time.round(2)}s) exceeds recommended threshold. Consider optimizing images and reducing data complexity.",
          confidence_score: 0.85,
          impact_level: 'medium',
          actionable: true,
          metadata: {
            current_load_time: avg_load_time,
            threshold: PresentationConfig.get('performance.load_time_threshold', 3.0),
            error_rate: error_rate
          }
        }
      end
    end
    
    def analyze_audience_engagement(presentation)
      views = presentation.views.recent
      return nil if views.empty?
      
      avg_duration = views.average(:duration) || 0
      completion_rate = views.where(completed: true).count.to_f / views.count
      
      if completion_rate < PresentationConfig.get('analytics.completion_rate_threshold', 0.7)
        {
          type: 'engagement',
          title: 'Low Audience Engagement Detected',
          description: "Completion rate (#{(completion_rate * 100).round(1)}%) is below optimal levels. Consider adding interactive elements or reducing content length.",
          confidence_score: 0.78,
          impact_level: 'high',
          actionable: true,
          metadata: {
            completion_rate: completion_rate,
            avg_duration: avg_duration,
            total_views: views.count
          }
        }
      end
    end
    
    def analyze_content_effectiveness(presentation)
      interactions = presentation.interactions.recent
      feedback = presentation.feedback.recent
      
      return nil if interactions.empty? && feedback.empty?
      
      interaction_rate = interactions.count.to_f / presentation.views.recent.count
      avg_rating = feedback.average(:rating) || 0
      
      if avg_rating < PresentationConfig.get('analytics.rating_threshold', 4.0)
        {
          type: 'content',
          title: 'Content Improvement Opportunity',
          description: "Average rating (#{avg_rating.round(1)}/5) suggests content could be enhanced. Review feedback for specific improvement areas.",
          confidence_score: 0.72,
          impact_level: 'medium',
          actionable: true,
          metadata: {
            avg_rating: avg_rating,
            interaction_rate: interaction_rate,
            feedback_count: feedback.count
          }
        }
      end
    end
    
    # Data analysis methods
    def analyze_data_trends(data_source)
      recent_data = data_source.data_points.recent
      return nil if recent_data.count < 10
      
      # Simple trend analysis
      values = recent_data.order(:created_at).pluck(:value)
      trend = calculate_trend(values)
      
      if trend.abs > PresentationConfig.get('analytics.trend_threshold', 0.1)
        direction = trend > 0 ? 'increasing' : 'decreasing'
        {
          type: 'trend',
          title: "Significant Trend Detected in #{data_source.name}",
          description: "Data shows a #{direction} trend (#{(trend * 100).round(1)}% change). This may indicate important business changes.",
          confidence_score: 0.80,
          impact_level: 'medium',
          actionable: true,
          metadata: {
            trend_percentage: trend * 100,
            data_points: values.count,
            direction: direction
          }
        }
      end
    end
    
    def analyze_data_quality(data_source)
      quality_score = data_source.latest_quality_score
      return nil unless quality_score
      
      threshold = PresentationConfig.get('monitoring.quality_threshold', 0.8)
      
      if quality_score < threshold
        {
          type: 'quality',
          title: "Data Quality Issue in #{data_source.name}",
          description: "Quality score (#{(quality_score * 100).round(1)}%) is below acceptable threshold. Review data validation rules and source reliability.",
          confidence_score: 0.90,
          impact_level: 'high',
          actionable: true,
          metadata: {
            quality_score: quality_score,
            threshold: threshold,
            issues: data_source.quality_issues
          }
        }
      end
    end
    
    def analyze_data_usage(data_source)
      usage_stats = data_source.usage_statistics.recent
      return nil if usage_stats.empty?
      
      avg_queries = usage_stats.average(:query_count) || 0
      
      if avg_queries < PresentationConfig.get('analytics.usage_threshold', 10)
        {
          type: 'usage',
          title: "Low Data Source Utilization",
          description: "#{data_source.name} has low usage (#{avg_queries.round} queries/day). Consider promoting or reviewing relevance.",
          confidence_score: 0.65,
          impact_level: 'low',
          actionable: true,
          metadata: {
            avg_queries: avg_queries,
            threshold: PresentationConfig.get('analytics.usage_threshold', 10)
          }
        }
      end
    end
    
    # Recommendation methods
    def generate_presentation_recommendations(presentation_id)
      presentation = organization.presentations.find_by(id: presentation_id)
      return [] unless presentation
      
      recommendations = []
      
      # Performance recommendations
      if presentation.average_load_time > 3.0
        recommendations << {
          type: 'performance',
          priority: 'high',
          title: 'Optimize Loading Performance',
          description: 'Reduce image sizes and optimize data queries to improve load times',
          estimated_impact: 'Reduce load time by 40-60%'
        }
      end
      
      # Engagement recommendations
      completion_rate = presentation.completion_rate
      if completion_rate < 0.7
        recommendations << {
          type: 'engagement',
          priority: 'medium',
          title: 'Improve Content Engagement',
          description: 'Add interactive elements or break content into smaller sections',
          estimated_impact: 'Increase completion rate by 20-30%'
        }
      end
      
      recommendations
    end
    
    def generate_data_source_recommendations(data_source_id)
      data_source = organization.data_sources.find_by(id: data_source_id)
      return [] unless data_source
      
      recommendations = []
      
      # Quality recommendations
      if data_source.latest_quality_score < 0.8
        recommendations << {
          type: 'quality',
          priority: 'high',
          title: 'Improve Data Quality',
          description: 'Implement additional validation rules and data cleansing processes',
          estimated_impact: 'Increase data reliability by 25-40%'
        }
      end
      
      recommendations
    end
    
    def generate_organization_recommendations
      recommendations = []
      
      # Overall performance recommendations
      avg_engagement = organization.presentations.average(:engagement_score) || 0
      if avg_engagement < 70
        recommendations << {
          type: 'strategy',
          priority: 'medium',
          title: 'Enhance Overall Engagement Strategy',
          description: 'Develop organization-wide guidelines for creating engaging presentations',
          estimated_impact: 'Improve average engagement by 15-25%'
        }
      end
      
      recommendations
    end
    
    # Helper methods
    def save_insight(insight_data, context = nil)
      insight = organization.ai_insights.build(
        insight_type: insight_data[:type],
        title: insight_data[:title],
        description: insight_data[:description],
        confidence_score: insight_data[:confidence_score],
        impact_level: insight_data[:impact_level],
        actionable: insight_data[:actionable],
        metadata: insight_data[:metadata]
      )
      
      if context.is_a?(Presentation)
        insight.presentation = context
      elsif context.is_a?(DataSource)
        insight.data_source = context
      end
      
      insight.save
    rescue => e
      Rails.logger.error "Failed to save insight: #{e.message}"
    end
    
    def calculate_trend(values)
      return 0.0 if values.length < 2
      
      n = values.length
      sum_x = (0...n).sum
      sum_y = values.sum
      sum_xy = values.each_with_index.sum { |y, x| x * y }
      sum_x2 = (0...n).sum { |x| x * x }
      
      slope = (n * sum_xy - sum_x * sum_y).to_f / (n * sum_x2 - sum_x * sum_x)
      
      # Normalize by the average value to get percentage change
      avg_value = sum_y.to_f / n
      return 0.0 if avg_value.zero?
      
      slope / avg_value
    end
    
    def calculate_readability_score(presentation)
      # Simplified readability calculation
      # In a real implementation, this would analyze text complexity
      content_length = presentation.content&.length || 0
      
      case content_length
      when 0..500
        0.9
      when 501..1500
        0.8
      when 1501..3000
        0.7
      else
        0.6
      end
    end
    
    def analyze_visual_balance(presentation)
      # Simplified visual balance analysis
      # In a real implementation, this would analyze layout and visual elements
      slide_count = presentation.slides&.count || 0
      
      slide_count > 0 ? [0.8, 1.0].min : 0.5
    end
    
    def analyze_narrative_flow(presentation)
      # Simplified narrative flow analysis
      # In a real implementation, this would analyze content structure
      has_intro = presentation.content&.include?('introduction') || false
      has_conclusion = presentation.content&.include?('conclusion') || false
      
      score = 0.5
      score += 0.2 if has_intro
      score += 0.2 if has_conclusion
      score
    end
    
    def calculate_data_density(presentation)
      # Simplified data density calculation
      chart_count = presentation.charts&.count || 0
      slide_count = presentation.slides&.count || 1
      
      density = chart_count.to_f / slide_count
      [density, 1.0].min
    end
    
    def calculate_accessibility_score(presentation)
      # Simplified accessibility score
      # In a real implementation, this would check alt text, color contrast, etc.
      0.75 # Default score
    end
    
    def generate_content_suggestions(analysis, presentation)
      suggestions = []
      
      if analysis[:readability_score] < 0.7
        suggestions << "Consider simplifying complex sentences and technical jargon"
      end
      
      if analysis[:visual_balance] < 0.7
        suggestions << "Improve visual balance by distributing content more evenly across slides"
      end
      
      if analysis[:accessibility_score] < 0.8
        suggestions << "Add alt text to images and ensure sufficient color contrast"
      end
      
      suggestions
    end
    
    def calculate_overall_content_score(analysis)
      weights = {
        readability_score: 0.25,
        visual_balance: 0.25,
        narrative_flow: 0.20,
        data_density: 0.15,
        accessibility_score: 0.15
      }
      
      weighted_score = analysis.sum { |key, value| weights[key] * value }
      (weighted_score * 100).round(1)
    end
    
    def extract_presentation_features(presentation)
      {
        slide_count: presentation.slides&.count || 0,
        chart_count: presentation.charts&.count || 0,
        content_length: presentation.content&.length || 0,
        has_interactive_elements: presentation.interactive_elements.present?,
        creation_date: presentation.created_at,
        last_updated: presentation.updated_at,
        creator_experience: presentation.user&.presentations&.count || 0
      }
    end
  end
end