# frozen_string_literal: true

class AddScheduleFieldsToPipelineConfigurations < ActiveRecord::Migration[7.1]
  def change
    # Determine the table name (might be pipelines or pipeline_configurations)
    table_name = table_exists?(:pipelines) ? :pipelines : :pipeline_configurations
    
    add_column table_name, :schedule_type, :string unless column_exists?(table_name, :schedule_type)
    add_column table_name, :schedule_expression, :string unless column_exists?(table_name, :schedule_expression)
    add_column table_name, :schedule_timezone, :string, default: 'UTC' unless column_exists?(table_name, :schedule_timezone)
    
    # Migrate existing schedule_config data
    reversible do |dir|
      dir.up do
        if ActiveRecord::Base.connection.table_exists?(table_name) && column_exists?(table_name, :schedule_config)
          # Use direct SQL to avoid model dependencies
          execute <<~SQL
            UPDATE #{table_name}
            SET 
              schedule_type = COALESCE(schedule_config->>'type', NULL),
              schedule_expression = COALESCE(
                schedule_config->>'expression',
                schedule_config->>'cron_expression',
                (schedule_config->>'interval_minutes')::text,
                NULL
              ),
              schedule_timezone = COALESCE(schedule_config->>'timezone', 'UTC')
            WHERE schedule_config IS NOT NULL
              AND schedule_config != 'null'::jsonb
              AND schedule_config != '{}'::jsonb
          SQL
        end
      end
    end
  end
end
