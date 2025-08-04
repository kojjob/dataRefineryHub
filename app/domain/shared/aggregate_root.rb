# frozen_string_literal: true

module Domain
  module Shared
    # Base class for all aggregate roots
    class AggregateRoot < Entity
      def initialize(attributes = {})
        super
        @domain_events = []
        @version = 0
      end
      
      attr_reader :domain_events, :version
      
      def clear_events
        @domain_events.clear
      end
      
      protected
      
      def apply_event(event)
        # Set aggregate info on the event
        event.aggregate_id = id
        event.aggregate_type = self.class.name
        
        # Store the event
        @domain_events << event
        
        # Apply the event to update state
        handle_event(event)
        
        # Increment version
        @version += 1
      end
      
      # Override in subclasses to handle specific events
      def handle_event(event)
        handler_method = "on_#{event.event_type}"
        send(handler_method, event) if respond_to?(handler_method, true)
      end
      
      # For event sourcing - rebuild from events
      def replay_events(events)
        events.each do |event|
          handle_event(event)
          @version += 1
        end
      end
    end
  end
end
