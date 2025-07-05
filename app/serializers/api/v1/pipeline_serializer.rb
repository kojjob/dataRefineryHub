# API::V1::PipelineSerializer
# Serializer for pipeline execution responses
class Api::V1::PipelineSerializer < ActiveModel::Serializer
  attributes :id, :pipeline_name, :status, :execution_mode, :priority,
             :started_at, :completed_at, :duration_seconds, :progress_percentage,
             :total_tasks, :completed_tasks, :failed_tasks, :created_at, :updated_at

  belongs_to :data_source, serializer: Api::V1::DataSourceSerializer
  belongs_to :user, serializer: Api::V1::UserSerializer

  def duration_seconds
    object.duration_seconds
  end

  def progress_percentage
    object.progress_percentage
  end
end
