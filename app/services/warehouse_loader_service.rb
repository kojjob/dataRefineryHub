# WarehouseLoaderService
# Handles loading raw data directly into data warehouses for ELT processing
class WarehouseLoaderService
  include Singleton

  SUPPORTED_WAREHOUSES = %w[snowflake bigquery redshift databricks synapse].freeze

  def initialize
    @logger = Rails.logger
    @loaders = {}
    initialize_loaders
  end

  def load_to_warehouse(warehouse_type, data_source, data, options = {})
    loader = @loaders[warehouse_type]
    raise ArgumentError, "Unsupported warehouse type: #{warehouse_type}" unless loader

    loader.load(data_source, data, options)
  end

  def create_external_table(warehouse_type, data_source, options = {})
    loader = @loaders[warehouse_type]
    raise ArgumentError, "Unsupported warehouse type: #{warehouse_type}" unless loader

    loader.create_external_table(data_source, options)
  end

  def setup_elt_pipeline(warehouse_type, data_source, options = {})
    loader = @loaders[warehouse_type]
    raise ArgumentError, "Unsupported warehouse type: #{warehouse_type}" unless loader

    # Create staging area
    staging_info = loader.create_staging_area(data_source)

    # Set up incremental loading if requested
    if options[:incremental]
      loader.setup_incremental_loading(data_source, staging_info)
    end

    # Create transformation views/procedures
    if options[:transformations]
      loader.create_transformation_layer(data_source, options[:transformations])
    end

    staging_info
  end

  private

  def initialize_loaders
    @loaders["snowflake"] = SnowflakeLoader.new
    @loaders["bigquery"] = BigQueryLoader.new
    @loaders["redshift"] = RedshiftLoader.new
    @loaders["databricks"] = DatabricksLoader.new
    @loaders["synapse"] = SynapseLoader.new
  end

  # Base Warehouse Loader
  class BaseWarehouseLoader
    def initialize
      @logger = Rails.logger
    end

    def load(data_source, data, options = {})
      raise NotImplementedError, "Subclass must implement load method"
    end

    def create_external_table(data_source, options = {})
      raise NotImplementedError, "Subclass must implement create_external_table method"
    end

    def create_staging_area(data_source)
      raise NotImplementedError, "Subclass must implement create_staging_area method"
    end

    def setup_incremental_loading(data_source, staging_info)
      raise NotImplementedError, "Subclass must implement setup_incremental_loading method"
    end

    def create_transformation_layer(data_source, transformations)
      raise NotImplementedError, "Subclass must implement create_transformation_layer method"
    end

    protected

    def generate_table_name(data_source, prefix = "raw")
      "#{prefix}_#{data_source.source_type}_#{data_source.id}"
    end

    def infer_schema(data)
      return {} if data.empty?

      schema = {}
      sample_size = [ data.size, 1000 ].min

      data.first(sample_size).each do |record|
        record.each do |key, value|
          schema[key] ||= infer_column_type(value)
        end
      end

      schema
    end

    def infer_column_type(value)
      case value
      when Integer
        "INTEGER"
      when Float
        "FLOAT"
      when TrueClass, FalseClass
        "BOOLEAN"
      when Date
        "DATE"
      when DateTime, Time
        "TIMESTAMP"
      when Hash, Array
        "VARIANT" # JSON type
      else
        "VARCHAR"
      end
    end
  end

  # Snowflake Loader
  class SnowflakeLoader < BaseWarehouseLoader
    def initialize
      super
      @connection = establish_connection
    end

    def load(data_source, data, options = {})
      table_name = options[:table_name] || generate_table_name(data_source)
      schema_name = options[:schema] || "RAW_DATA"

      # Create schema if not exists
      @connection.execute("CREATE SCHEMA IF NOT EXISTS #{schema_name}")

      # Create table based on data schema
      create_table_from_data(schema_name, table_name, data) unless options[:skip_table_creation]

      # Load data
      if options[:use_copy]
        load_via_copy(schema_name, table_name, data, options)
      else
        load_via_insert(schema_name, table_name, data, options)
      end

      # Return load statistics
      {
        warehouse: "snowflake",
        table: "#{schema_name}.#{table_name}",
        rows_loaded: data.size,
        method: options[:use_copy] ? "COPY" : "INSERT"
      }
    end

    def create_external_table(data_source, options = {})
      table_name = options[:table_name] || generate_table_name(data_source, "ext")
      schema_name = options[:schema] || "EXTERNAL_TABLES"

      case data_source.source_type
      when "s3"
        create_s3_external_table(schema_name, table_name, data_source, options)
      when "azure_blob"
        create_azure_external_table(schema_name, table_name, data_source, options)
      else
        raise NotImplementedError, "External tables not supported for #{data_source.source_type}"
      end
    end

    def create_staging_area(data_source)
      staging_schema = "STAGING_#{data_source.organization_id}"

      # Create staging schema
      @connection.execute("CREATE SCHEMA IF NOT EXISTS #{staging_schema}")

      # Create file format
      file_format = create_file_format(data_source)

      # Create stage
      stage_name = "#{staging_schema}.#{data_source.source_type}_STAGE_#{data_source.id}"
      create_stage(stage_name, data_source)

      {
        schema: staging_schema,
        stage: stage_name,
        file_format: file_format
      }
    end

    def setup_incremental_loading(data_source, staging_info)
      table_name = generate_table_name(data_source)

      # Create merge stored procedure
      proc_sql = <<-SQL
        CREATE OR REPLACE PROCEDURE #{staging_info[:schema]}.MERGE_#{table_name}()
        RETURNS VARCHAR
        LANGUAGE SQL
        AS
        $$
        BEGIN
          MERGE INTO RAW_DATA.#{table_name} AS target
          USING (
            SELECT * FROM @#{staging_info[:stage]}
          ) AS source
          ON target.id = source.id
          WHEN MATCHED THEN
            UPDATE SET target.* = source.*
          WHEN NOT MATCHED THEN
            INSERT (*) VALUES (source.*);
        #{'  '}
          RETURN 'Merge completed successfully';
        END;
        $$
      SQL

      @connection.execute(proc_sql)

      # Create task for automated loading
      create_automated_task(data_source, staging_info)
    end

    def create_transformation_layer(data_source, transformations)
      transform_schema = "TRANSFORMED_#{data_source.organization_id}"
      @connection.execute("CREATE SCHEMA IF NOT EXISTS #{transform_schema}")

      transformations.each do |transform|
        case transform[:type]
        when "view"
          create_transformation_view(transform_schema, transform)
        when "materialized_view"
          create_materialized_view(transform_schema, transform)
        when "procedure"
          create_transformation_procedure(transform_schema, transform)
        end
      end
    end

    private

    def establish_connection
      config = Rails.application.config.snowflake

      require "odbc"
      ODBC.connect(
        config[:dsn],
        config[:username],
        config[:password]
      )
    end

    def create_table_from_data(schema_name, table_name, data)
      schema = infer_schema(data)

      columns = schema.map do |name, type|
        "#{name} #{type}"
      end.join(", ")

      sql = <<-SQL
        CREATE TABLE IF NOT EXISTS #{schema_name}.#{table_name} (
          #{columns},
          _loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
          _source VARCHAR
        )
      SQL

      @connection.execute(sql)
    end

    def load_via_copy(schema_name, table_name, data, options)
      # Write data to temporary file
      temp_file = Tempfile.new([ "snowflake_load", ".csv" ])

      begin
        CSV.open(temp_file.path, "w") do |csv|
          csv << data.first.keys if data.any?
          data.each { |row| csv << row.values }
        end

        # Upload to internal stage
        stage_name = "@~/temp_load_#{SecureRandom.hex(8)}"
        @connection.execute("PUT file://#{temp_file.path} #{stage_name}")

        # Copy into table
        copy_sql = <<-SQL
          COPY INTO #{schema_name}.#{table_name}
          FROM #{stage_name}
          FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1)
          ON_ERROR = #{options[:on_error] || 'CONTINUE'}
        SQL

        @connection.execute(copy_sql)

        # Clean up stage
        @connection.execute("REMOVE #{stage_name}")
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    def load_via_insert(schema_name, table_name, data, options)
      # Batch inserts for better performance
      batch_size = options[:batch_size] || 1000

      data.each_slice(batch_size) do |batch|
        values = batch.map do |row|
          "(#{row.values.map { |v| quote_value(v) }.join(', ')})"
        end.join(", ")

        columns = data.first.keys.join(", ")

        insert_sql = <<-SQL
          INSERT INTO #{schema_name}.#{table_name} (#{columns})
          VALUES #{values}
        SQL

        @connection.execute(insert_sql)
      end
    end

    def quote_value(value)
      case value
      when nil
        "NULL"
      when String
        "'#{value.gsub("'", "''")}'"
      when Date, DateTime, Time
        "'#{value.iso8601}'"
      when TrueClass
        "TRUE"
      when FalseClass
        "FALSE"
      else
        value.to_s
      end
    end

    def create_s3_external_table(schema_name, table_name, data_source, options)
      sql = <<-SQL
        CREATE OR REPLACE EXTERNAL TABLE #{schema_name}.#{table_name} (
          #{options[:columns] || 'data VARIANT'}
        )
        WITH LOCATION = @#{data_source.connection_details['stage_name']}
        FILE_FORMAT = #{options[:file_format] || '(TYPE = JSON)'}
      SQL

      @connection.execute(sql)
    end

    def create_file_format(data_source)
      format_name = "FF_#{data_source.source_type.upcase}_#{data_source.id}"

      format_sql = case data_source.connection_details["file_type"]
      when "csv"
        <<-SQL
          CREATE OR REPLACE FILE FORMAT #{format_name}
          TYPE = CSV
          FIELD_DELIMITER = ','
          SKIP_HEADER = 1
          NULL_IF = ('NULL', '')
          EMPTY_FIELD_AS_NULL = TRUE
        SQL
      when "json"
        <<-SQL
          CREATE OR REPLACE FILE FORMAT #{format_name}
          TYPE = JSON
          STRIP_OUTER_ARRAY = TRUE
        SQL
      when "parquet"
        <<-SQL
          CREATE OR REPLACE FILE FORMAT #{format_name}
          TYPE = PARQUET
        SQL
      else
        <<-SQL
          CREATE OR REPLACE FILE FORMAT #{format_name}
          TYPE = CSV
        SQL
      end

      @connection.execute(format_sql)
      format_name
    end

    def create_stage(stage_name, data_source)
      case data_source.source_type
      when "s3"
        credentials = data_source.credentials
        stage_sql = <<-SQL
          CREATE OR REPLACE STAGE #{stage_name}
          URL = 's3://#{data_source.connection_details['bucket']}/#{data_source.connection_details['prefix']}'
          CREDENTIALS = (
            AWS_KEY_ID = '#{credentials['access_key_id']}'
            AWS_SECRET_KEY = '#{credentials['secret_access_key']}'
          )
        SQL
      when "azure_blob"
        stage_sql = <<-SQL
          CREATE OR REPLACE STAGE #{stage_name}
          URL = 'azure://#{data_source.connection_details['container']}/#{data_source.connection_details['prefix']}'
          CREDENTIALS = (
            AZURE_SAS_TOKEN = '#{data_source.credentials['sas_token']}'
          )
        SQL
      end

      @connection.execute(stage_sql)
    end

    def create_automated_task(data_source, staging_info)
      task_sql = <<-SQL
        CREATE OR REPLACE TASK LOAD_#{generate_table_name(data_source)}_TASK
        WAREHOUSE = COMPUTE_WH
        SCHEDULE = '#{data_source.connection_details['schedule'] || '60 MINUTE'}'
        AS
        CALL #{staging_info[:schema]}.MERGE_#{generate_table_name(data_source)}();
      SQL

      @connection.execute(task_sql)
      @connection.execute("ALTER TASK LOAD_#{generate_table_name(data_source)}_TASK RESUME")
    end

    def create_transformation_view(schema, transform)
      sql = <<-SQL
        CREATE OR REPLACE VIEW #{schema}.#{transform[:name]} AS
        #{transform[:sql]}
      SQL

      @connection.execute(sql)
    end
  end

  # BigQuery Loader
  class BigQueryLoader < BaseWarehouseLoader
    def initialize
      super
      require "google/cloud/bigquery"
      @client = Google::Cloud::Bigquery.new(
        project_id: Rails.application.config.bigquery[:project_id],
        credentials: Rails.application.config.bigquery[:credentials]
      )
    end

    def load(data_source, data, options = {})
      dataset_id = options[:dataset] || "raw_data"
      table_id = options[:table_name] || generate_table_name(data_source)

      dataset = @client.dataset(dataset_id) || @client.create_dataset(dataset_id)
      table = dataset.table(table_id) || create_table(dataset, table_id, data)

      # Load data
      load_job = table.load_job data,
        format: options[:format] || "json",
        write_disposition: options[:write_disposition] || "WRITE_APPEND",
        autodetect: options[:autodetect] != false

      load_job.wait_until_done!

      {
        warehouse: "bigquery",
        table: "#{dataset_id}.#{table_id}",
        rows_loaded: load_job.output_rows,
        bytes_processed: load_job.output_bytes
      }
    end

    def create_external_table(data_source, options = {})
      dataset_id = options[:dataset] || "external_data"
      table_id = options[:table_name] || generate_table_name(data_source, "ext")

      dataset = @client.dataset(dataset_id) || @client.create_dataset(dataset_id)

      external_data_config = case data_source.source_type
      when "gcs"
        {
          source_uris: [ "gs://#{data_source.connection_details['bucket']}/#{data_source.connection_details['prefix']}/*" ],
          source_format: data_source.connection_details["file_format"] || "CSV",
          autodetect: true
        }
      when "drive"
        {
          source_uris: [ data_source.connection_details["drive_uri"] ],
          source_format: "GOOGLE_SHEETS"
        }
      end

      table = dataset.create_table table_id do |t|
        t.external = external_data_config
      end

      {
        warehouse: "bigquery",
        table: "#{dataset_id}.#{table_id}",
        external: true
      }
    end

    def create_staging_area(data_source)
      dataset_id = "staging_#{data_source.organization_id}"
      dataset = @client.dataset(dataset_id) || @client.create_dataset(dataset_id)

      # Create data transfer for automated loading
      if data_source.source_type == "gcs"
        transfer_config = create_data_transfer(data_source, dataset_id)
      end

      {
        dataset: dataset_id,
        transfer_config: transfer_config
      }
    end

    def setup_incremental_loading(data_source, staging_info)
      # Create merge query as scheduled query
      merge_query = generate_merge_query(data_source, staging_info)

      # Schedule the query
      schedule_query(merge_query, data_source)
    end

    def create_transformation_layer(data_source, transformations)
      dataset_id = "transformed_#{data_source.organization_id}"
      dataset = @client.dataset(dataset_id) || @client.create_dataset(dataset_id)

      transformations.each do |transform|
        case transform[:type]
        when "view"
          create_view(dataset, transform)
        when "materialized_view"
          create_materialized_view(dataset, transform)
        when "scheduled_query"
          create_scheduled_query(dataset, transform)
        end
      end
    end

    private

    def create_table(dataset, table_id, data)
      schema = infer_bigquery_schema(data)

      dataset.create_table table_id do |t|
        schema.each do |field|
          t.send(field[:type].downcase, field[:name])
        end
        t.timestamp "_loaded_at"
        t.string "_source"
      end
    end

    def infer_bigquery_schema(data)
      schema = infer_schema(data)

      schema.map do |name, type|
        bq_type = case type
        when "INTEGER" then :integer
        when "FLOAT" then :float
        when "BOOLEAN" then :boolean
        when "DATE" then :date
        when "TIMESTAMP" then :timestamp
        when "VARIANT" then :json
        else :string
        end

        { name: name, type: bq_type }
      end
    end
  end

  # Redshift Loader
  class RedshiftLoader < BaseWarehouseLoader
    def initialize
      super
      @connection = establish_redshift_connection
    end

    def load(data_source, data, options = {})
      schema_name = options[:schema] || "raw_data"
      table_name = options[:table_name] || generate_table_name(data_source)

      # Create schema if not exists
      @connection.execute("CREATE SCHEMA IF NOT EXISTS #{schema_name}")

      # Create table
      create_table_from_data(schema_name, table_name, data) unless options[:skip_table_creation]

      # Load data via S3 (most efficient for Redshift)
      if options[:use_s3_copy]
        load_via_s3_copy(schema_name, table_name, data, options)
      else
        load_via_insert(schema_name, table_name, data, options)
      end

      # Analyze table for query optimization
      @connection.execute("ANALYZE #{schema_name}.#{table_name}")

      {
        warehouse: "redshift",
        table: "#{schema_name}.#{table_name}",
        rows_loaded: data.size
      }
    end

    def create_external_table(data_source, options = {})
      schema_name = options[:schema] || "spectrum"
      table_name = options[:table_name] || generate_table_name(data_source, "ext")

      # Create external schema if needed
      create_external_schema(schema_name) unless options[:skip_schema_creation]

      # Create external table
      location = case data_source.source_type
      when "s3"
        "s3://#{data_source.connection_details['bucket']}/#{data_source.connection_details['prefix']}"
      else
        raise NotImplementedError, "External tables only supported for S3 sources"
      end

      sql = <<-SQL
        CREATE EXTERNAL TABLE #{schema_name}.#{table_name} (
          #{options[:columns] || 'data VARCHAR(MAX)'}
        )
        STORED AS #{data_source.connection_details['file_format'] || 'PARQUET'}
        LOCATION '#{location}'
      SQL

      @connection.execute(sql)

      {
        warehouse: "redshift",
        table: "#{schema_name}.#{table_name}",
        external: true
      }
    end

    private

    def establish_redshift_connection
      config = Rails.application.config.redshift

      PG.connect(
        host: config[:host],
        port: config[:port] || 5439,
        dbname: config[:database],
        user: config[:username],
        password: config[:password]
      )
    end

    def load_via_s3_copy(schema_name, table_name, data, options)
      # Upload data to S3 first
      s3_path = upload_to_s3(data)

      # Execute COPY command
      copy_sql = <<-SQL
        COPY #{schema_name}.#{table_name}
        FROM '#{s3_path}'
        IAM_ROLE '#{Rails.application.config.redshift[:iam_role]}'
        FORMAT AS JSON 'auto'
        TIMEFORMAT 'YYYY-MM-DD HH:MI:SS'
      SQL

      @connection.execute(copy_sql)

      # Clean up S3 file
      delete_from_s3(s3_path)
    end
  end

  # Databricks Loader
  class DatabricksLoader < BaseWarehouseLoader
    def initialize
      super
      @client = initialize_databricks_client
    end

    def load(data_source, data, options = {})
      catalog = options[:catalog] || "main"
      schema = options[:schema] || "raw_data"
      table = options[:table_name] || generate_table_name(data_source)

      # Create Delta table
      create_delta_table(catalog, schema, table, data) unless options[:skip_table_creation]

      # Load data
      load_to_delta(catalog, schema, table, data, options)

      {
        warehouse: "databricks",
        table: "#{catalog}.#{schema}.#{table}",
        rows_loaded: data.size,
        format: "delta"
      }
    end

    private

    def initialize_databricks_client
      # Initialize Databricks SQL connector
      require "databricks-sql"

      config = Rails.application.config.databricks

      Databricks::SQL.connect(
        server_hostname: config[:hostname],
        http_path: config[:http_path],
        access_token: config[:access_token]
      )
    end
  end

  # Azure Synapse Loader
  class SynapseLoader < BaseWarehouseLoader
    def initialize
      super
      @connection = establish_synapse_connection
    end

    def load(data_source, data, options = {})
      schema_name = options[:schema] || "raw_data"
      table_name = options[:table_name] || generate_table_name(data_source)

      # Create schema
      @connection.execute("CREATE SCHEMA IF NOT EXISTS #{schema_name}")

      # Create table
      create_table_from_data(schema_name, table_name, data) unless options[:skip_table_creation]

      # Load data via PolyBase or COPY
      if options[:use_polybase]
        load_via_polybase(schema_name, table_name, data, options)
      else
        load_via_copy(schema_name, table_name, data, options)
      end

      {
        warehouse: "synapse",
        table: "#{schema_name}.#{table_name}",
        rows_loaded: data.size
      }
    end

    private

    def establish_synapse_connection
      config = Rails.application.config.synapse

      TinyTDS::Client.new(
        host: config[:host],
        port: config[:port] || 1433,
        database: config[:database],
        username: config[:username],
        password: config[:password],
        azure: true
      )
    end
  end
end
