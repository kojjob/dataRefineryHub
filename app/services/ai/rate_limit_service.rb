# frozen_string_literal: true

module Ai
  class RateLimitService
    include ActiveModel::Model
    
    # Rate limit configurations by operation type
    RATE_LIMITS = {
      # Natural Language Queries
      natural_language_query: {
        requests_per_minute: 10,
        requests_per_hour: 100,
        requests_per_day: 500,
        cost_per_request: 0.05 # USD
      },
      
      # Presentation Generation
      presentation_generation: {
        requests_per_minute: 2,
        requests_per_hour: 20,
        requests_per_day: 50,
        cost_per_request: 0.25 # USD
      },
      
      # BI Agent Operations
      bi_agent_analysis: {
        requests_per_minute: 5,
        requests_per_hour: 50,
        requests_per_day: 200,
        cost_per_request: 0.10 # USD
      },
      
      # Real-time Analytics
      real_time_analytics: {
        requests_per_minute: 20,
        requests_per_hour: 500,
        requests_per_day: 2000,
        cost_per_request: 0.02 # USD
      },
      
      # Data Integration Analysis
      data_integration_analysis: {
        requests_per_minute: 3,
        requests_per_hour: 30,
        requests_per_day: 100,
        cost_per_request: 0.15 # USD
      },
      
      # General LLM Requests
      llm_request: {
        requests_per_minute: 15,
        requests_per_hour: 200,
        requests_per_day: 1000,
        cost_per_request: 0.03 # USD
      }
    }.freeze
    
    # Organization tier limits
    TIER_MULTIPLIERS = {
      'starter' => 1.0,
      'professional' => 3.0,
      'enterprise' => 10.0,
      'unlimited' => Float::INFINITY
    }.freeze
    
    # Monthly cost limits by tier
    MONTHLY_COST_LIMITS = {
      'starter' => 50.0,      # $50/month
      'professional' => 200.0, # $200/month
      'enterprise' => 1000.0,  # $1000/month
      'unlimited' => Float::INFINITY
    }.freeze
    
    attr_accessor :organization, :operation_type, :user
    
    def initialize(organization:, operation_type:, user: nil)
      @organization = organization
      @operation_type = operation_type.to_sym
      @user = user
      @cache_store = Rails.cache
      
      validate_operation_type!
    end
    
    # Check if request should be rate limited
    def rate_limited?
      return false if bypass_rate_limiting?
      
      # Check various rate limit conditions
      minute_limited? || hour_limited? || day_limited? || cost_limited?
    end
    
    # Get time until rate limit resets
    def retry_after
      limits = [
        minutes_until_reset(:minute),
        minutes_until_reset(:hour),
        minutes_until_reset(:day)
      ].compact
      
      limits.min&.minutes || 1.minute
    end
    
    # Record a successful request
    def record_request
      current_time = Time.current
      
      # Increment counters
      increment_counter(:minute, current_time)
      increment_counter(:hour, current_time)
      increment_counter(:day, current_time)
      
      # Record cost
      record_cost_usage
      
      # Update statistics
      update_usage_statistics
      
      Rails.logger.info "Rate limit request recorded: #{@operation_type} for org #{@organization.id}"
    end
    
    # Get current usage statistics
    def usage_statistics
      {
        current_usage: {
          minute: get_current_count(:minute),
          hour: get_current_count(:hour),
          day: get_current_count(:day)
        },
        limits: {
          minute: effective_limit(:requests_per_minute),
          hour: effective_limit(:requests_per_hour),
          day: effective_limit(:requests_per_day)
        },
        cost_usage: {
          today: get_daily_cost_usage,
          month: get_monthly_cost_usage,
          limit: monthly_cost_limit
        },
        next_reset: {
          minute: next_reset_time(:minute),
          hour: next_reset_time(:hour),
          day: next_reset_time(:day)
        }
      }
    end
    
    # Get organization's total AI usage across all operations
    def organization_usage_summary
      summary = {
        total_requests_today: 0,
        total_cost_today: 0.0,
        total_requests_month: 0,
        total_cost_month: 0.0,
        operations_breakdown: {}
      }
      
      RATE_LIMITS.keys.each do |operation|
        operation_usage = get_operation_usage(operation)
        summary[:total_requests_today] += operation_usage[:requests_today]
        summary[:total_cost_today] += operation_usage[:cost_today]
        summary[:total_requests_month] += operation_usage[:requests_month]
        summary[:total_cost_month] += operation_usage[:cost_month]
        summary[:operations_breakdown][operation] = operation_usage
      end
      
      summary[:tier] = organization_tier
      summary[:monthly_limit] = monthly_cost_limit
      summary[:approaching_limit] = summary[:total_cost_month] > (monthly_cost_limit * 0.8)
      summary[:over_limit] = summary[:total_cost_month] >= monthly_cost_limit
      
      summary
    end
    
    # Check if organization is approaching limits
    def approaching_limits?
      monthly_usage = get_monthly_cost_usage
      monthly_limit = monthly_cost_limit
      
      return false if monthly_limit == Float::INFINITY
      
      (monthly_usage / monthly_limit) > 0.8
    end
    
    # Check if organization has exceeded monthly cost limit
    def exceeded_monthly_limit?
      return false if monthly_cost_limit == Float::INFINITY
      
      get_monthly_cost_usage >= monthly_cost_limit
    end
    
    # Get remaining requests for current period
    def remaining_requests(period = :hour)
      limit = effective_limit("requests_per_#{period}".to_sym)
      current = get_current_count(period)
      
      [limit - current, 0].max
    end
    
    # Estimate cost for operation
    def estimated_cost
      RATE_LIMITS[@operation_type][:cost_per_request]
    end
    
    # Predict when rate limits will reset
    def rate_limit_reset_prediction
      {
        minute: next_reset_time(:minute),
        hour: next_reset_time(:hour),
        day: next_reset_time(:day),
        month: next_reset_time(:month)
      }
    end
    
    private
    
    def validate_operation_type!
      unless RATE_LIMITS.key?(@operation_type)
        raise ArgumentError, "Unknown operation type: #{@operation_type}"
      end
    end
    
    def bypass_rate_limiting?
      # Allow bypassing for certain conditions
      return true if Rails.env.test?
      return true if @organization.unlimited_ai_access?
      return true if system_operation?
      
      false
    end
    
    def system_operation?
      # Check if this is a system-level operation that should bypass limits
      @user.nil? || @user.system_user?
    end
    
    def minute_limited?
      get_current_count(:minute) >= effective_limit(:requests_per_minute)
    end
    
    def hour_limited?
      get_current_count(:hour) >= effective_limit(:requests_per_hour)
    end
    
    def day_limited?
      get_current_count(:day) >= effective_limit(:requests_per_day)
    end
    
    def cost_limited?
      exceeded_monthly_limit?
    end
    
    def effective_limit(limit_key)
      base_limit = RATE_LIMITS[@operation_type][limit_key]
      tier_multiplier = TIER_MULTIPLIERS[organization_tier]
      
      (base_limit * tier_multiplier).to_i
    end
    
    def organization_tier
      @organization.subscription_tier || 'starter'
    end
    
    def monthly_cost_limit
      MONTHLY_COST_LIMITS[organization_tier]
    end
    
    def get_current_count(period)
      cache_key = rate_limit_key(period)
      @cache_store.read(cache_key) || 0
    end
    
    def increment_counter(period, timestamp)
      cache_key = rate_limit_key(period, timestamp)
      ttl = period_ttl(period)
      
      @cache_store.increment(cache_key, 1, expires_in: ttl)
    end
    
    def rate_limit_key(period, timestamp = Time.current)
      time_component = case period
                       when :minute
                         timestamp.strftime('%Y%m%d%H%M')
                       when :hour
                         timestamp.strftime('%Y%m%d%H')
                       when :day
                         timestamp.strftime('%Y%m%d')
                       when :month
                         timestamp.strftime('%Y%m')
                       end
      
      "rate_limit:#{@organization.id}:#{@operation_type}:#{period}:#{time_component}"
    end
    
    def period_ttl(period)
      case period
      when :minute
        1.minute + 10.seconds # Small buffer
      when :hour
        1.hour + 1.minute
      when :day
        1.day + 1.hour
      when :month
        1.month + 1.day
      end
    end
    
    def minutes_until_reset(period)
      current_time = Time.current
      
      case period
      when :minute
        60 - current_time.sec
      when :hour
        ((60 - current_time.min) * 60) - current_time.sec
      when :day
        seconds_until_midnight = (current_time.end_of_day - current_time).to_i
        seconds_until_midnight / 60
      end
    end
    
    def next_reset_time(period)
      current_time = Time.current
      
      case period
      when :minute
        current_time.beginning_of_minute + 1.minute
      when :hour
        current_time.beginning_of_hour + 1.hour
      when :day
        current_time.beginning_of_day + 1.day
      when :month
        current_time.beginning_of_month + 1.month
      end
    end
    
    def record_cost_usage
      cost = RATE_LIMITS[@operation_type][:cost_per_request]
      current_time = Time.current
      
      # Record daily cost
      daily_key = "cost_usage:#{@organization.id}:day:#{current_time.strftime('%Y%m%d')}"
      @cache_store.increment(daily_key, cost, expires_in: 2.days)
      
      # Record monthly cost
      monthly_key = "cost_usage:#{@organization.id}:month:#{current_time.strftime('%Y%m')}"
      @cache_store.increment(monthly_key, cost, expires_in: 2.months)
      
      # Record operation-specific cost
      operation_daily_key = "cost_usage:#{@organization.id}:#{@operation_type}:day:#{current_time.strftime('%Y%m%d')}"
      @cache_store.increment(operation_daily_key, cost, expires_in: 2.days)
      
      operation_monthly_key = "cost_usage:#{@organization.id}:#{@operation_type}:month:#{current_time.strftime('%Y%m')}"
      @cache_store.increment(operation_monthly_key, cost, expires_in: 2.months)
    end
    
    def get_daily_cost_usage
      daily_key = "cost_usage:#{@organization.id}:day:#{Time.current.strftime('%Y%m%d')}"
      @cache_store.read(daily_key) || 0.0
    end
    
    def get_monthly_cost_usage
      monthly_key = "cost_usage:#{@organization.id}:month:#{Time.current.strftime('%Y%m')}"
      @cache_store.read(monthly_key) || 0.0
    end
    
    def get_operation_usage(operation)
      current_time = Time.current
      
      {
        requests_today: get_operation_count(operation, :day),
        cost_today: get_operation_cost(operation, :day),
        requests_month: get_operation_count(operation, :month),
        cost_month: get_operation_cost(operation, :month)
      }
    end
    
    def get_operation_count(operation, period)
      time_component = case period
                       when :day
                         Time.current.strftime('%Y%m%d')
                       when :month
                         Time.current.strftime('%Y%m')
                       end
      
      key = "rate_limit:#{@organization.id}:#{operation}:#{period}:#{time_component}"
      @cache_store.read(key) || 0
    end
    
    def get_operation_cost(operation, period)
      time_component = case period
                       when :day
                         Time.current.strftime('%Y%m%d')
                       when :month
                         Time.current.strftime('%Y%m')
                       end
      
      key = "cost_usage:#{@organization.id}:#{operation}:#{period}:#{time_component}"
      @cache_store.read(key) || 0.0
    end
    
    def update_usage_statistics
      # Update aggregated statistics for monitoring
      stats_key = "ai_usage_stats:#{@organization.id}:#{Date.current}"
      
      current_stats = @cache_store.read(stats_key) || {
        total_requests: 0,
        total_cost: 0.0,
        operations: Hash.new(0)
      }
      
      current_stats[:total_requests] += 1
      current_stats[:total_cost] += estimated_cost
      current_stats[:operations][@operation_type] += 1
      current_stats[:last_updated] = Time.current.iso8601
      
      @cache_store.write(stats_key, current_stats, expires_in: 7.days)
    end
  end
end