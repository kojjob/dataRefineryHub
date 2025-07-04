# API::V1::TaskDetailSerializer
# Detailed serializer for task with full information
class Api::V1::TaskDetailSerializer < Api::V1::TaskSerializer
  attributes :configuration, :metadata, :error_message, :depends_on, :execution_id
  
  has_many :task_executions, serializer: Api::V1::TaskExecutionSerializer
  
  def task_executions
    object.task_executions.recent.limit(10)
  end
end