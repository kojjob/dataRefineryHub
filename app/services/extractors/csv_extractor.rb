# CSV data extractor for local and remote CSV files
# Supports various delimiters, encodings, and large file handling
require "csv"
require "open-uri"
require "net/http"

class CsvExtractor < BaseExtractor
  # Default CSV parsing options
  DEFAULT_OPTIONS = {
    headers: true,
    header_converters: :symbol,
    skip_blanks: true,
    encoding: "UTF-8"
  }.freeze

  COMMON_DELIMITERS = [ ",", "\t", ";", "|" ].freeze
  SUPPORTED_ENCODINGS = %w[UTF-8 ISO-8859-1 Windows-1252 ASCII-8BIT].freeze

  def validate_connection
    source_config = data_source.configuration

    case source_config["source_type"]
    when "file", "local"
      validate_local_file(source_config["file_path"])
    when "url", "remote"
      validate_remote_url(source_config["url"])
    when "s3"
      validate_s3_source(source_config)
    else
      raise ConfigurationError, "Unsupported CSV source type: #{source_config['source_type']}"
    end
  end

  def perform_extraction
    logger.info "Starting CSV extraction for #{data_source.name}"

    source_config = data_source.configuration
    csv_options = build_csv_options(source_config)

    # Get CSV data based on source type
    csv_data = case source_config["source_type"]
    when "file", "local"
                 extract_from_local_file(source_config["file_path"], csv_options)
    when "url", "remote"
                 extract_from_url(source_config["url"], csv_options)
    when "s3"
                 extract_from_s3(source_config, csv_options)
    end

    logger.info "Completed CSV extraction: #{csv_data.count} records"
    csv_data
  end

  def get_schema_info
    source_config = data_source.configuration

    # Read sample rows to infer schema
    sample_size = 100
    sample_data = []

    begin
      csv_options = build_csv_options(source_config).merge(headers: true)

      case source_config["source_type"]
      when "file", "local"
        CSV.foreach(source_config["file_path"], **csv_options) do |row|
          sample_data << row
          break if sample_data.size >= sample_size
        end
      when "url", "remote"
        csv_content = fetch_remote_content(source_config["url"], limit: 50_000) # 50KB sample
        CSV.parse(csv_content, **csv_options) do |row|
          sample_data << row
          break if sample_data.size >= sample_size
        end
      end

      infer_schema_from_sample(sample_data)
    rescue => e
      logger.error "Failed to get schema info: #{e.message}"
      {}
    end
  end

  # Auto-detect CSV format
  def detect_csv_format(file_path_or_content, is_content = false)
    sample = if is_content
               file_path_or_content.lines.first(10).join
    else
               File.open(file_path_or_content, "r:bom|utf-8") { |f| f.read(1024) }
    end

    # Detect delimiter
    delimiter = detect_delimiter(sample)

    # Detect if headers exist
    has_headers = detect_headers(sample, delimiter)

    # Detect encoding
    encoding = detect_encoding(file_path_or_content, is_content)

    {
      delimiter: delimiter,
      headers: has_headers,
      encoding: encoding
    }
  end

  private

  def validate_local_file(file_path)
    unless File.exist?(file_path)
      raise ConnectionError, "CSV file not found: #{file_path}"
    end

    unless File.readable?(file_path)
      raise AuthenticationError, "CSV file not readable: #{file_path}"
    end

    if File.size(file_path) == 0
      raise DataValidationError, "CSV file is empty: #{file_path}"
    end

    # Try to parse first few lines
    CSV.foreach(file_path, **build_csv_options(data_source.configuration)).first(5)

    logger.info "Successfully validated local CSV file: #{file_path}"
  rescue CSV::MalformedCSVError => e
    raise DataValidationError, "Invalid CSV format: #{e.message}"
  end

  def validate_remote_url(url)
    uri = URI.parse(url)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.head(uri.path.empty? ? "/" : uri.path)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise ConnectionError, "Remote CSV not accessible: #{response.code} #{response.message}"
    end

    # Check content type
    content_type = response["content-type"]
    unless content_type.nil? || content_type.include?("text/csv") || content_type.include?("text/plain")
      logger.warn "Unexpected content type for CSV: #{content_type}"
    end

    logger.info "Successfully validated remote CSV URL: #{url}"
  rescue URI::InvalidURIError => e
    raise ConfigurationError, "Invalid URL: #{e.message}"
  rescue => e
    raise ConnectionError, "Failed to validate remote CSV: #{e.message}"
  end

  def validate_s3_source(config)
    # Delegate to CloudStorageExtractor for S3 validation
    cloud_extractor = CloudStorageExtractor.new(data_source)
    cloud_extractor.test_connection
  end

  def extract_from_local_file(file_path, csv_options)
    records = []
    row_number = 0

    # Use streaming for large files
    if File.size(file_path) > 100.megabytes
      extract_large_file(file_path, csv_options) do |batch|
        records.concat(batch)
      end
    else
      CSV.foreach(file_path, **csv_options) do |row|
        row_number += 1
        records << format_csv_record(row, row_number)
      end
    end

    records
  end

  def extract_from_url(url, csv_options)
    records = []
    row_number = 0

    # Download and parse CSV
    csv_content = fetch_remote_content(url)

    CSV.parse(csv_content, **csv_options) do |row|
      row_number += 1
      records << format_csv_record(row, row_number)
    end

    records
  rescue => e
    raise ExtractionError, "Failed to extract from URL: #{e.message}"
  end

  def extract_from_s3(config, csv_options)
    # Use CloudStorageExtractor for S3 files
    cloud_config = data_source.configuration.merge(
      "provider" => "aws_s3",
      "bucket" => config["bucket"],
      "prefix" => config["key"]
    )

    temp_data_source = data_source.dup
    temp_data_source.configuration = cloud_config

    cloud_extractor = CloudStorageExtractor.new(temp_data_source)
    cloud_extractor.extract_data(job_id: extraction_job&.id)
  end

  def extract_large_file(file_path, csv_options)
    batch_size = 10_000
    batch = []
    row_number = 0

    CSV.foreach(file_path, **csv_options) do |row|
      row_number += 1
      batch << format_csv_record(row, row_number)

      if batch.size >= batch_size
        yield batch
        batch = []
      end
    end

    yield batch if batch.any?
  end

  def build_csv_options(config)
    options = DEFAULT_OPTIONS.dup

    # Override with configuration
    options[:col_sep] = config["delimiter"] if config["delimiter"]
    options[:quote_char] = config["quote_char"] if config["quote_char"]
    options[:encoding] = config["encoding"] if config["encoding"]
    options[:headers] = config["headers"] != false

    # Auto-detect if not specified
    if config["auto_detect"] && !config["delimiter"]
      detected_format = detect_csv_format(get_sample_content(config))
      options[:col_sep] = detected_format[:delimiter]
      options[:encoding] = detected_format[:encoding]
    end

    options
  end

  def format_csv_record(row, row_number)
    data = if row.is_a?(CSV::Row)
             row.to_h
    elsif row.is_a?(Array)
             # If no headers, create generic column names
             Hash[row.each_with_index.map { |val, idx| [ "column_#{idx + 1}", val ] }]
    else
             row
    end

    {
      record_type: "csv_row",
      data: data,
      row_number: row_number,
      extracted_at: Time.current
    }
  end

  def fetch_remote_content(url, limit: nil)
    uri = URI.parse(url)

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      request = Net::HTTP::Get.new(uri)

      if limit
        # Stream with limit for sampling
        response_body = ""
        http.request(request) do |response|
          response.read_body do |chunk|
            response_body << chunk
            break if response_body.bytesize >= limit
          end
        end
        response_body
      else
        # Get full content
        response = http.request(request)
        raise ConnectionError, "HTTP Error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
        response.body
      end
    end
  end

  def get_sample_content(config)
    case config["source_type"]
    when "file", "local"
      File.open(config["file_path"], "r:bom|utf-8") { |f| f.read(10_000) }
    when "url", "remote"
      fetch_remote_content(config["url"], limit: 10_000)
    else
      ""
    end
  end

  def detect_delimiter(sample)
    # Count occurrences of common delimiters
    delimiter_counts = COMMON_DELIMITERS.map do |delim|
      count = sample.lines.first(5).map { |line| line.count(delim) }.min || 0
      [ delim, count ]
    end.to_h

    # Return delimiter with most consistent count
    delimiter_counts.max_by { |_, count| count }&.first || ","
  end

  def detect_headers(sample, delimiter)
    lines = sample.lines.first(2)
    return true if lines.size < 2

    # Parse first two rows
    first_row = CSV.parse_line(lines[0], col_sep: delimiter)
    second_row = CSV.parse_line(lines[1], col_sep: delimiter)

    return true unless first_row && second_row

    # Check if first row looks like headers (text) and second row has different types
    first_row.zip(second_row).any? do |header, value|
      header.to_s.match?(/^[a-zA-Z]/) &&
        (value.to_s.match?(/^\d+\.?\d*$/) || value.nil?)
    end
  rescue
    true # Default to assuming headers exist
  end

  def detect_encoding(file_path_or_content, is_content = false)
    require "charlock_holmes" if defined?(CharlockHolmes)

    sample = if is_content
               file_path_or_content[0...10_000]
    else
               File.open(file_path_or_content, "rb") { |f| f.read(10_000) }
    end

    if defined?(CharlockHolmes)
      detection = CharlockHolmes::EncodingDetector.detect(sample)
      detection[:encoding] || "UTF-8"
    else
      # Simple detection based on BOM or common patterns
      case sample[0...3]
      when "\xEF\xBB\xBF"
        "UTF-8"
      when "\xFF\xFE"
        "UTF-16LE"
      when "\xFE\xFF"
        "UTF-16BE"
      else
        "UTF-8" # Default
      end
    end
  rescue
    "UTF-8"
  end

  def infer_schema_from_sample(sample_data)
    return {} if sample_data.empty?

    # Get headers
    headers = if sample_data.first.is_a?(CSV::Row)
                sample_data.first.headers
    else
                sample_data.first.keys
    end

    schema = {}

    headers.each do |header|
      column_values = sample_data.map { |row| row[header] }.compact

      schema[header] = {
        name: header.to_s,
        type: infer_column_type(column_values),
        nullable: column_values.size < sample_data.size,
        samples: column_values.first(5),
        unique_values: column_values.uniq.size
      }
    end

    {
      columns: schema,
      row_count_estimate: nil, # Unknown for CSV
      detected_delimiter: data_source.configuration["delimiter"],
      detected_encoding: data_source.configuration["encoding"]
    }
  end

  def infer_column_type(values)
    return "string" if values.empty?

    # Check if all values match a type
    if values.all? { |v| v.to_s.match?(/^\d+$/) }
      "integer"
    elsif values.all? { |v| v.to_s.match?(/^\d*\.?\d+$/) }
      "float"
    elsif values.all? { |v| v.to_s.match?(/^(true|false|yes|no|1|0)$/i) }
      "boolean"
    elsif values.all? { |v| v.to_s.match?(/^\d{4}-\d{2}-\d{2}/) }
      "date"
    elsif values.all? { |v| v.to_s.match?(/^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}/) }
      "datetime"
    else
      "string"
    end
  end

  # Class methods
  class << self
    def supported_source_type
      "csv"
    end

    def required_fields
      %w[source_type]
    end

    def optional_fields
      %w[file_path url bucket key delimiter encoding headers quote_char auto_detect]
    end

    def supports_incremental_sync?
      false # CSV files typically don't support incremental sync
    end
  end
end
