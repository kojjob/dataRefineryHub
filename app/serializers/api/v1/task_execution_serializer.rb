# API::V1::TaskExecutionSerializer
# Serializer for task execution history
class Api::V1::TaskExecutionSerializer < ActiveModel::Serializer
  attributes :id, :status, :started_at, :completed_at, :duration_seconds,
             :output, :error_message, :created_at
  
  belongs_to :executed_by, serializer: Api::V1::UserSerializer
end