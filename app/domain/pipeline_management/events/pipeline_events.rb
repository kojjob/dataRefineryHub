# frozen_string_literal: true

module Domain
  module PipelineManagement
    module Events
      # Event raised when a pipeline is created
      class PipelineCreated < ::Domain::Shared::DomainEvent
        attribute :name, :string
        attribute :organization_id, :string
        attribute :created_by_id, :string
        
        validates :name, :organization_id, :created_by_id, presence: true
      end
      
      # Event raised when pipeline source is configured
      class SourceConfigured < ::Domain::Shared::DomainEvent
        attribute :source_type, :string
        attribute :configuration, :json
        attribute :configured_by_id, :string
        
        validates :source_type, :configuration, presence: true
      end
      
      # Event raised when pipeline destination is configured
      class DestinationConfigured < ::Domain::Shared::DomainEvent
        attribute :destination_type, :string
        attribute :configuration, :json
        attribute :configured_by_id, :string
        
        validates :destination_type, :configuration, presence: true
      end
      
      # Event raised when transformation rule is added
      class TransformationRuleAdded < ::Domain::Shared::DomainEvent
        attribute :rule, :json
        attribute :position, :integer
        attribute :added_by_id, :string
        
        validates :rule, :position, presence: true
      end
      
      # Event raised when transformation rule is removed
      class TransformationRuleRemoved < ::Domain::Shared::DomainEvent
        attribute :position, :integer
        attribute :removed_by_id, :string
        
        validates :position, presence: true
      end
      
      # Event raised when pipeline is scheduled
      class PipelineScheduled < ::Domain::Shared::DomainEvent
        attribute :schedule, :json
        attribute :next_run_at, :datetime
        attribute :scheduled_by_id, :string
        
        validates :schedule, presence: true
      end
      
      # Event raised when pipeline schedule is removed
      class PipelineUnscheduled < ::Domain::Shared::DomainEvent
        attribute :unscheduled_by_id, :string
      end
      
      # Event raised when pipeline status changes
      class PipelineStatusChanged < ::Domain::Shared::DomainEvent
        attribute :from_status, :string
        attribute :to_status, :string
        attribute :reason, :string
        attribute :changed_by_id, :string
        
        validates :from_status, :to_status, presence: true
      end
      
      # Event raised when pipeline is activated
      class PipelineActivated < ::Domain::Shared::DomainEvent
        attribute :activated_by_id, :string
      end
      
      # Event raised when pipeline is paused
      class PipelinePaused < ::Domain::Shared::DomainEvent
        attribute :reason, :string
        attribute :paused_by_id, :string
      end
      
      # Event raised when pipeline is archived
      class PipelineArchived < ::Domain::Shared::DomainEvent
        attribute :reason, :string
        attribute :archived_by_id, :string
      end
      
      # Event raised when pipeline execution starts
      class PipelineExecutionStarted < ::Domain::Shared::DomainEvent
        attribute :execution_id, :string
        attribute :triggered_by, :string # 'scheduled', 'manual', 'webhook'
        attribute :executor_id, :string
        attribute :parameters, :json
        
        validates :execution_id, :triggered_by, presence: true
      end
      
      # Event raised when pipeline execution completes
      class PipelineExecutionCompleted < ::Domain::Shared::DomainEvent
        attribute :execution_id, :string
        attribute :status, :string # 'success', 'failed', 'partial'
        attribute :duration_seconds, :integer
        attribute :rows_processed, :integer
        attribute :error_message, :string
        
        validates :execution_id, :status, presence: true
      end
      
      # Event raised when retry policy is set
      class RetryPolicyConfigured < ::Domain::Shared::DomainEvent
        attribute :retry_policy, :json
        attribute :configured_by_id, :string
        
        validates :retry_policy, presence: true
      end
    end
  end
end
