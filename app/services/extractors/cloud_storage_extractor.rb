# CloudStorageExtractor
# Extracts data from cloud storage services (S3, GCS, Azure Blob)
class CloudStorageExtractor < BaseExtractor
  SUPPORTED_PROVIDERS = %w[aws_s3 google_cloud_storage azure_blob].freeze
  SUPPORTED_FORMATS = %w[csv json xml parquet avro excel].freeze

  def initialize(data_source)
    super
    @provider = data_source.connection_details["provider"]
    @bucket = data_source.connection_details["bucket"]
    @prefix = data_source.connection_details["prefix"]

    initialize_client
  end

  protected

  def validate_connection
    case @provider
    when "aws_s3"
      validate_s3_connection
    when "google_cloud_storage"
      validate_gcs_connection
    when "azure_blob"
      validate_azure_connection
    else
      raise NotImplementedError, "Provider #{@provider} not supported"
    end
  end

  def fetch_data(options = {})
    files = list_files(options)

    if options[:parallel_downloads]
      fetch_files_parallel(files, options)
    else
      fetch_files_sequential(files, options)
    end
  end

  def get_schema_info
    # For cloud storage, we might infer schema from file samples
    sample_file = list_files(limit: 1).first
    return {} unless sample_file

    content = download_file(sample_file[:key])
    infer_schema_from_content(content, sample_file[:format])
  end

  private

  def initialize_client
    case @provider
    when "aws_s3"
      initialize_s3_client
    when "google_cloud_storage"
      initialize_gcs_client
    when "azure_blob"
      initialize_azure_client
    end
  end

  # AWS S3 Implementation
  def initialize_s3_client
    require "aws-sdk-s3"

    credentials = data_source.credentials

    @client = Aws::S3::Client.new(
      region: credentials["region"] || "us-east-1",
      access_key_id: credentials["access_key_id"],
      secret_access_key: credentials["secret_access_key"],
      session_token: credentials["session_token"] # For temporary credentials
    )

    @s3_resource = Aws::S3::Resource.new(client: @client)
  end

  def validate_s3_connection
    @client.head_bucket(bucket: @bucket)
  rescue Aws::S3::Errors::NoSuchBucket
    raise ConnectionError, "S3 bucket '#{@bucket}' not found"
  rescue Aws::S3::Errors::Forbidden
    raise AuthenticationError, "Access denied to S3 bucket '#{@bucket}'"
  rescue => e
    raise ConnectionError, "S3 connection failed: #{e.message}"
  end

  def list_s3_files(options)
    files = []

    list_options = {
      bucket: @bucket,
      prefix: build_prefix(options),
      max_keys: options[:limit] || 1000
    }

    if options[:after_marker]
      list_options[:start_after] = options[:after_marker]
    end

    response = @client.list_objects_v2(list_options)

    response.contents.each do |object|
      next if object.key.end_with?("/") # Skip directories
      next unless file_matches_pattern?(object.key, options[:pattern])

      files << {
        key: object.key,
        size: object.size,
        last_modified: object.last_modified,
        etag: object.etag,
        format: detect_file_format(object.key)
      }
    end

    files
  end

  def download_s3_file(key)
    object = @s3_resource.bucket(@bucket).object(key)

    # For large files, use streaming
    if object.content_length > 100.megabytes
      stream_s3_file(object)
    else
      object.get.body.read
    end
  end

  def stream_s3_file(object)
    temp_file = Tempfile.new([ "s3_download", File.extname(object.key) ])

    object.download_file(temp_file.path)

    begin
      yield temp_file if block_given?
      File.read(temp_file.path) unless block_given?
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  # Google Cloud Storage Implementation
  def initialize_gcs_client
    require "google/cloud/storage"

    credentials = data_source.credentials

    @client = Google::Cloud::Storage.new(
      project_id: credentials["project_id"],
      credentials: JSON.parse(credentials["service_account_json"])
    )

    @bucket_object = @client.bucket(@bucket)
  end

  def validate_gcs_connection
    raise ConnectionError, "GCS bucket '#{@bucket}' not found" unless @bucket_object
  rescue => e
    raise ConnectionError, "GCS connection failed: #{e.message}"
  end

  def list_gcs_files(options)
    files = []

    prefix = build_prefix(options)
    file_list = @bucket_object.files(prefix: prefix, max: options[:limit])

    file_list.each do |file|
      next unless file_matches_pattern?(file.name, options[:pattern])

      files << {
        key: file.name,
        size: file.size,
        last_modified: file.created_at,
        etag: file.etag,
        format: detect_file_format(file.name)
      }
    end

    files
  end

  def download_gcs_file(key)
    file = @bucket_object.file(key)

    # For large files, use streaming
    if file.size > 100.megabytes
      stream_gcs_file(file)
    else
      file.download.read
    end
  end

  def stream_gcs_file(file)
    temp_file = Tempfile.new([ "gcs_download", File.extname(file.name) ])

    file.download(temp_file.path)

    begin
      yield temp_file if block_given?
      File.read(temp_file.path) unless block_given?
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  # Azure Blob Storage Implementation
  def initialize_azure_client
    require "azure/storage/blob"

    credentials = data_source.credentials

    @client = Azure::Storage::Blob::BlobService.create(
      storage_account_name: credentials["account_name"],
      storage_access_key: credentials["account_key"]
    )
  end

  def validate_azure_connection
    @client.list_containers(max_results: 1)
  rescue => e
    raise ConnectionError, "Azure Blob connection failed: #{e.message}"
  end

  def list_azure_files(options)
    files = []

    prefix = build_prefix(options)

    blobs = @client.list_blobs(
      @bucket,
      prefix: prefix,
      max_results: options[:limit]
    )

    blobs.each do |blob|
      next unless file_matches_pattern?(blob.name, options[:pattern])

      files << {
        key: blob.name,
        size: blob.properties[:content_length],
        last_modified: blob.properties[:last_modified],
        etag: blob.properties[:etag],
        format: detect_file_format(blob.name)
      }
    end

    files
  end

  def download_azure_file(key)
    blob, content = @client.get_blob(@bucket, key)
    content
  end

  # Common methods
  def list_files(options = {})
    case @provider
    when "aws_s3"
      list_s3_files(options)
    when "google_cloud_storage"
      list_gcs_files(options)
    when "azure_blob"
      list_azure_files(options)
    end
  end

  def download_file(key)
    case @provider
    when "aws_s3"
      download_s3_file(key)
    when "google_cloud_storage"
      download_gcs_file(key)
    when "azure_blob"
      download_azure_file(key)
    end
  end

  def build_prefix(options)
    prefix_parts = [ @prefix ]

    # Add date-based partitioning if configured
    if options[:date_partition]
      date = options[:date] || Date.current
      partition_format = data_source.connection_details["partition_format"] || "year=%Y/month=%m/day=%d"
      prefix_parts << date.strftime(partition_format)
    end

    prefix_parts.compact.join("/")
  end

  def file_matches_pattern?(filename, pattern)
    return true unless pattern

    File.fnmatch?(pattern, filename)
  end

  def detect_file_format(filename)
    extension = File.extname(filename).downcase.delete(".")

    case extension
    when "csv", "tsv"
      "csv"
    when "json", "jsonl"
      "json"
    when "xml"
      "xml"
    when "parquet"
      "parquet"
    when "avro"
      "avro"
    when "xlsx", "xls"
      "excel"
    else
      "unknown"
    end
  end

  def fetch_files_sequential(files, options)
    all_data = []

    files.each do |file|
      @logger.info "Processing file: #{file[:key]}"

      begin
        content = download_file(file[:key])
        parsed_data = parse_file_content(content, file[:format], options)

        # Add file metadata to each record
        parsed_data.each do |record|
          record["_source_file"] = file[:key]
          record["_file_modified"] = file[:last_modified]
        end

        all_data.concat(parsed_data)
      rescue => e
        @logger.error "Failed to process file #{file[:key]}: #{e.message}"
        raise if options[:fail_on_error]
      end
    end

    all_data
  end

  def fetch_files_parallel(files, options)
    all_data = Concurrent::Array.new
    pool_size = options[:parallel_workers] || 5

    Parallel.each(files, in_threads: pool_size) do |file|
      @logger.info "Processing file: #{file[:key]}"

      begin
        content = download_file(file[:key])
        parsed_data = parse_file_content(content, file[:format], options)

        parsed_data.each do |record|
          record["_source_file"] = file[:key]
          record["_file_modified"] = file[:last_modified]
        end

        all_data.concat(parsed_data)
      rescue => e
        @logger.error "Failed to process file #{file[:key]}: #{e.message}"
        raise if options[:fail_on_error]
      end
    end

    all_data.to_a
  end

  def parse_file_content(content, format, options)
    case format
    when "csv"
      parse_csv(content, options)
    when "json"
      parse_json(content, options)
    when "xml"
      parse_xml(content, options)
    when "parquet"
      parse_parquet(content, options)
    when "excel"
      parse_excel(content, options)
    else
      raise NotImplementedError, "File format #{format} not supported"
    end
  end

  def parse_csv(content, options)
    require "csv"

    csv_options = {
      headers: options[:headers] != false,
      col_sep: options[:delimiter] || ",",
      encoding: options[:encoding] || "UTF-8"
    }

    CSV.parse(content, **csv_options).map(&:to_h)
  end

  def parse_json(content, options)
    data = JSON.parse(content)

    # Handle both array and object responses
    if data.is_a?(Array)
      data
    elsif data.is_a?(Hash) && options[:data_path]
      # Extract nested data if path is specified
      data.dig(*options[:data_path].split(".")) || []
    else
      [ data ]
    end
  end

  def parse_xml(content, options)
    require "nokogiri"

    doc = Nokogiri::XML(content)
    records = []

    # Find record elements based on configuration
    record_xpath = options[:record_xpath] || "//record"

    doc.xpath(record_xpath).each do |node|
      record = {}

      # Extract all child elements as fields
      node.children.each do |child|
        next unless child.element?
        record[child.name] = child.text
      end

      # Include attributes if configured
      if options[:include_attributes]
        node.attributes.each do |name, attr|
          record["@#{name}"] = attr.value
        end
      end

      records << record
    end

    records
  end

  def parse_parquet(content, options)
    require "parquet"

    # Write content to temp file as parquet gem requires file path
    temp_file = Tempfile.new([ "parquet", ".parquet" ])
    temp_file.binmode
    temp_file.write(content)
    temp_file.rewind

    begin
      Parquet.read(temp_file.path)
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  def parse_excel(content, options)
    require "roo"

    temp_file = Tempfile.new([ "excel", ".xlsx" ])
    temp_file.binmode
    temp_file.write(content)
    temp_file.rewind

    begin
      spreadsheet = Roo::Spreadsheet.open(temp_file.path)
      sheet = options[:sheet] || spreadsheet.sheets.first

      # Convert to array of hashes
      header = spreadsheet.row(1)
      rows = []

      (2..spreadsheet.last_row).each do |i|
        row_data = spreadsheet.row(i)
        rows << Hash[header.zip(row_data)]
      end

      rows
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  def infer_schema_from_content(content, format)
    sample_data = parse_file_content(content, format, limit: 100)
    return {} if sample_data.empty?

    schema = {}

    # Analyze first 100 records to infer types
    sample_data.each do |record|
      record.each do |field, value|
        schema[field] ||= {
          name: field,
          type: infer_field_type(value),
          nullable: false,
          samples: []
        }

        schema[field][:nullable] = true if value.nil?
        schema[field][:samples] << value if schema[field][:samples].size < 5
      end
    end

    schema
  end

  def infer_field_type(value)
    case value
    when Integer
      "integer"
    when Float
      "float"
    when TrueClass, FalseClass
      "boolean"
    when Date, DateTime, Time
      "datetime"
    when NilClass
      "unknown"
    else
      "string"
    end
  end
end
