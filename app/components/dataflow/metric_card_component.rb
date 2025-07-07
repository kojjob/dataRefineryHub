module Dataflow
  class MetricCardComponent < ViewComponent::Base
    def initialize(icon:, title:, value:, change: nil, change_type: :positive)
      @icon = icon
      @title = title
      @value = value
      @change = change
      @change_type = change_type
    end

    private

    attr_reader :icon, :title, :value, :change, :change_type

    def change_class
      case change_type
      when :positive
        "positive"
      when :negative
        "negative"
      else
        ""
      end
    end
  end
end