# API::V1::ScheduledTaskRunSerializer
# Serializer for scheduled task run responses
class Api::V1::ScheduledTaskRunSerializer < ActiveModel::Serializer
  attributes :id, :status, :started_at, :completed_at, :duration_seconds,
             :error_message, :output, :created_at

  belongs_to :scheduled_task, serializer: Api::V1::ScheduledTaskSerializer
  belongs_to :pipeline_execution, serializer: Api::V1::PipelineSerializer
  belongs_to :task, serializer: Api::V1::TaskSerializer
end
