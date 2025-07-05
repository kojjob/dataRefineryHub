# API::V1::ExecutionLogSerializer
# Serializer for pipeline execution logs
class Api::V1::ExecutionLogSerializer < ActiveModel::Serializer
  attributes :id, :level, :message, :context, :created_at
end
