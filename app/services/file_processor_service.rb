class FileProcessorService
  include ActiveModel::Model

  attr_accessor :data_source, :file, :user

  SUPPORTED_EXTENSIONS = %w[.csv .xlsx .xls .json .txt .xml .parquet .tsv .yaml .yml].freeze

  def initialize(data_source:, file:, user:)
    @data_source = data_source
    @file = file
    @user = user
  end

  def process!
    validate_file!

    case file_extension
    when ".csv"
      process_csv_file
    when ".xlsx", ".xls"
      process_excel_file
    when ".json"
      process_json_file
    when ".txt"
      process_text_file
    when ".xml"
      process_xml_file
    when ".parquet"
      process_parquet_file
    when ".tsv"
      process_tsv_file
    when ".yaml", ".yml"
      process_yaml_file
    else
      raise UnsupportedFileTypeError, "Unsupported file type: #{file_extension}"
    end
  end

  def preview_data(limit: 10)
    case file_extension
    when ".csv"
      preview_csv_data(limit)
    when ".xlsx", ".xls"
      preview_excel_data(limit)
    when ".json"
      preview_json_data(limit)
    when ".xml"
      preview_xml_data(limit)
    when ".parquet"
      preview_parquet_data(limit)
    when ".tsv"
      preview_tsv_data(limit)
    when ".yaml", ".yml"
      preview_yaml_data(limit)
    else
      []
    end
  end

  def analyze_structure
    case file_extension
    when ".csv"
      analyze_csv_structure
    when ".xlsx", ".xls"
      analyze_excel_structure
    when ".json"
      analyze_json_structure
    when ".xml"
      analyze_xml_structure
    when ".parquet"
      analyze_parquet_structure
    when ".tsv"
      analyze_tsv_structure
    when ".yaml", ".yml"
      analyze_yaml_structure
    else
      {}
    end
  end

  private

  def validate_file!
    raise ArgumentError, "File is required" unless file
    raise ArgumentError, "Data source is required" unless data_source

    unless SUPPORTED_EXTENSIONS.include?(file_extension)
      raise UnsupportedFileTypeError, "Unsupported file extension: #{file_extension}"
    end

    if file_size > 50.megabytes
      raise FileSizeError, "File size exceeds 50MB limit"
    end
  end

  def file_extension
    @file_extension ||= File.extname(original_filename).downcase
  end

  def original_filename
    @original_filename ||= file.respond_to?(:original_filename) ? file.original_filename : file.filename.to_s
  end

  def file_size
    @file_size ||= file.respond_to?(:size) ? file.size : file.blob.byte_size
  end

  def file_path
    @file_path ||= if file.respond_to?(:tempfile)
                     file.tempfile.path
    elsif file.respond_to?(:path)
                     file.path
    else
                     # For Active Storage attachments
                     file.download
    end
  end

  # CSV Processing
  def process_csv_file
    records = []

    begin
      SmarterCSV.process(file_path, {
        chunk_size: 100,
        remove_empty_values: false,
        strip_whitespace: false
      }) do |chunk|
        chunk.each do |row_data|
          records << create_raw_data_record(row_data, "csv_row")
        end
      end
    rescue => e
      Rails.logger.error "CSV processing error: #{e.message}"
      raise FileProcessingError, "Failed to process CSV file: #{e.message}"
    end

    {
      total_records: records.length,
      sample_data: records.first(5),
      processing_summary: generate_processing_summary(records)
    }
  end

  def preview_csv_data(limit)
    return [] unless File.exist?(file_path)

    SmarterCSV.process(file_path, {
      chunk_size: limit,
      remove_empty_values: false
    }).first(limit)
  rescue => e
    Rails.logger.error "CSV preview error: #{e.message}"
    []
  end

  def analyze_csv_structure
    return {} unless File.exist?(file_path)

    begin
      # Read first few rows to analyze structure
      sample_data = SmarterCSV.process(file_path, chunk_size: 100).first(100)

      return {} if sample_data.empty?

      headers = sample_data.first.keys
      column_analysis = {}

      headers.each do |header|
        column_data = sample_data.map { |row| row[header] }.compact

        column_analysis[header] = {
          data_type: detect_column_type(column_data),
          sample_values: column_data.first(5),
          null_count: sample_data.count { |row| row[header].blank? },
          unique_count: column_data.uniq.length
        }
      end

      {
        total_rows: sample_data.length,
        total_columns: headers.length,
        headers: headers,
        column_analysis: column_analysis,
        suggested_transformations: suggest_transformations(column_analysis)
      }
    rescue => e
      Rails.logger.error "CSV structure analysis error: #{e.message}"
      {}
    end
  end

  # Excel Processing
  def process_excel_file
    records = []

    begin
      workbook = Roo::Spreadsheet.open(file_path)
      default_sheet = workbook.default_sheet

      headers = workbook.row(1).map(&:to_s)

      (2..workbook.last_row).each do |row_num|
        row_data = {}
        headers.each_with_index do |header, index|
          row_data[header.underscore.to_sym] = workbook.cell(row_num, index + 1)
        end

        records << create_raw_data_record(row_data, "excel_row")
      end
    rescue => e
      Rails.logger.error "Excel processing error: #{e.message}"
      raise FileProcessingError, "Failed to process Excel file: #{e.message}"
    end

    {
      total_records: records.length,
      sample_data: records.first(5),
      processing_summary: generate_processing_summary(records)
    }
  end

  def preview_excel_data(limit)
    return [] unless File.exist?(file_path)

    begin
      workbook = Roo::Spreadsheet.open(file_path)
      headers = workbook.row(1).map(&:to_s)

      preview_data = []
      (2..[ workbook.last_row, limit + 1 ].min).each do |row_num|
        row_data = {}
        headers.each_with_index do |header, index|
          row_data[header.underscore.to_sym] = workbook.cell(row_num, index + 1)
        end
        preview_data << row_data
      end

      preview_data
    rescue => e
      Rails.logger.error "Excel preview error: #{e.message}"
      []
    end
  end

  def analyze_excel_structure
    return {} unless File.exist?(file_path)

    begin
      workbook = Roo::Spreadsheet.open(file_path)
      headers = workbook.row(1).map(&:to_s)

      # Sample first 100 rows for analysis
      sample_data = []
      (2..[ workbook.last_row, 101 ].min).each do |row_num|
        row_data = {}
        headers.each_with_index do |header, index|
          row_data[header.underscore.to_sym] = workbook.cell(row_num, index + 1)
        end
        sample_data << row_data
      end

      column_analysis = {}
      headers.each do |header|
        header_sym = header.underscore.to_sym
        column_data = sample_data.map { |row| row[header_sym] }.compact

        column_analysis[header] = {
          data_type: detect_column_type(column_data),
          sample_values: column_data.first(5),
          null_count: sample_data.count { |row| row[header_sym].blank? },
          unique_count: column_data.uniq.length
        }
      end

      {
        total_rows: workbook.last_row - 1, # Exclude header row
        total_columns: headers.length,
        headers: headers,
        column_analysis: column_analysis,
        sheet_names: workbook.sheets,
        suggested_transformations: suggest_transformations(column_analysis)
      }
    rescue => e
      Rails.logger.error "Excel structure analysis error: #{e.message}"
      {}
    end
  end

  # JSON Processing
  def process_json_file
    records = []

    begin
      file_content = File.read(file_path)
      json_data = JSON.parse(file_content)

      case json_data
      when Array
        json_data.each_with_index do |item, index|
          records << create_raw_data_record(item, "json_item", { index: index })
        end
      when Hash
        # Single object
        records << create_raw_data_record(json_data, "json_object")
      else
        raise FileProcessingError, "Unsupported JSON structure"
      end
    rescue JSON::ParserError => e
      raise FileProcessingError, "Invalid JSON format: #{e.message}"
    rescue => e
      Rails.logger.error "JSON processing error: #{e.message}"
      raise FileProcessingError, "Failed to process JSON file: #{e.message}"
    end

    {
      total_records: records.length,
      sample_data: records.first(5),
      processing_summary: generate_processing_summary(records)
    }
  end

  def preview_json_data(limit)
    return [] unless File.exist?(file_path)

    begin
      file_content = File.read(file_path)
      json_data = JSON.parse(file_content)

      case json_data
      when Array
        json_data.first(limit)
      when Hash
        [ json_data ]
      else
        []
      end
    rescue => e
      Rails.logger.error "JSON preview error: #{e.message}"
      []
    end
  end

  def analyze_json_structure
    return {} unless File.exist?(file_path)

    begin
      file_content = File.read(file_path)
      json_data = JSON.parse(file_content)

      case json_data
      when Array
        return {} if json_data.empty?

        sample_items = json_data.first(100)
        all_keys = sample_items.flat_map(&:keys).uniq

        column_analysis = {}
        all_keys.each do |key|
          values = sample_items.map { |item| item[key] }.compact

          column_analysis[key] = {
            data_type: detect_column_type(values),
            sample_values: values.first(5),
            null_count: sample_items.count { |item| item[key].nil? },
            unique_count: values.uniq.length
          }
        end

        {
          structure_type: "array",
          total_items: json_data.length,
          total_fields: all_keys.length,
          fields: all_keys,
          column_analysis: column_analysis
        }
      when Hash
        {
          structure_type: "object",
          total_fields: json_data.keys.length,
          fields: json_data.keys,
          sample_data: json_data
        }
      end
    rescue => e
      Rails.logger.error "JSON structure analysis error: #{e.message}"
      {}
    end
  end

  # Text Processing
  def process_text_file
    begin
      file_content = File.read(file_path)
      lines = file_content.lines.map(&:strip).reject(&:empty?)

      records = lines.each_with_index.map do |line, index|
        create_raw_data_record({ content: line, line_number: index + 1 }, "text_line")
      end

      {
        total_records: records.length,
        sample_data: records.first(5),
        processing_summary: generate_processing_summary(records)
      }
    rescue => e
      Rails.logger.error "Text processing error: #{e.message}"
      raise FileProcessingError, "Failed to process text file: #{e.message}"
    end
  end

  # XML Processing
  def process_xml_file
    begin
      require "nokogiri"

      file_content = File.read(file_path)
      doc = Nokogiri::XML(file_content)

      # Find the root element's children or use a common pattern
      rows = doc.xpath("//row") # Try common 'row' pattern first
      if rows.empty?
        # If no 'row' elements, use the first level children of root
        rows = doc.root.children.select(&:element?)
      end

      records = []

      rows.each_with_index do |row, index|
        begin
          row_data = {}

          # Extract attributes
          row.attributes.each do |name, attr|
            row_data[name] = attr.value
          end

          # Extract child elements
          row.children.select(&:element?).each do |child|
            row_data[child.name] = child.text
          end

          # Add row number if no other identifier
          row_data["xml_row_number"] = index + 1 if row_data.empty?

          records << create_raw_data_record(row_data, "xml_row")
        rescue => e
          Rails.logger.warn "Error processing XML row #{index + 1}: #{e.message}"
        end
      end

      {
        total_records: records.length,
        sample_data: records.first(5),
        processing_summary: generate_processing_summary(records)
      }
    rescue => e
      Rails.logger.error "XML processing error: #{e.message}"
      raise FileProcessingError, "Failed to process XML file: #{e.message}"
    end
  end

  # Parquet Processing
  def process_parquet_file
    begin
      # Note: This requires the 'red-parquet' gem
      # For now, we'll provide a basic implementation that can be enhanced
      raise FileProcessingError, "Parquet processing requires additional setup. Please convert to CSV format."
    rescue => e
      Rails.logger.error "Parquet processing error: #{e.message}"
      raise FileProcessingError, "Failed to process Parquet file: #{e.message}"
    end
  end

  # TSV Processing
  def process_tsv_file
    begin
      require "csv"

      records = []

      CSV.foreach(file_path, col_sep: "\t", headers: true, encoding: "UTF-8") do |row|
        begin
          records << create_raw_data_record(row.to_h, "tsv_row")
        rescue => e
          Rails.logger.warn "Error processing TSV row: #{e.message}"
        end
      end

      {
        total_records: records.length,
        sample_data: records.first(5),
        processing_summary: generate_processing_summary(records)
      }
    rescue => e
      Rails.logger.error "TSV processing error: #{e.message}"
      raise FileProcessingError, "Failed to process TSV file: #{e.message}"
    end
  end

  # YAML Processing
  def process_yaml_file
    begin
      require "yaml"

      file_content = File.read(file_path)
      data = YAML.safe_load(file_content)

      records = []

      case data
      when Array
        data.each_with_index do |item, index|
          begin
            if item.is_a?(Hash)
              records << create_raw_data_record(item, "yaml_item")
            else
              records << create_raw_data_record({ "value" => item, "index" => index }, "yaml_item")
            end
          rescue => e
            Rails.logger.warn "Error processing YAML item #{index}: #{e.message}"
          end
        end
      when Hash
        begin
          records << create_raw_data_record(data, "yaml_object")
        rescue => e
          Rails.logger.warn "Error processing YAML hash: #{e.message}"
        end
      else
        records << create_raw_data_record({ "value" => data }, "yaml_value")
      end

      {
        total_records: records.length,
        sample_data: records.first(5),
        processing_summary: generate_processing_summary(records)
      }
    rescue => e
      Rails.logger.error "YAML processing error: #{e.message}"
      raise FileProcessingError, "Failed to process YAML file: #{e.message}"
    end
  end

  def preview_xml_data(limit)
    return [] unless File.exist?(file_path)

    begin
      require "nokogiri"

      file_content = File.read(file_path)
      doc = Nokogiri::XML(file_content)

      rows = doc.xpath("//row")
      if rows.empty?
        rows = doc.root.children.select(&:element?)
      end

      preview_data = []
      rows.first(limit).each do |row|
        row_data = {}

        row.attributes.each do |name, attr|
          row_data[name] = attr.value
        end

        row.children.select(&:element?).each do |child|
          row_data[child.name] = child.text
        end

        preview_data << row_data
      end

      preview_data
    rescue => e
      Rails.logger.error "XML preview error: #{e.message}"
      []
    end
  end

  def preview_parquet_data(limit)
    []
  end

  def preview_tsv_data(limit)
    return [] unless File.exist?(file_path)

    begin
      require "csv"

      preview_data = []
      CSV.foreach(file_path, col_sep: "\t", headers: true, encoding: "UTF-8").with_index do |row, index|
        break if index >= limit
        preview_data << row.to_h
      end

      preview_data
    rescue => e
      Rails.logger.error "TSV preview error: #{e.message}"
      []
    end
  end

  def preview_yaml_data(limit)
    return [] unless File.exist?(file_path)

    begin
      require "yaml"

      file_content = File.read(file_path)
      data = YAML.safe_load(file_content)

      case data
      when Array
        data.first(limit)
      when Hash
        [ data ]
      else
        [ { "value" => data } ]
      end
    rescue => e
      Rails.logger.error "YAML preview error: #{e.message}"
      []
    end
  end

  def analyze_xml_structure
    return {} unless File.exist?(file_path)

    begin
      require "nokogiri"

      file_content = File.read(file_path)
      doc = Nokogiri::XML(file_content)

      rows = doc.xpath("//row")
      if rows.empty?
        rows = doc.root.children.select(&:element?)
      end

      sample_rows = rows.first(100)
      all_fields = Set.new

      sample_rows.each do |row|
        row.attributes.each { |name, _| all_fields.add(name) }
        row.children.select(&:element?).each { |child| all_fields.add(child.name) }
      end

      {
        total_rows: rows.length,
        total_fields: all_fields.length,
        fields: all_fields.to_a,
        root_element: doc.root.name
      }
    rescue => e
      Rails.logger.error "XML structure analysis error: #{e.message}"
      {}
    end
  end

  def analyze_parquet_structure
    {}
  end

  def analyze_tsv_structure
    return {} unless File.exist?(file_path)

    begin
      require "csv"

      sample_data = []
      CSV.foreach(file_path, col_sep: "\t", headers: true, encoding: "UTF-8").with_index do |row, index|
        break if index >= 100
        sample_data << row.to_h
      end

      return {} if sample_data.empty?

      headers = sample_data.first.keys
      column_analysis = {}

      headers.each do |header|
        column_data = sample_data.map { |row| row[header] }.compact

        column_analysis[header] = {
          data_type: detect_column_type(column_data),
          sample_values: column_data.first(5),
          null_count: sample_data.count { |row| row[header].blank? },
          unique_count: column_data.uniq.length
        }
      end

      {
        total_rows: sample_data.length,
        total_columns: headers.length,
        headers: headers,
        column_analysis: column_analysis,
        suggested_transformations: suggest_transformations(column_analysis)
      }
    rescue => e
      Rails.logger.error "TSV structure analysis error: #{e.message}"
      {}
    end
  end

  def analyze_yaml_structure
    return {} unless File.exist?(file_path)

    begin
      require "yaml"

      file_content = File.read(file_path)
      data = YAML.safe_load(file_content)

      case data
      when Array
        return {} if data.empty?

        sample_items = data.first(100)
        all_keys = sample_items.select { |item| item.is_a?(Hash) }.flat_map(&:keys).uniq

        {
          structure_type: "array",
          total_items: data.length,
          total_fields: all_keys.length,
          fields: all_keys
        }
      when Hash
        {
          structure_type: "object",
          total_fields: data.keys.length,
          fields: data.keys
        }
      else
        {
          structure_type: "primitive",
          data_type: data.class.name.downcase
        }
      end
    rescue => e
      Rails.logger.error "YAML structure analysis error: #{e.message}"
      {}
    end
  end

  # Helper Methods
  def create_raw_data_record(data, record_type, metadata = {})
    raw_data_record = RawDataRecord.new(
      data_source: data_source,
      record_type: record_type,
      external_id: generate_external_id(data, record_type),
      data: {
        original_data: data,
        file_metadata: {
          filename: original_filename,
          file_size: file_size,
          processed_at: Time.current,
          processor_version: "1.0"
        }.merge(metadata)
      }
    )

    if raw_data_record.save
      raw_data_record
    else
      Rails.logger.error "Failed to save raw data record: #{raw_data_record.errors.full_messages}"
      nil
    end
  end

  def generate_external_id(data, record_type)
    # Generate a unique ID based on file and row data
    content_hash = Digest::MD5.hexdigest(data.to_json)
    "#{record_type}_#{original_filename}_#{content_hash}"
  end

  def detect_column_type(values)
    return "unknown" if values.empty?

    sample_values = values.compact.first(10)

    # Check for numeric types
    if sample_values.all? { |v| v.to_s.match?(/^\d+$/) }
      "integer"
    elsif sample_values.all? { |v| v.to_s.match?(/^\d+\.?\d*$/) }
      "decimal"
    elsif sample_values.all? { |v| v.to_s.match?(/^\d{4}-\d{2}-\d{2}/) }
      "date"
    elsif sample_values.all? { |v| v.to_s.match?(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/) }
      "datetime"
    elsif sample_values.all? { |v| %w[true false].include?(v.to_s.downcase) }
      "boolean"
    elsif sample_values.all? { |v| v.to_s.match?(/^[^@]+@[^@]+\.[^@]+$/) }
      "email"
    elsif sample_values.all? { |v| v.to_s.match?(/^https?:\/\//) }
      "url"
    else
      "text"
    end
  end

  def suggest_transformations(column_analysis)
    suggestions = []

    column_analysis.each do |column, analysis|
      case analysis[:data_type]
      when "date", "datetime"
        suggestions << {
          column: column,
          transformation: "parse_date",
          description: "Parse #{column} as date/time for time-series analysis"
        }
      when "email"
        suggestions << {
          column: column,
          transformation: "extract_domain",
          description: "Extract domain from #{column} for customer segmentation"
        }
      when "text"
        if analysis[:unique_count] < analysis[:sample_values].length * 0.5
          suggestions << {
            column: column,
            transformation: "categorize",
            description: "Treat #{column} as categorical data for grouping"
          }
        end
      end
    end

    suggestions
  end

  def generate_processing_summary(records)
    successful_records = records.compact.length
    failed_records = records.count(&:nil?)

    {
      total_processed: records.length,
      successful: successful_records,
      failed: failed_records,
      success_rate: records.empty? ? 0 : (successful_records.to_f / records.length * 100).round(2)
    }
  end

  # Custom Error Classes
  class UnsupportedFileTypeError < StandardError; end
  class FileSizeError < StandardError; end
  class FileProcessingError < StandardError; end
end
