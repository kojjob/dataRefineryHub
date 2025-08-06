# frozen_string_literal: true

module Domain
  module PipelineManagement
    module Repositories
      # Repository interface for Pipeline aggregate persistence
      class PipelineRepository
        class NotFoundError < StandardError; end

        def find(id)
          raise NotImplementedError, "Subclass must implement #find"
        end

        def find_by_organization(organization_id)
          raise NotImplementedError, "Subclass must implement #find_by_organization"
        end

        def find_by_name(organization_id, name)
          raise NotImplementedError, "Subclass must implement #find_by_name"
        end

        def save(aggregate)
          raise NotImplementedError, "Subclass must implement #save"
        end

        def delete(id)
          raise NotImplementedError, "Subclass must implement #delete"
        end

        def exists?(id)
          raise NotImplementedError, "Subclass must implement #exists?"
        end

        def count_by_organization(organization_id)
          raise NotImplementedError, "Subclass must implement #count_by_organization"
        end

        def find_scheduled_pipelines(as_of: Time.current)
          raise NotImplementedError, "Subclass must implement #find_scheduled_pipelines"
        end

        def find_active_pipelines(organization_id: nil)
          raise NotImplementedError, "Subclass must implement #find_active_pipelines"
        end
      end
    end
  end
end
