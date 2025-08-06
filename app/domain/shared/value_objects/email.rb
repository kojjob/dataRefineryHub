# frozen_string_literal: true

module Domain
  module Shared
    module ValueObjects
      # Email value object with validation
      class Email
        include ActiveModel::Model

        attr_reader :value

        validates :value, presence: true
        validates :value, format: {
          with: URI::MailTo::EMAIL_REGEXP,
          message: "is not a valid email address"
        }

        def initialize(value)
          @value = value&.downcase&.strip
          validate!
        end

        def to_s
          value
        end

        def ==(other)
          other.is_a?(self.class) && value == other.value
        end

        alias eql? ==

        def hash
          value.hash
        end

        # For ActiveRecord serialization
        def self.dump(email)
          email&.value
        end

        def self.load(value)
          new(value) if value.present?
        end
      end
    end
  end
end
