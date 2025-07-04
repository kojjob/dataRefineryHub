# API::V1::PipelineDetailSerializer
# Detailed serializer for pipeline execution with full information
class Api::V1::PipelineDetailSerializer < Api::V1::PipelineSerializer
  attributes :configuration, :metadata, :error_message, :retry_count
  
  has_many :tasks, serializer: Api::V1::TaskSerializer
  
  def tasks
    object.tasks.order(:position)
  end
end