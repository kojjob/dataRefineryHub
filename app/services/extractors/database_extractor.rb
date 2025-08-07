# DatabaseExtractor
# Generic database extractor supporting PostgreSQL, MySQL, SQL Server, etc.
class DatabaseExtractor < BaseExtractor
  SUPPORTED_DATABASES = %w[postgresql mysql sqlserver sqlite oracle].freeze

  def initialize(data_source)
    super
    @connection_pool = ConnectionPool.new(size: 5, timeout: 5) do
      establish_database_connection
    end
  end

  protected

  def validate_connection
    @connection_pool.with do |connection|
      connection.active?
    end
  rescue => e
    raise ConnectionError, "Database connection failed: #{e.message}"
  end

  def fetch_data(options = {})
    query = build_query(options)

    @connection_pool.with do |connection|
      if options[:streaming]
        stream_query_results(connection, query, options)
      else
        execute_query(connection, query, options)
      end
    end
  end

  def get_schema_info
    @connection_pool.with do |connection|
      case database_type
      when "postgresql"
        get_postgresql_schema(connection)
      when "mysql"
        get_mysql_schema(connection)
      when "sqlserver"
        get_sqlserver_schema(connection)
      else
        get_generic_schema(connection)
      end
    end
  end

  private

  def establish_database_connection
    config = data_source.credentials.symbolize_keys

    case database_type
    when "postgresql"
      require "pg"
      PG.connect(
        host: config[:host],
        port: config[:port] || 5432,
        dbname: config[:database],
        user: config[:username],
        password: config[:password],
        sslmode: config[:ssl_mode] || "prefer"
      )
    when "mysql"
      require "mysql2"
      Mysql2::Client.new(
        host: config[:host],
        port: config[:port] || 3306,
        database: config[:database],
        username: config[:username],
        password: config[:password],
        ssl_mode: config[:ssl_mode] || "preferred"
      )
    when "sqlserver"
      require "tiny_tds"
      TinyTDS::Client.new(
        host: config[:host],
        port: config[:port] || 1433,
        database: config[:database],
        username: config[:username],
        password: config[:password],
        azure: config[:azure] || false
      )
    else
      raise NotImplementedError, "Database type #{database_type} not yet supported"
    end
  end

  def database_type
    data_source.connection_details["database_type"] || "postgresql"
  end

  def build_query(options)
    table = options[:table] || data_source.connection_details["default_table"]

    if options[:custom_query]
      sanitize_query(options[:custom_query])
    elsif options[:incremental] && options[:last_sync_at]
      build_incremental_query(table, options[:last_sync_at], options[:timestamp_column])
    else
      build_full_query(table, options)
    end
  end

  def build_full_query(table, options)
    columns = options[:columns] || "*"
    limit = options[:limit]

    query = "SELECT #{columns} FROM #{quote_identifier(table)}"
    query += " WHERE #{options[:where]}" if options[:where]
    query += " ORDER BY #{options[:order_by]}" if options[:order_by]
    query += " LIMIT #{limit}" if limit

    query
  end

  def build_incremental_query(table, last_sync_at, timestamp_column = "updated_at")
    columns = "*"

    # Return query and params separately for parameterized execution
    query = <<-SQL
      SELECT #{columns}#{' '}
      FROM #{quote_identifier(table)}
      WHERE #{quote_identifier(timestamp_column)} > $1
      ORDER BY #{quote_identifier(timestamp_column)} ASC
    SQL

    { query: query, params: [ last_sync_at.iso8601 ] }
  end

  def quote_identifier(identifier)
    case database_type
    when "mysql"
      "`#{identifier}`"
    when "sqlserver"
      "[#{identifier}]"
    else
      %("#{identifier}")
    end
  end

  def sanitize_query(query)
    # Basic SQL injection prevention
    # In production, use proper parameterized queries
    query.gsub(/;.*$/, "")
  end

  def execute_query(connection, query, options)
    results = []
    params = options[:params] || []

    case database_type
    when "postgresql"
      if params.any?
        result = connection.exec_params(query, params)
      else
        result = connection.exec(query)
      end
      result.each { |row| results << row }
    when "mysql"
      if params.any?
        statement = connection.prepare(query)
        result = statement.execute(*params)
        result.each { |row| results << row }
        statement.close if statement
      else
        connection.query(query).each { |row| results << row }
      end
    when "sqlserver"
      if params.any?
        # Use parameterized queries instead of string substitution
        # This prevents SQL injection attacks
        begin
          # TinyTDS supports parameterized queries through exec_sp or properly escaped queries
          # Convert PostgreSQL-style $1, $2 parameters to SQL Server ? placeholders
          param_query = query.gsub(/\$\d+/, "?")
          result = connection.execute(param_query, *params)
        rescue => e
          Rails.logger.error "SQL Server parameterized query failed: #{e.message}"
          # If parameterized query fails, raise error instead of falling back to unsafe substitution
          raise "Database query failed: parameterized queries required for security"
        end
      else
        result = connection.execute(query)
      end
      result.each { |row| results << row }
    end

    results
  end

  def stream_query_results(connection, query, options)
    batch_size = options[:batch_size] || 1000

    case database_type
    when "postgresql"
      connection.send_query(query)
      connection.set_single_row_mode

      batch = []
      while connection.get_result
        while row = connection.get_result
          batch << row

          if batch.size >= batch_size
            yield batch
            batch = []
          end
        end
      end

      yield batch if batch.any?
    when "mysql"
      connection.query(query, stream: true).each_slice(batch_size) do |batch|
        yield batch
      end
    else
      # Fallback to non-streaming
      execute_query(connection, query, options).each_slice(batch_size) do |batch|
        yield batch
      end
    end
  end

  def get_postgresql_schema(connection)
    query = <<-SQL
      SELECT#{' '}
        table_name,
        column_name,
        data_type,
        is_nullable,
        column_default
      FROM information_schema.columns
      WHERE table_schema = 'public'
      ORDER BY table_name, ordinal_position
    SQL

    schema = {}
    connection.exec(query).each do |row|
      table = row["table_name"]
      schema[table] ||= []
      schema[table] << {
        name: row["column_name"],
        type: row["data_type"],
        nullable: row["is_nullable"] == "YES",
        default: row["column_default"]
      }
    end

    schema
  end

  def get_mysql_schema(connection)
    database = data_source.credentials["database"]

    query = <<-SQL
      SELECT#{' '}
        TABLE_NAME as table_name,
        COLUMN_NAME as column_name,
        DATA_TYPE as data_type,
        IS_NULLABLE as is_nullable,
        COLUMN_DEFAULT as column_default
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = ?
      ORDER BY TABLE_NAME, ORDINAL_POSITION
    SQL

    schema = {}
    statement = connection.prepare(query)
    result = statement.execute(database)
    result.each do |row|
      table = row["table_name"]
      schema[table] ||= []
      schema[table] << {
        name: row["column_name"],
        type: row["data_type"],
        nullable: row["is_nullable"] == "YES",
        default: row["column_default"]
      }
    end
    statement.close if statement

    schema
  end

  def get_sqlserver_schema(connection)
    query = <<-SQL
      SELECT#{' '}
        t.name AS table_name,
        c.name AS column_name,
        ty.name AS data_type,
        c.is_nullable,
        dc.definition AS column_default
      FROM sys.columns c
      JOIN sys.tables t ON c.object_id = t.object_id
      JOIN sys.types ty ON c.user_type_id = ty.user_type_id
      LEFT JOIN sys.default_constraints dc ON c.default_object_id = dc.object_id
      ORDER BY t.name, c.column_id
    SQL

    schema = {}
    result = connection.execute(query)
    result.each do |row|
      table = row["table_name"]
      schema[table] ||= []
      schema[table] << {
        name: row["column_name"],
        type: row["data_type"],
        nullable: row["is_nullable"] == 1,
        default: row["column_default"]
      }
    end

    result.cancel
    schema
  end

  def get_generic_schema(connection)
    # Fallback schema detection
    {}
  end

  def cleanup
    @connection_pool.shutdown(&:close) if @connection_pool
    super
  end
end
