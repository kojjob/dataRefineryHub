#!/usr/bin/env ruby
# Script to create DDD directory structure

require 'fileutils'

base_path = File.join(Dir.pwd, 'app/domain')

directories = [
  # Shared Kernel
  'shared/domain_events',
  'shared/value_objects',
  
  # Pipeline Management Bounded Context
  'pipeline_management/entities',
  'pipeline_management/value_objects',
  'pipeline_management/aggregates',
  'pipeline_management/repositories',
  'pipeline_management/services',
  'pipeline_management/events',
  
  # Data Integration Bounded Context
  'data_integration/entities',
  'data_integration/value_objects',
  'data_integration/aggregates',
  'data_integration/repositories',
  'data_integration/services',
  'data_integration/events',
  
  # Execution Engine Bounded Context
  'execution_engine/entities',
  'execution_engine/value_objects',
  'execution_engine/aggregates',
  'execution_engine/repositories',
  'execution_engine/services',
  'execution_engine/events',
  
  # Data Quality Bounded Context
  'data_quality/entities',
  'data_quality/value_objects',
  'data_quality/services',
  'data_quality/repositories',
  'data_quality/events'
]

# Application Layer
app_directories = [
  'app/application/commands',
  'app/application/queries',
  'app/application/workflows',
  'app/application/event_handlers'
]

# Infrastructure Layer
infra_directories = [
  'app/infrastructure/persistence/active_record',
  'app/infrastructure/persistence/repositories',
  'app/infrastructure/external/warehouse_adapters',
  'app/infrastructure/external/storage_adapters',
  'app/infrastructure/external/notification_adapters'
]

all_directories = directories.map { |d| File.join(base_path, d) } + 
                  app_directories + infra_directories

all_directories.each do |dir|
  FileUtils.mkdir_p(dir)
  puts "Created: #{dir}"
end

puts "\nDDD directory structure created successfully!"
