# API::V1::TaskTemplateDetailSerializer
# Detailed serializer for task template with configuration
class Api::V1::TaskTemplateDetailSerializer < Api::V1::TaskTemplateSerializer
  attributes :template_config, :usage_count
  
  def usage_count
    object.tasks.count
  end
end