# frozen_string_literal: true

module Infrastructure
  module ActiveRecord
    # ActiveRecord model for domain events persistence
    class DomainEventRecord < ApplicationRecord
      self.table_name = 'domain_events'
      
      # Associations
      belongs_to :aggregate, polymorphic: true, optional: true
      
      # Validations
      validates :event_id, presence: true, uniqueness: true
      validates :event_type, presence: true
      validates :aggregate_id, presence: true
      validates :aggregate_type, presence: true
      validates :occurred_at, presence: true
      
      # Scopes
      scope :for_aggregate, ->(aggregate_id, aggregate_type) {
        where(aggregate_id: aggregate_id, aggregate_type: aggregate_type)
      }
      scope :by_type, ->(event_type) { where(event_type: event_type) }
      scope :since, ->(timestamp) { where('occurred_at >= ?', timestamp) }
      scope :until, ->(timestamp) { where('occurred_at <= ?', timestamp) }
      
      # Convert to domain event
      def to_domain_event
        event_class = "Domain::PipelineManagement::Events::#{event_type.camelize}".constantize
        
        event_class.new(
          event_id: event_id,
          aggregate_id: aggregate_id,
          aggregate_type: aggregate_type,
          occurred_at: occurred_at,
          user_id: metadata&.dig('user_id'),
          correlation_id: metadata&.dig('correlation_id'),
          **data.symbolize_keys
        )
      rescue NameError => e
        Rails.logger.error "Unknown event type: #{event_type}"
        raise e
      end
    end
  end
end
