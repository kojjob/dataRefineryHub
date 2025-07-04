# API::V1::ScheduledTaskSerializer
# Serializer for scheduled task responses
class Api::V1::ScheduledTaskSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :status, :schedule_type, :schedule_description,
             :next_run_at, :run_count, :max_runs, :start_date, :end_date,
             :created_at, :updated_at
  
  belongs_to :task_template, serializer: Api::V1::TaskTemplateSerializer
  belongs_to :created_by, serializer: Api::V1::UserSerializer
  
  def schedule_description
    object.schedule_description
  end
end