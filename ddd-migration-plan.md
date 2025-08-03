# Data Refinery Platform - DDD Migration Analysis & Plan

**Document Version**: 2.0  
**Created**: January 19, 2025  
**Status**: Active Planning Phase

## Executive Summary

The Data Refinery Platform's DDD migration is more advanced than initially documented. A complete domain layer with event sourcing has been implemented but remains disconnected from the Rails application. This document provides a comprehensive analysis and actionable plan to bridge this gap while maintaining production stability.

## Current State Analysis

### ✅ Completed Work

#### 1. Domain Structure
Complete bounded contexts have been created:
```
app/domain/
├── pipeline_management/    # Most developed
├── data_integration/      # Structure only
├── data_quality/         # Structure only
├── execution_engine/     # Structure only
└── shared/              # Core DDD infrastructure
```

#### 2. Domain Infrastructure
- **Base Classes**: Entity, AggregateRoot, DomainEvent
- **Event System**: EventPublisher with subscription mechanism
- **Value Objects**: Schedule, RetryPolicy, PipelineStatus, TransformationRule
- **Domain Events**: Complete event hierarchy for pipeline lifecycle

#### 3. Event Sourcing Implementation
- PipelineAggregate with full event sourcing
- Domain events table (`domain_events`) in database
- ActiveRecordPipelineRepository with event persistence
- Infrastructure models for bridging domain and persistence

#### 4. Model Naming
- Already using `Pipeline` model (not `PipelineConfiguration`)
- Database table correctly named `pipelines`

### ⚠️ Critical Issues Found

#### 1. Database Schema Mismatch
```ruby
# Created migrations target wrong table:
class AddScheduleFieldsToPipelineConfigurations  # Wrong table name!
class AddRetryPolicyFieldsToPipelineConfigurations  # Wrong table name!

# Actual table is 'pipelines' not 'pipeline_configurations'
```

#### 2. Parallel Systems Problem
Two complete pipeline implementations exist:
- **Traditional**: `app/models/pipeline.rb` (ActiveRecord)
- **DDD**: `app/domain/pipeline_management/` (Event Sourced)

These systems are not connected!

#### 3. Model Code Issues
```ruby
# In app/models/pipeline.rb
def validate_dependencies
  existing_pipelines = organization.pipeline_configurations  # Bug: wrong association
                                  .where(name: dependency_names)
                                  .pluck(:name)
end
```

#### 4. Missing Application Layer
- No command handlers or application services
- Controllers directly use ActiveRecord models
- Repository pattern implemented but not used

## Root Cause Analysis

### Why Two Systems Exist

1. **Incremental Migration Attempt**: Domain layer built alongside existing system
2. **Missing Bridge**: No connection between domain and Rails application
3. **Incomplete Documentation**: Knowledge base doesn't reflect actual progress
4. **Fear of Breaking Changes**: Domain layer not integrated to preserve stability

### Technical Debt Accumulated

1. Duplicate business logic across both systems
2. Migrations created for wrong table names
3. Value object integration in wrong model
4. Event sourcing infrastructure unused

## Recommended Solution Architecture

### Target Architecture
```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Controllers   │────▶│ Command Handlers │────▶│ Domain Layer    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                │                          │
                                ▼                          ▼
                        ┌──────────────────┐     ┌─────────────────┐
                        │ Query Services   │────▶│ Repositories    │
                        └──────────────────┘     └─────────────────┘
                                │                          │
                                ▼                          ▼
                        ┌──────────────────┐     ┌─────────────────┐
                        │ Read Models      │     │ Event Store     │
                        └──────────────────┘     └─────────────────┘
```

### Bridge Strategy
```ruby
# Gradual migration approach
class Pipeline < ApplicationRecord
  # Phase 1: Delegate to domain for writes
  def activate!(user)
    command = Commands::ActivatePipeline.new(
      pipeline_id: id,
      user: user
    )
    ApplicationService.handle(command)
  end
  
  # Phase 2: Maintain read model for queries
  # Keep existing associations and scopes
  
  # Phase 3: Eventually become thin persistence adapter
end
```

## Migration Plan - 8 Week Timeline

### Phase 1: Fix Infrastructure (Week 1)

#### Tasks:
1. **Fix Migration Issues**
   ```ruby
   # Delete incorrect migrations
   rails destroy migration AddScheduleFieldsToPipelineConfigurations
   rails destroy migration AddRetryPolicyFieldsToPipelineConfigurations
   
   # Create correct migration
   class AddDomainFieldsToPipelines < ActiveRecord::Migration[8.0]
     def change
       # Add retry policy fields
       add_column :pipelines, :retry_max_attempts, :integer
       add_column :pipelines, :retry_backoff_strategy, :string
       add_column :pipelines, :retry_initial_delay, :integer
       add_column :pipelines, :retry_max_delay, :integer
       add_column :pipelines, :retry_multiplier, :float
       
       # Add status tracking fields
       add_column :pipelines, :status_changed_at, :datetime
       add_column :pipelines, :status_changed_by_id, :bigint
       add_column :pipelines, :status_reason, :text
       
       # Add event sourcing support
       add_column :pipelines, :aggregate_version, :integer, default: 0
       add_index :pipelines, :aggregate_version
     end
   end
   ```

2. **Fix Model Bugs**
   ```ruby
   # In app/models/pipeline.rb
   def validate_dependencies
     dependency_names = dependencies.map { |d| d["pipeline_name"] }
     
     # Fix: use 'pipelines' not 'pipeline_configurations'
     existing_pipelines = organization.pipelines
                                     .where(name: dependency_names)
                                     .pluck(:name)
     
     missing = dependency_names - existing_pipelines
     if missing.any?
       errors.add(:dependencies, "Unknown pipelines: #{missing.join(', ')}")
     end
   end
   ```

3. **Configure Rails Autoloading**
   ```ruby
   # config/application.rb
   config.autoload_paths << Rails.root.join('app/domain')
   config.autoload_paths << Rails.root.join('app/application')
   config.autoload_paths << Rails.root.join('app/infrastructure')
   ```

### Phase 2: Create Application Layer (Week 2)

#### Directory Structure:
```
app/application/
├── commands/
│   ├── base_command.rb
│   ├── create_pipeline.rb
│   ├── activate_pipeline.rb
│   ├── schedule_pipeline.rb
│   └── execute_pipeline.rb
├── queries/
│   ├── get_pipeline.rb
│   ├── list_pipelines.rb
│   └── pipeline_statistics.rb
└── services/
    └── application_service.rb
```

#### Sample Command Handler:
```ruby
module Application
  module Commands
    class CreatePipeline < BaseCommand
      attr_reader :name, :description, :organization_id, :user_id
      
      validates :name, presence: true
      validates :organization_id, presence: true
      validates :user_id, presence: true
      
      def initialize(name:, description: nil, organization_id:, user_id:)
        @name = name
        @description = description
        @organization_id = organization_id
        @user_id = user_id
      end
    end
    
    class CreatePipelineHandler
      def initialize(repository: ActiveRecordPipelineRepository.new)
        @repository = repository
      end
      
      def handle(command)
        # Check if pipeline name already exists
        existing = @repository.find_by_name(
          command.organization_id, 
          command.name
        )
        raise NameAlreadyTaken if existing
        
        # Create aggregate
        pipeline = PipelineAggregate.create(
          name: command.name,
          description: command.description,
          organization_id: command.organization_id,
          created_by: User.find(command.user_id)
        )
        
        # Save to repository
        @repository.save(pipeline)
        
        # Return result
        Result.success(pipeline_id: pipeline.id)
      end
    end
  end
end
```

### Phase 3: Update Controllers Incrementally (Weeks 3-4)

#### Migration Strategy:
```ruby
class PipelinesController < ApplicationController
  # Phase 3.1: New create action using command
  def create
    command = Commands::CreatePipeline.new(
      name: pipeline_params[:name],
      description: pipeline_params[:description],
      organization_id: current_organization.id,
      user_id: current_user.id
    )
    
    result = ApplicationService.handle(command)
    
    if result.success?
      @pipeline = Pipeline.find(result.pipeline_id)
      redirect_to @pipeline, notice: 'Pipeline created successfully'
    else
      @pipeline = Pipeline.new(pipeline_params)
      @pipeline.errors.add(:base, result.error_message)
      render :new
    end
  end
  
  # Phase 3.2: Keep existing read actions temporarily
  def index
    @pipelines = current_organization.pipelines
  end
end
```

### Phase 4: Migrate Related Models (Weeks 5-6)

#### Priority Order:
1. **PipelineExecution** - Create ExecutionAggregate
2. **DataSource** - Move to DataIntegration context
3. **Alert** - Create as domain event handler
4. **Task** - Part of ExecutionEngine context

### Phase 5: Remove Legacy Code (Weeks 7-8)

1. Remove business logic from ActiveRecord models
2. Convert models to thin persistence adapters
3. Remove duplicate validations
4. Clean up unused code

## Implementation Guidelines

### 1. Testing Strategy

```ruby
# Unit tests for domain
RSpec.describe Domain::PipelineManagement::Aggregates::PipelineAggregate do
  # Test aggregate behavior
end

# Integration tests for repositories  
RSpec.describe Infrastructure::Persistence::Repositories::ActiveRecordPipelineRepository do
  # Test persistence
end

# Feature tests for commands
RSpec.describe Application::Commands::CreatePipelineHandler do
  # Test full flow
end
```

### 2. Event Handling

```ruby
# Subscribe to domain events
Domain::Shared::DomainEvents::EventPublisher.subscribe(
  Domain::PipelineManagement::Events::PipelineActivated,
  NotificationService.new
)
```

### 3. Performance Considerations

- Use read models for queries (avoid event replay)
- Implement caching for aggregates
- Use database views for complex reports
- Consider CQRS for read-heavy operations

## Risk Mitigation

### 1. Gradual Rollout
- Feature flags for new functionality
- A/B testing between old and new code paths
- Monitoring and alerting on both systems

### 2. Data Integrity
- Keep both systems in sync during migration
- Automated tests comparing outputs
- Data validation scripts

### 3. Rollback Strategy
- Each phase independently deployable
- Database migrations reversible
- Feature flags for instant rollback

## Success Metrics

### Technical Metrics
- [ ] All tests passing
- [ ] No performance degradation
- [ ] Zero data inconsistencies
- [ ] 100% feature parity

### Business Metrics
- [ ] No increase in bug reports
- [ ] Maintained system uptime
- [ ] Improved development velocity
- [ ] Easier onboarding for new developers

## Immediate Action Items

### This Week (Priority Order):

1. **Fix Pipeline Model Bug**
   ```bash
   # Create fix branch
   git checkout -b fix/pipeline-dependencies-bug
   
   # Fix the validate_dependencies method
   # Run tests
   bundle exec rspec spec/models/pipeline_spec.rb
   
   # Deploy fix
   ```

2. **Create Correct Migrations**
   ```bash
   # Generate new migration
   rails g migration AddDomainFieldsToPipelines
   
   # Run migration
   rails db:migrate
   ```

3. **Create First Command Handler**
   ```bash
   # Create application structure
   mkdir -p app/application/commands
   
   # Implement CreatePipeline command
   # Write tests
   # Integrate with one controller action
   ```

4. **Add Integration Test**
   ```ruby
   # spec/integration/create_pipeline_flow_spec.rb
   RSpec.describe "Create Pipeline Flow" do
     it "creates pipeline through domain layer" do
       # Test complete flow
     end
   end
   ```

## Long-term Vision

### 6 Month Goal
- Complete DDD migration for all bounded contexts
- Full event sourcing for audit trail
- CQRS implementation for reporting
- Microservice extraction preparation

### 12 Month Goal
- Extract bounded contexts as services
- Event streaming between services
- Full API-first architecture
- Multi-tenant optimization

## Resources & References

### Documentation
- [Domain-Driven Design by Eric Evans](https://www.domainlanguage.com/ddd/)
- [Implementing Domain-Driven Design by Vaughn Vernon](https://www.informit.com/store/implementing-domain-driven-design-9780321834577)
- [Event Sourcing Pattern](https://martinfowler.com/eaaDev/EventSourcing.html)

### Team Training
- Weekly DDD study group
- Pair programming sessions
- Code review focus on domain concepts
- Architecture decision records (ADRs)

## Conclusion

The Data Refinery Platform has a solid domain foundation that needs to be connected to the Rails application layer. By following this incremental migration plan, we can achieve a clean DDD architecture while maintaining system stability and team productivity.

The key is to move deliberately, test thoroughly, and maintain backward compatibility throughout the migration process.

---

**Next Review**: After Phase 1 completion  
**Contact**: Architecture Team  
**Questions**: Use #ddd-migration Slack channel