# frozen_string_literal: true

module Infrastructure
  module ActiveRecord
    # ActiveRecord model for Pipeline persistence
    class PipelineRecord < ApplicationRecord
      self.table_name = "pipelines"

      # Associations
      belongs_to :organization
      belongs_to :created_by, class_name: "User"
      has_many :domain_events,
               -> { order(:occurred_at) },
               as: :aggregate,
               class_name: "Infrastructure::ActiveRecord::DomainEventRecord",
               dependent: :destroy

      # We keep the existing pipeline_executions association for compatibility
      has_many :pipeline_executions, foreign_key: :pipeline_id, dependent: :destroy

      # Validations
      validates :name, presence: true, uniqueness: { scope: :organization_id }
      validates :status, presence: true

      # Scopes
      scope :active, -> { where(status: "active") }
      scope :scheduled, -> { where.not(schedule_config: nil) }
      scope :operational, -> { where(status: %w[active paused]) }

      # Serialize JSON fields
      serialize :source_config, JSON
      serialize :destination_config, JSON
      serialize :transformation_rules, JSON
      serialize :schedule_config, JSON
      serialize :retry_policy, JSON
      serialize :tags, JSON

      # Convert to domain aggregate
      def to_aggregate
        # Rebuild aggregate from events
        events = domain_events.map(&:to_domain_event)
        Domain::PipelineManagement::Aggregates::PipelineAggregate.build_from_events(events)
      end

      # Update from aggregate
      def update_from_aggregate(aggregate)
        self.name = aggregate.name
        self.description = aggregate.description
        self.status = aggregate.status.value
        self.source_config = aggregate.source_configuration
        self.destination_config = aggregate.destination_configuration
        self.transformation_rules = aggregate.transformation_rules.map(&:to_h)
        self.schedule_config = aggregate.schedule&.to_h
        self.retry_policy = aggregate.retry_policy&.to_h
        self.tags = aggregate.tags
        self.created_by_id = aggregate.created_by_id
      end
    end
  end
end
