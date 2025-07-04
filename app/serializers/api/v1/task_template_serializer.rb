# API::V1::TaskTemplateSerializer
# Serializer for task template responses
class Api::V1::TaskTemplateSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :task_type, :execution_mode, :category,
             :tags, :active, :default_timeout, :default_priority, :default_weight,
             :created_at, :updated_at
  
  def tags
    object.tag_list
  end
end