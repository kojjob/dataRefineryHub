# PostgreSQL data extractor with advanced features
# Supports incremental sync, schema detection, and efficient data extraction
class PostgresqlExtractor < DatabaseExtractor
  # PostgreSQL-specific configurations
  PG_CONNECTION_DEFAULTS = {
    port: 5432,
    sslmode: "prefer",
    connect_timeout: 10,
    statement_timeout: "300s",
    idle_in_transaction_session_timeout: "30s"
  }.freeze

  SYSTEM_SCHEMAS = %w[pg_catalog information_schema pg_toast].freeze

  def initialize(data_source)
    super
    @connection_pool = ConnectionPool.new(size: 5, timeout: 5) do
      establish_postgresql_connection
    end
  end

  def validate_connection
    @connection_pool.with do |conn|
      # Test connection with simple query
      result = conn.exec("SELECT version()")
      version_info = result[0]["version"]

      logger.info "Connected to PostgreSQL: #{version_info}"

      # Verify database exists and we have access
      validate_database_access(conn)

      { status: :success, message: "Connected successfully", version: version_info }
    end
  rescue PG::Error => e
    handle_pg_error(e)
  end

  def perform_extraction
    logger.info "Starting PostgreSQL extraction for #{data_source.name}"

    extraction_config = data_source.configuration
    tables = extraction_config["tables"] || discover_tables

    all_data = []

    tables.each do |table|
      logger.info "Extracting data from table: #{table}"

      table_data = extract_table_data(table, extraction_config)
      logger.info "Extracted #{table_data.count} records from #{table}"

      all_data.concat(table_data)
    end

    logger.info "Completed PostgreSQL extraction: #{all_data.count} total records"
    all_data
  end

  def get_schema_info
    @connection_pool.with do |conn|
      schema = {}

      # Get all user tables
      tables_query = <<-SQL
        SELECT#{' '}
          schemaname,
          tablename
        FROM pg_tables
        WHERE schemaname NOT IN (#{SYSTEM_SCHEMAS.map { |s| "'#{s}'" }.join(', ')})
        ORDER BY schemaname, tablename
      SQL

      tables = conn.exec(tables_query)

      tables.each do |table_row|
        schema_name = table_row["schemaname"]
        table_name = table_row["tablename"]
        full_table_name = "#{schema_name}.#{table_name}"

        # Get column information
        columns_query = <<-SQL
          SELECT#{' '}
            column_name,
            data_type,
            character_maximum_length,
            numeric_precision,
            numeric_scale,
            is_nullable,
            column_default,
            ordinal_position
          FROM information_schema.columns
          WHERE table_schema = $1 AND table_name = $2
          ORDER BY ordinal_position
        SQL

        columns = conn.exec_params(columns_query, [ schema_name, table_name ])

        # Get primary key information
        pk_query = <<-SQL
          SELECT a.attname
          FROM pg_index i
          JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
          WHERE i.indrelid = $1::regclass AND i.indisprimary
        SQL

        pk_columns = conn.exec_params(pk_query, [ full_table_name ]).map { |r| r["attname"] }

        # Get row count estimate
        count_query = <<-SQL
          SELECT reltuples::BIGINT AS estimate
          FROM pg_class
          WHERE oid = $1::regclass
        SQL

        row_count = conn.exec_params(count_query, [ full_table_name ])[0]["estimate"].to_i

        schema[full_table_name] = {
          columns: columns.map do |col|
            {
              name: col["column_name"],
              type: format_data_type(col),
              nullable: col["is_nullable"] == "YES",
              default: col["column_default"],
              primary_key: pk_columns.include?(col["column_name"])
            }
          end,
          row_count_estimate: row_count,
          schema: schema_name,
          table: table_name
        }
      end

      schema
    end
  rescue PG::Error => e
    logger.error "Failed to get schema info: #{e.message}"
    {}
  end

  # Get sample data from a table
  def get_sample_data(table_name, limit = 10)
    @connection_pool.with do |conn|
      query = "SELECT * FROM #{quote_identifier(table_name)} LIMIT $1"
      result = conn.exec_params(query, [ limit ])

      result.map { |row| row.to_h }
    end
  rescue PG::Error => e
    logger.error "Failed to get sample data: #{e.message}"
    []
  end

  # PostgreSQL-specific features
  def supports_streaming?
    true
  end

  def supports_parallel_extraction?
    true
  end

  def supports_incremental_sync?
    true
  end

  private

  def establish_postgresql_connection
    config = data_source.configuration.symbolize_keys

    connection_params = PG_CONNECTION_DEFAULTS.merge(
      host: config[:host],
      port: config[:port] || PG_CONNECTION_DEFAULTS[:port],
      dbname: config[:database],
      user: config[:username],
      password: config[:password]
    )

    # Add SSL configuration if provided
    if config[:ssl_mode]
      connection_params[:sslmode] = config[:ssl_mode]
      connection_params[:sslcert] = config[:ssl_cert] if config[:ssl_cert]
      connection_params[:sslkey] = config[:ssl_key] if config[:ssl_key]
      connection_params[:sslrootcert] = config[:ssl_root_cert] if config[:ssl_root_cert]
    end

    PG.connect(connection_params)
  end

  def validate_database_access(conn)
    # Check if we can query basic information
    conn.exec("SELECT current_database(), current_user")

    # Verify we have at least SELECT permission on some tables
    result = conn.exec(<<-SQL)
      SELECT COUNT(*) as accessible_tables
      FROM information_schema.tables
      WHERE table_schema NOT IN (#{SYSTEM_SCHEMAS.map { |s| "'#{s}'" }.join(', ')})
        AND table_type = 'BASE TABLE'
    SQL

    accessible_tables = result[0]["accessible_tables"].to_i

    if accessible_tables == 0
      raise AuthenticationError, "No accessible tables found. Check database permissions."
    end
  end

  def discover_tables
    @connection_pool.with do |conn|
      query = <<-SQL
        SELECT#{' '}
          schemaname || '.' || tablename as full_table_name
        FROM pg_tables
        WHERE schemaname NOT IN (#{SYSTEM_SCHEMAS.map { |s| "'#{s}'" }.join(', ')})
        ORDER BY schemaname, tablename
      SQL

      result = conn.exec(query)
      result.map { |row| row["full_table_name"] }
    end
  end

  def extract_table_data(table, config)
    @connection_pool.with do |conn|
      records = []

      # Build query based on configuration
      query_options = build_extraction_query(table, config)

      if config["use_streaming"] && supports_streaming?
        # Use cursor for large datasets
        extract_with_cursor(conn, table, query_options) do |batch|
          records.concat(batch)
        end
      else
        # Regular extraction
        result = conn.exec(query_options[:query], query_options[:params])

        result.each do |row|
          records << {
            record_type: sanitize_table_name(table),
            table_name: table,
            data: row.to_h,
            extracted_at: Time.current
          }
        end
      end

      records
    end
  end

  def build_extraction_query(table, config)
    columns = config["columns"] || [ "*" ]
    where_clause = config["where_clause"]
    order_by = config["order_by"]
    limit = config["limit"]

    # Handle incremental sync
    if config["incremental_sync"] && data_source.last_sync_at
      timestamp_column = config["timestamp_column"] || "updated_at"
      incremental_where = "#{quote_identifier(timestamp_column)} > $1"

      where_clause = where_clause ? "(#{where_clause}) AND #{incremental_where}" : incremental_where
      params = [ data_source.last_sync_at ]
    else
      params = []
    end

    # Build query
    query_parts = [
      "SELECT #{columns.join(', ')}",
      "FROM #{quote_identifier(table)}"
    ]

    query_parts << "WHERE #{where_clause}" if where_clause
    query_parts << "ORDER BY #{order_by}" if order_by
    query_parts << "LIMIT #{limit}" if limit

    {
      query: query_parts.join(" "),
      params: params
    }
  end

  def extract_with_cursor(conn, table, query_options)
    cursor_name = "cursor_#{SecureRandom.hex(8)}"
    batch_size = 1000

    begin
      # Start transaction
      conn.exec("BEGIN")

      # Declare cursor
      declare_query = "DECLARE #{cursor_name} CURSOR FOR #{query_options[:query]}"
      conn.exec_params(declare_query, query_options[:params])

      # Fetch in batches
      loop do
        result = conn.exec("FETCH #{batch_size} FROM #{cursor_name}")
        break if result.count == 0

        batch = result.map do |row|
          {
            record_type: sanitize_table_name(table),
            table_name: table,
            data: row.to_h,
            extracted_at: Time.current
          }
        end

        yield batch
      end
    ensure
      # Clean up
      conn.exec("CLOSE #{cursor_name}") rescue nil
      conn.exec("COMMIT") rescue nil
    end
  end

  def format_data_type(column)
    base_type = column["data_type"]

    case base_type
    when "character varying"
      max_length = column["character_maximum_length"]
      max_length ? "varchar(#{max_length})" : "varchar"
    when "numeric"
      precision = column["numeric_precision"]
      scale = column["numeric_scale"]
      if precision && scale
        "numeric(#{precision},#{scale})"
      else
        "numeric"
      end
    when "character"
      max_length = column["character_maximum_length"]
      "char(#{max_length || 1})"
    else
      base_type
    end
  end

  def quote_identifier(identifier)
    # Handle schema.table format
    if identifier.include?(".")
      parts = identifier.split(".")
      parts.map { |part| %("#{part}") }.join(".")
    else
      %("#{identifier}")
    end
  end

  def sanitize_table_name(table_name)
    # Remove schema prefix for record type
    table_name.split(".").last.downcase.gsub(/[^a-z0-9_]/, "_")
  end

  def handle_pg_error(error)
    case error
    when PG::ConnectionBad
      raise ConnectionError, "Failed to connect to PostgreSQL: #{error.message}"
    when PG::InsufficientPrivilege
      raise AuthenticationError, "Insufficient privileges: #{error.message}"
    when PG::UndefinedTable
      raise ConnectionError, "Table not found: #{error.message}"
    when PG::InvalidPassword
      raise AuthenticationError, "Invalid password"
    else
      raise ConnectionError, "PostgreSQL error: #{error.message}"
    end
  end

  # Class methods
  class << self
    def supported_source_type
      "postgresql"
    end

    def required_fields
      %w[host database username password]
    end

    def optional_fields
      %w[port ssl_mode ssl_cert ssl_key ssl_root_cert schema tables]
    end
  end
end
