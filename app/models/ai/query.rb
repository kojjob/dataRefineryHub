# frozen_string_literal: true

module Ai
  class Query < ApplicationRecord
    self.table_name = 'ai_queries'
    
    belongs_to :organization
    belongs_to :user
    
    validates :query, presence: true
    
    scope :recent, -> { order(created_at: :desc) }
    scope :by_intent, ->(intent) { where(intent: intent) }
    scope :successful, -> { where.not(response: nil) }
    
    # Enum for tracking query intents
    enum :intent, {
      general: 0,
      revenue_analysis: 1,
      customer_analysis: 2,
      performance_analysis: 3,
      anomaly_detection: 4,
      forecast: 5,
      action_request: 6
    }, prefix: true
    
    # Encrypt sensitive context data
    encrypts :context if Rails.application.config.respond_to?(:active_record_encryption)
    
    def successful?
      response.present?
    end
    
    def execution_time
      return nil unless response.present? && created_at.present?
      (updated_at - created_at).round(2)
    end
    
    def extracted_metrics
      entities&.dig('metrics') || []
    end
    
    def time_range
      if entities&.dig('time_range').present?
        start_time = Time.parse(entities['time_range']['start'])
        end_time = Time.parse(entities['time_range']['end'])
        start_time..end_time
      end
    rescue
      nil
    end
    
    # Analytics methods
    def self.popular_queries(organization, limit = 10)
      where(organization: organization)
        .group(:query)
        .order('count_all DESC')
        .limit(limit)
        .count
    end
    
    def self.intent_distribution(organization)
      where(organization: organization)
        .group(:intent)
        .count
        .transform_keys { |k| k&.humanize || 'Unknown' }
    end
    
    def self.average_execution_time(organization)
      where(organization: organization)
        .where.not(response: nil)
        .average('EXTRACT(EPOCH FROM (updated_at - created_at))')
        &.round(2)
    end
    
    def self.queries_by_hour(organization, days_back = 7)
      where(organization: organization)
        .where('created_at > ?', days_back.days.ago)
        .group_by_hour(:created_at)
        .count
    end
    
    # Context helpers
    def add_context(key, value)
      self.context ||= {}
      self.context[key] = value
      save if persisted?
    end
    
    def get_context(key)
      context&.dig(key.to_s)
    end
    
    # Response helpers
    def has_visualizations?
      response_data&.dig('visualizations')&.any?
    end
    
    def has_actions?
      response_data&.dig('actions')&.any?
    end
    
    def response_data
      JSON.parse(response) if response.present?
    rescue
      nil
    end
    
    # Conversation threading
    def previous_query
      self.class.where(organization: organization, user: user)
                .where('created_at < ?', created_at)
                .order(created_at: :desc)
                .first
    end
    
    def conversation_thread
      # Get last 5 queries in conversation
      self.class.where(organization: organization, user: user)
                .where('created_at >= ?', 30.minutes.ago)
                .order(created_at: :asc)
    end
    
    # Learning helpers
    def mark_as_helpful
      add_context('helpful', true)
      add_context('feedback_at', Time.current)
    end
    
    def mark_as_not_helpful(reason = nil)
      add_context('helpful', false)
      add_context('feedback_reason', reason) if reason
      add_context('feedback_at', Time.current)
    end
    
    def feedback_provided?
      get_context('helpful') != nil
    end
  end
end