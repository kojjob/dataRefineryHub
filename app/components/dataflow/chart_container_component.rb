module Dataflow
  class ChartContainerComponent < ViewComponent::Base
    def initialize(title:, chart_id:, controls: false)
      @title = title
      @chart_id = chart_id
      @controls = controls
    end

    private

    attr_reader :title, :chart_id, :controls
  end
end