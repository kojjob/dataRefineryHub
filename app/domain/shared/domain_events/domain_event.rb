# frozen_string_literal: true

module Domain
  module Shared
    module DomainEvents
      # Base class for all domain events
      class DomainEvent
        include ActiveModel::Model
        include ActiveModel::Serialization

        attr_reader :aggregate_id, :occurred_at, :version

        def initialize(attributes = {})
          @occurred_at = attributes.fetch(:occurred_at, Time.current)
          @version = attributes.fetch(:version, 1)
          super
        end

        def event_type
          self.class.name.demodulize
        end

        def to_h
          serializable_hash.symbolize_keys
        end

        def ==(other)
          return false unless other.is_a?(self.class)

          to_h == other.to_h
        end
      end
    end
  end
end
