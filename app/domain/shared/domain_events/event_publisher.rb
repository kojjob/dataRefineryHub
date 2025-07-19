# frozen_string_literal: true

module Domain
  module Shared
    module DomainEvents
      # Publishes domain events to subscribers
      class EventPublisher
        include Singleton

        def initialize
          @subscribers = Hash.new { |hash, key| hash[key] = [] }
        end

        def subscribe(event_class, handler)
          @subscribers[event_class] << handler
        end

        def publish(event)
          handlers = @subscribers[event.class] + @subscribers[DomainEvent]
          
          handlers.each do |handler|
            case handler
            when Proc
              handler.call(event)
            when Class
              handler.new.call(event) if handler.instance_methods.include?(:call)
            else
              handler.call(event) if handler.respond_to?(:call)
            end
          end
        end

        def publish_all(events)
          events.each { |event| publish(event) }
        end

        def clear_subscribers
          @subscribers.clear
        end

        class << self
          delegate :subscribe, :publish, :publish_all, :clear_subscribers, to: :instance
        end
      end
    end
  end
end
