class AddRetryPolicyFieldsToPipelineConfigurations < ActiveRecord::Migration[8.0]
  def change
    # The PipelineConfiguration model uses table_name = "pipelines"
    # so we need to add columns to the pipelines table
    add_column :pipelines, :retry_max_attempts, :integer
    add_column :pipelines, :retry_backoff_strategy, :string
    add_column :pipelines, :retry_initial_delay, :integer
    add_column :pipelines, :retry_max_delay, :integer
    add_column :pipelines, :retry_multiplier, :float
    
    reversible do |dir|
      dir.up do
        # Skip if no pipelines exist or retry_policy column doesn't exist
        return unless ActiveRecord::Base.connection.table_exists?(:pipelines) && 
                     ActiveRecord::Base.connection.column_exists?(:pipelines, :retry_policy)
        
        # Use raw SQL to avoid model dependencies
        execute <<~SQL
          UPDATE pipelines
          SET 
            retry_max_attempts = COALESCE((retry_policy->>'max_attempts')::integer, 3),
            retry_backoff_strategy = COALESCE(
              retry_policy->>'strategy',
              retry_policy->>'backoff_strategy',
              'exponential'
            ),
            retry_initial_delay = COALESCE(
              (retry_policy->>'initial_delay')::integer,
              (retry_policy->>'initial_delay_seconds')::integer,
              60
            ),
            retry_max_delay = COALESCE(
              (retry_policy->>'max_delay')::integer,
              (retry_policy->>'max_delay_seconds')::integer,
              3600
            ),
            retry_multiplier = COALESCE(
              (retry_policy->>'multiplier')::float,
              (retry_policy->>'backoff_multiplier')::float,
              2.0
            )
          WHERE retry_policy IS NOT NULL
            AND retry_policy != 'null'::jsonb
            AND retry_policy != '{}'::jsonb
        SQL
      end
    end
  end
end