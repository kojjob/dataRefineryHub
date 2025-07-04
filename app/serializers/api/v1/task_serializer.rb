# API::V1::TaskSerializer
# Serializer for task responses
class Api::V1::TaskSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :task_type, :execution_mode, :status,
             :priority, :position, :started_at, :completed_at, :duration_seconds,
             :retry_count, :max_retries, :timeout_seconds, :created_at, :updated_at
  
  belongs_to :pipeline_execution, serializer: Api::V1::PipelineSerializer
  belongs_to :assignee, serializer: Api::V1::UserSerializer
  belongs_to :task_template, serializer: Api::V1::TaskTemplateSerializer
  
  def duration_seconds
    object.duration_seconds
  end
end