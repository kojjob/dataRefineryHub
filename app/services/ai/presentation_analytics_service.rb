# AI Presentation Analytics Service
# Handles data fetching and analytics for interactive presentations

module Ai
  class PresentationAnalyticsService
    include Singleton
    
    attr_reader :organization
    
    def initialize(organization:)
      @organization = organization
    end
    
    # View count analytics
    def get_view_count(presentation_id, time_range)
      # Query actual presentation views from database
      presentation = find_presentation(presentation_id)
      return 0 unless presentation
      
      presentation.views
                  .where(created_at: time_range)
                  .count
    rescue => e
      Rails.logger.error "Failed to get view count for presentation #{presentation_id}: #{e.message}"
      0
    end
    
    # Engagement metrics
    def get_engagement_data(presentation_id, time_range)
      presentation = find_presentation(presentation_id)
      return default_engagement_data unless presentation
      
      views = presentation.views.where(created_at: time_range)
      interactions = presentation.interactions.where(created_at: time_range)
      
      {
        avg_time: calculate_average_view_time(views),
        interactions: interactions.count,
        bounce_rate: calculate_bounce_rate(views),
        completion_rate: calculate_completion_rate(views)
      }
    rescue => e
      Rails.logger.error "Failed to get engagement data for presentation #{presentation_id}: #{e.message}"
      default_engagement_data
    end
    
    # Audience feedback
    def get_feedback_data(presentation_id, time_range)
      presentation = find_presentation(presentation_id)
      return default_feedback_data unless presentation
      
      feedback = presentation.feedback.where(created_at: time_range)
      
      {
        rating: calculate_average_rating(feedback),
        comments: feedback.where.not(comment: [nil, '']).count,
        total_responses: feedback.count
      }
    rescue => e
      Rails.logger.error "Failed to get feedback data for presentation #{presentation_id}: #{e.message}"
      default_feedback_data
    end
    
    # Performance metrics
    def get_performance_data(presentation_id, time_range)
      presentation = find_presentation(presentation_id)
      return default_performance_data unless presentation
      
      performance_logs = presentation.performance_logs.where(created_at: time_range)
      
      {
        load_time: calculate_average_load_time(performance_logs),
        error_rate: calculate_error_rate(performance_logs),
        uptime: calculate_uptime(performance_logs)
      }
    rescue => e
      Rails.logger.error "Failed to get performance data for presentation #{presentation_id}: #{e.message}"
      default_performance_data
    end
    
    # Conversion metrics
    def get_conversion_data(presentation_id, time_range)
      presentation = find_presentation(presentation_id)
      return default_conversion_data unless presentation
      
      conversions = presentation.conversions.where(created_at: time_range)
      total_views = get_view_count(presentation_id, time_range)
      
      {
        conversions: conversions.count,
        rate: total_views > 0 ? (conversions.count.to_f / total_views * 100).round(2) : 0.0,
        revenue: conversions.sum(:value) || 0
      }
    rescue => e
      Rails.logger.error "Failed to get conversion data for presentation #{presentation_id}: #{e.message}"
      default_conversion_data
    end
    
    # Geographic data
    def get_geographic_data(presentation_id, time_range)
      presentation = find_presentation(presentation_id)
      return default_geographic_data unless presentation
      
      views = presentation.views.where(created_at: time_range)
      countries = views.group(:country).count
      
      {
        countries: countries.keys.length,
        top_country: countries.max_by { |_, count| count }&.first || 'Unknown',
        distribution: countries
      }
    rescue => e
      Rails.logger.error "Failed to get geographic data for presentation #{presentation_id}: #{e.message}"
      default_geographic_data
    end
    
    # Chart data methods
    def get_revenue_chart_data(time_range)
      # Fetch revenue data from organization's data sources
      data_points = organization.revenue_data
                               .where(date: time_range)
                               .group_by_day(:date)
                               .sum(:amount)
      
      {
        labels: data_points.keys.map { |date| date.strftime('%m/%d') },
        data: data_points.values
      }
    rescue => e
      Rails.logger.error "Failed to get revenue chart data: #{e.message}"
      { labels: [], data: [] }
    end
    
    def get_customer_chart_data(time_range)
      # Fetch customer data from organization's data sources
      customer_data = organization.customer_segments
                                 .where(updated_at: time_range)
                                 .group(:segment_type)
                                 .count
      
      {
        labels: customer_data.keys,
        data: customer_data.values
      }
    rescue => e
      Rails.logger.error "Failed to get customer chart data: #{e.message}"
      { labels: [], data: [] }
    end
    
    # AI insights
    def get_latest_insights
      # Fetch AI-generated insights from the organization's analytics
      organization.ai_insights
                  .recent
                  .limit(5)
                  .order(created_at: :desc)
    rescue => e
      Rails.logger.error "Failed to get AI insights: #{e.message}"
      []
    end
    
    # Engagement score calculation
    def calculate_engagement_score(presentation_id)
      engagement_data = get_engagement_data(presentation_id, 30.days.ago..Time.current)
      
      # Calculate weighted engagement score
      time_weight = normalize_score(engagement_data[:avg_time], 0, 600) * 0.4
      interaction_weight = normalize_score(engagement_data[:interactions], 0, 100) * 0.3
      completion_weight = engagement_data[:completion_rate] * 0.3
      
      ((time_weight + interaction_weight + completion_weight) * 100).round(1)
    rescue => e
      Rails.logger.error "Failed to calculate engagement score for presentation #{presentation_id}: #{e.message}"
      0.0
    end
    
    private
    
    def find_presentation(presentation_id)
      organization.presentations.find_by(id: presentation_id)
    end
    
    def calculate_average_view_time(views)
      return 0 if views.empty?
      
      total_time = views.where.not(duration: nil).sum(:duration)
      view_count = views.where.not(duration: nil).count
      
      view_count > 0 ? (total_time / view_count).round : 0
    end
    
    def calculate_bounce_rate(views)
      return 0.0 if views.empty?
      
      bounced_views = views.where('duration < ?', 30).count
      (bounced_views.to_f / views.count * 100).round(2)
    end
    
    def calculate_completion_rate(views)
      return 0.0 if views.empty?
      
      completed_views = views.where(completed: true).count
      (completed_views.to_f / views.count).round(2)
    end
    
    def calculate_average_rating(feedback)
      return 0.0 if feedback.empty?
      
      ratings = feedback.where.not(rating: nil)
      return 0.0 if ratings.empty?
      
      (ratings.average(:rating) || 0.0).round(1)
    end
    
    def calculate_average_load_time(performance_logs)
      return 0.0 if performance_logs.empty?
      
      (performance_logs.average(:load_time) || 0.0).round(2)
    end
    
    def calculate_error_rate(performance_logs)
      return 0.0 if performance_logs.empty?
      
      error_count = performance_logs.where(status: 'error').count
      (error_count.to_f / performance_logs.count * 100).round(2)
    end
    
    def calculate_uptime(performance_logs)
      return 100.0 if performance_logs.empty?
      
      success_count = performance_logs.where(status: 'success').count
      (success_count.to_f / performance_logs.count * 100).round(2)
    end
    
    def normalize_score(value, min_val, max_val)
      return 0.0 if max_val == min_val
      
      normalized = (value.to_f - min_val) / (max_val - min_val)
      [[normalized, 0.0].max, 1.0].min
    end
    
    # Default data methods for fallback
    def default_engagement_data
      {
        avg_time: 0,
        interactions: 0,
        bounce_rate: 0.0,
        completion_rate: 0.0
      }
    end
    
    def default_feedback_data
      {
        rating: 0.0,
        comments: 0,
        total_responses: 0
      }
    end
    
    def default_performance_data
      {
        load_time: 0.0,
        error_rate: 0.0,
        uptime: 100.0
      }
    end
    
    def default_conversion_data
      {
        conversions: 0,
        rate: 0.0,
        revenue: 0
      }
    end
    
    def default_geographic_data
      {
        countries: 0,
        top_country: 'Unknown',
        distribution: {}
      }
    end
  end
end