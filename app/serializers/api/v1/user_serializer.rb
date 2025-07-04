# API::V1::UserSerializer
# Serializer for user responses (limited information for API)
class Api::V1::UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :first_name, :last_name, :full_name, :role
  
  def full_name
    object.full_name
  end
end