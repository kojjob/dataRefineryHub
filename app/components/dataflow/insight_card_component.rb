module Dataflow
  class InsightCardComponent < ViewComponent::Base
    def initialize(type:, confidence:, message:, action_text:, severity: :medium)
      @type = type
      @confidence = confidence
      @message = message
      @action_text = action_text
      @severity = severity
    end

    private

    attr_reader :type, :confidence, :message, :action_text, :severity

    def severity_class
      case severity
      when :critical
        "critical"
      when :high
        "high"
      when :medium
        "medium"
      else
        ""
      end
    end

    def button_class
      severity == :critical ? "btn--primary" : "btn--outline"
    end
  end
end
