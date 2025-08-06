# frozen_string_literal: true

module Domain
  module Shared
    # Base class for all domain entities
    class Entity
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :id, :string
      attribute :created_at, :datetime
      attribute :updated_at, :datetime

      def initialize(attributes = {})
        super
        @id ||= SecureRandom.uuid
        @created_at ||= Time.current
        @updated_at ||= Time.current
      end

      def ==(other)
        other.is_a?(self.class) && id == other.id
      end

      alias eql? ==

      def hash
        id.hash
      end

      def persisted?
        created_at.present? && id.present?
      end

      protected

      def touch
        @updated_at = Time.current
      end
    end
  end
end
