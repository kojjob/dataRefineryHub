# API::V1::DataSourceSerializer
# Serializer for data source responses
class Api::V1::DataSourceSerializer < ActiveModel::Serializer
  attributes :id, :name, :source_type, :status, :created_at, :updated_at
end
