# frozen_string_literal: true

module Infrastructure
  module Persistence
    module Repositories
      # ActiveRecord implementation of PipelineRepository
      class ActiveRecordPipelineRepository < ::Domain::PipelineManagement::Repositories::PipelineRepository
        def find(id)
          record = Infrastructure::ActiveRecord::PipelineRecord
                    .includes(:domain_events)
                    .find_by(id: id)

          return nil unless record

          record.to_aggregate
        rescue StandardError => e
          Rails.logger.error "Error finding pipeline #{id}: #{e.message}"
          raise
        end

        def find_by_organization(organization_id)
          records = Infrastructure::ActiveRecord::PipelineRecord
                     .includes(:domain_events)
                     .where(organization_id: organization_id)
                     .order(created_at: :desc)

          records.map(&:to_aggregate)
        end

        def find_by_name(organization_id, name)
          record = Infrastructure::ActiveRecord::PipelineRecord
                    .includes(:domain_events)
                    .find_by(organization_id: organization_id, name: name)

          return nil unless record

          record.to_aggregate
        end

        def save(aggregate)
          ApplicationRecord.transaction do
            # Find or create the record
            record = Infrastructure::ActiveRecord::PipelineRecord
                      .find_or_initialize_by(id: aggregate.id)

            # Update record from aggregate state
            record.update_from_aggregate(aggregate)
            record.organization_id = aggregate.organization_id

            # Save the record
            record.save!

            # Save new domain events
            aggregate.domain_events.each do |event|
              save_domain_event(event, record)
            end

            # Clear events from aggregate after saving
            aggregate.clear_events

            # Publish events to subscribers
            publish_events(aggregate.domain_events)

            aggregate
          end
        rescue StandardError => e
          Rails.logger.error "Error saving pipeline: #{e.message}"
          raise
        end

        def delete(id)
          record = Infrastructure::ActiveRecord::PipelineRecord.find_by(id: id)
          return false unless record

          record.destroy
          true
        end

        def exists?(id)
          Infrastructure::ActiveRecord::PipelineRecord.exists?(id: id)
        end

        def count_by_organization(organization_id)
          Infrastructure::ActiveRecord::PipelineRecord
            .where(organization_id: organization_id)
            .count
        end

        def find_scheduled_pipelines(as_of: Time.current)
          records = Infrastructure::ActiveRecord::PipelineRecord
                     .includes(:domain_events)
                     .scheduled
                     .operational

          aggregates = records.map(&:to_aggregate)

          # Filter by next run time
          aggregates.select do |pipeline|
            next_run = pipeline.next_scheduled_run
            next_run && next_run <= as_of
          end
        end

        def find_active_pipelines(organization_id: nil)
          scope = Infrastructure::ActiveRecord::PipelineRecord
                   .includes(:domain_events)
                   .active

          scope = scope.where(organization_id: organization_id) if organization_id

          scope.map(&:to_aggregate)
        end

        private

        def save_domain_event(event, record)
          Infrastructure::ActiveRecord::DomainEventRecord.create!(
            event_id: event.event_id,
            event_type: event.event_type,
            aggregate_id: record.id,
            aggregate_type: "Infrastructure::ActiveRecord::PipelineRecord",
            data: event.to_h.except(:event_id, :aggregate_id, :aggregate_type, :occurred_at, :metadata),
            metadata: event.to_h.slice(:user_id, :correlation_id),
            occurred_at: event.occurred_at,
            aggregate: record
          )
        end

        def publish_events(events)
          publisher = Domain::Shared::EventPublisher.instance
          events.each { |event| publisher.publish(event) }
        end
      end
    end
  end
end
