# Migration Guide: PipelineConfiguration to DDD

## Phase 1: Extract Value Objects (Week 1)

### Step 1: Replace schedule_config JSON with Schedule Value Object

#### Current Code:
```ruby
# In PipelineConfiguration model
schedule_config # JSON blob
```

#### Migration:
```ruby
# 1. Add migration to keep existing data
class AddScheduleFieldsToPipelineConfigurations < ActiveRecord::Migration[7.1]
  def change
    add_column :pipeline_configurations, :schedule_type, :string
    add_column :pipeline_configurations, :schedule_expression, :string
    add_column :pipeline_configurations, :schedule_timezone, :string, default: 'UTC'
    
    # Migrate existing data
    reversible do |dir|
      dir.up do
        PipelineConfiguration.find_each do |pipeline|
          if pipeline.schedule_config.present?
            pipeline.update_columns(
              schedule_type: pipeline.schedule_config['type'],
              schedule_expression: pipeline.schedule_config['expression'] || 
                                   pipeline.schedule_config['cron_expression'] || 
                                   pipeline.schedule_config['interval_minutes']&.to_s,
              schedule_timezone: pipeline.schedule_config['timezone'] || 'UTC'
            )
          end
        end
      end
    end
  end
end

# 2. Update PipelineConfiguration model
class PipelineConfiguration < ApplicationRecord
  # Add composed value object
  def schedule
    return nil unless schedule_type.present?
    
    @schedule ||= Domain::PipelineManagement::ValueObjects::Schedule.new(
      type: schedule_type,
      expression: schedule_expression,
      timezone: schedule_timezone
    )
  rescue ActiveModel::ValidationError
    nil
  end
  
  def schedule=(schedule_value_object)
    if schedule_value_object.nil?
      self.schedule_type = nil
      self.schedule_expression = nil
      self.schedule_timezone = nil
    else
      self.schedule_type = schedule_value_object.type
      self.schedule_expression = schedule_value_object.expression
      self.schedule_timezone = schedule_value_object.timezone
    end
    @schedule = schedule_value_object
  end
  
  # Update existing methods to use value object
  def scheduled?
    schedule.present?
  end
  
  def next_scheduled_run
    schedule&.next_run_time(from: last_executed_at || created_at)
  end
end

# 3. Update controllers/services
# Before:
pipeline.schedule_config = { type: 'cron', cron_expression: '0 0 * * *' }

# After:
pipeline.schedule = Domain::PipelineManagement::ValueObjects::Schedule.new(
  type: 'cron',
  expression: '0 0 * * *'
)
```

### Step 2: Extract RetryPolicy Value Object

```ruby
module Domain
  module PipelineManagement
    module ValueObjects
      class RetryPolicy
        include ActiveModel::Model
        
        attr_reader :max_attempts, :backoff_strategy, :backoff_seconds, :max_backoff_seconds
        
        STRATEGIES = %w[linear exponential constant].freeze
        
        validates :max_attempts, presence: true, 
                  numericality: { greater_than: 0, less_than_or_equal_to: 10 }
        validates :backoff_strategy, inclusion: { in: STRATEGIES }
        validates :backoff_seconds, presence: true, 
                  numericality: { greater_than: 0 }
        
        def initialize(max_attempts: 3, backoff_strategy: 'exponential', 
                       backoff_seconds: 60, max_backoff_seconds: 3600)
          @max_attempts = max_attempts
          @backoff_strategy = backoff_strategy
          @backoff_seconds = backoff_seconds
          @max_backoff_seconds = max_backoff_seconds
          validate!
        end
        
        def calculate_delay(attempt_number)
          return 0 if attempt_number <= 0
          
          delay = case backoff_strategy
          when 'linear'
            backoff_seconds * attempt_number
          when 'exponential'
            backoff_seconds * (2 ** (attempt_number - 1))
          when 'constant'
            backoff_seconds
          end
          
          [delay, max_backoff_seconds].min
        end
      end
    end
  end
end
```

## Phase 2: Create Domain Events (Week 2)

### Pipeline Domain Events:

```ruby
# app/domain/pipeline_management/events/pipeline_created.rb
module Domain
  module PipelineManagement
    module Events
      class PipelineCreated < Domain::Shared::DomainEvents::DomainEvent
        attr_reader :pipeline_id, :name, :organization_id, :created_by_id
        
        def initialize(pipeline_id:, name:, organization_id:, created_by_id:, **attrs)
          @pipeline_id = pipeline_id
          @name = name
          @organization_id = organization_id
          @created_by_id = created_by_id
          super(aggregate_id: pipeline_id, **attrs)
        end
      end
    end
  end
end

# app/domain/pipeline_management/events/pipeline_executed.rb
module Domain
  module PipelineManagement
    module Events
      class PipelineExecuted < Domain::Shared::DomainEvents::DomainEvent
        attr_reader :pipeline_id, :execution_id, :executed_by_id
        
        def initialize(pipeline_id:, execution_id:, executed_by_id:, **attrs)
          @pipeline_id = pipeline_id
          @execution_id = execution_id
          @executed_by_id = executed_by_id
          super(aggregate_id: pipeline_id, **attrs)
        end
      end
    end
  end
end
```

### Emit Events from Existing Model:

```ruby
class PipelineConfiguration < ApplicationRecord
  after_create :emit_created_event
  
  def execute(user: nil, parameters: {})
    execution = pipeline_executions.create!(
      user: user || last_executed_by,
      status: "queued",
      started_at: Time.current,
      parameters: parameters,
      configuration_snapshot: export_config
    )
    
    update!(
      last_executed_at: Time.current,
      last_executed_by: user
    )
    
    # Emit domain event
    emit_executed_event(execution, user)
    
    PipelineExecutionJob.perform_later(execution)
    execution
  end
  
  private
  
  def emit_created_event
    event = Domain::PipelineManagement::Events::PipelineCreated.new(
      pipeline_id: id,
      name: name,
      organization_id: organization_id,
      created_by_id: created_by_id
    )
    Domain::Shared::DomainEvents::EventPublisher.publish(event)
  end
  
  def emit_executed_event(execution, user)
    event = Domain::PipelineManagement::Events::PipelineExecuted.new(
      pipeline_id: id,
      execution_id: execution.id,
      executed_by_id: user&.id || last_executed_by_id
    )
    Domain::Shared::DomainEvents::EventPublisher.publish(event)
  end
end
```

## Phase 3: Extract Pipeline Aggregate (Week 3)

### Create Aggregate that Wraps Existing Model:

```ruby
module Domain
  module PipelineManagement
    class PipelineAggregate
      attr_reader :record, :events
      
      delegate :id, :name, :organization_id, :status, to: :record
      
      def initialize(record)
        @record = record
        @events = []
      end
      
      def self.find(id)
        record = ::PipelineConfiguration.find(id)
        new(record)
      end
      
      def configure_schedule(schedule_params)
        raise InvalidStateError, "Cannot configure archived pipeline" if archived?
        
        schedule = ValueObjects::Schedule.new(**schedule_params)
        record.schedule = schedule
        
        events << Events::PipelineScheduled.new(
          pipeline_id: id,
          schedule: schedule.to_h,
          scheduled_at: Time.current
        )
        
        self
      end
      
      def execute(user:)
        raise InvalidStateError, "Cannot execute inactive pipeline" unless active?
        
        execution = record.execute(user: user)
        
        events << Events::PipelineExecuted.new(
          pipeline_id: id,
          execution_id: execution.id,
          executed_by_id: user.id
        )
        
        execution
      end
      
      def save!
        record.transaction do
          record.save!
          Domain::Shared::DomainEvents::EventPublisher.publish_all(events)
          events.clear
        end
        self
      end
      
      private
      
      def active?
        record.active?
      end
      
      def archived?
        record.archived?
      end
    end
  end
end
```

## Phase 4: Introduce Repository Pattern (Week 4)

```ruby
module Domain
  module PipelineManagement
    class PipelineRepository
      def find(id)
        record = ::PipelineConfiguration.find_by(id: id)
        return nil unless record
        
        PipelineAggregate.new(record)
      end
      
      def save(aggregate)
        aggregate.save!
      end
      
      def find_by_organization(organization_id)
        ::PipelineConfiguration
          .where(organization_id: organization_id)
          .map { |record| PipelineAggregate.new(record) }
      end
    end
  end
end
```

## Phase 5: Update Controllers to Use Domain Layer

```ruby
class PipelinesController < ApplicationController
  def update
    # Before:
    # @pipeline = current_organization.pipeline_configurations.find(params[:id])
    # @pipeline.update!(pipeline_params)
    
    # After:
    repository = Domain::PipelineManagement::PipelineRepository.new
    pipeline = repository.find(params[:id])
    
    if params[:schedule].present?
      pipeline.configure_schedule(schedule_params)
    end
    
    repository.save(pipeline)
    
    redirect_to pipeline_path(pipeline.id)
  end
  
  private
  
  def schedule_params
    params.require(:schedule).permit(:type, :expression, :timezone)
  end
end
```

## Testing Strategy During Migration

Always maintain both old and new tests during migration:

```ruby
# Keep existing model tests
RSpec.describe PipelineConfiguration do
  # Existing tests remain unchanged
end

# Add new domain tests
RSpec.describe Domain::PipelineManagement::PipelineAggregate do
  let(:pipeline_record) { create(:pipeline_configuration) }
  let(:aggregate) { described_class.new(pipeline_record) }
  
  describe '#configure_schedule' do
    it 'configures schedule and emits event' do
      aggregate.configure_schedule(
        type: 'daily',
        expression: '10:00'
      )
      
      expect(aggregate.record.schedule).to be_present
      expect(aggregate.events).to include(
        an_instance_of(Domain::PipelineManagement::Events::PipelineScheduled)
      )
    end
  end
end
```

## Rollback Strategy

Each phase can be rolled back independently:
- Value Objects: Keep JSON columns, remove delegated methods
- Domain Events: Remove event publishing calls
- Aggregates: Revert to direct model usage
- Repository: Revert to ActiveRecord queries

## Success Metrics

- No breaking changes to existing functionality
- All existing tests continue to pass
- New domain tests provide better coverage
- Performance remains the same or improves
- Domain events are being published and can be monitored
