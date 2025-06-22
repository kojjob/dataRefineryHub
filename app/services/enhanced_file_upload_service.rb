# frozen_string_literal: true

class EnhancedFileUploadService
  include DataSourceErrors

  def initialize(user, organization)
    @user = user
    @organization = organization
    @registry = DataSourceRegistry.instance
  end

  def process(uploaded_file, options = {})
    PerformanceMonitorService.track_with_result(
      'file_upload_processing',
      extract_performance_metadata(uploaded_file)
    ) do
      process_file_upload(uploaded_file, options)
    end
  end

  private

  attr_reader :user, :organization, :registry

  def process_file_upload(uploaded_file, options)
    # Step 1: Validate file
    validation_result = validate_file(uploaded_file)
    return validation_result if validation_result.failure?

    # Step 2: Security checks
    security_result = perform_security_checks(uploaded_file)
    return security_result if security_result.failure?

    # Step 3: Extract metadata
    metadata = extract_comprehensive_metadata(uploaded_file)

    # Step 4: Create data source
    data_source = create_data_source(uploaded_file, metadata, options)
    return Result.failure("Failed to create data source: #{data_source.errors.full_messages.join(', ')}") unless data_source.persisted?

    # Step 5: Store file securely
    storage_result = store_file_securely(uploaded_file, data_source)
    return storage_result if storage_result.failure?

    # Step 6: Create extraction job
    extraction_job = create_extraction_job(data_source, metadata)
    return Result.failure("Failed to create extraction job: #{extraction_job.errors.full_messages.join(', ')}") unless extraction_job.persisted?

    # Step 7: Queue processing job
    queue_processing_job(extraction_job)

    Result.success(
      {
        data_source: data_source,
        extraction_job: extraction_job,
        metadata: metadata
      },
      {
        processing_time: Time.current,
        file_size: uploaded_file.size,
        estimated_processing_time: estimate_processing_time(uploaded_file)
      }
    )
  rescue => e
    Rails.logger.error({
      event: 'file_upload_error',
      error: e.class.name,
      message: e.message,
      user_id: user.id,
      organization_id: organization.id,
      file_name: uploaded_file&.original_filename
    }.to_json)

    Result.from_exception(e)
  end

  def validate_file(uploaded_file)
    config = registry.file_upload_settings
    errors = []

    # Check file presence
    errors << InvalidFileFormat.new('No file provided') if uploaded_file.blank?

    return Result.failure(errors) if errors.any?

    # Check file size
    max_size = config[:max_size] || 50.megabytes
    if uploaded_file.size > max_size
      errors << FileSizeExceeded.new(
        ActiveSupport::NumberHelper.number_to_human_size(uploaded_file.size),
        ActiveSupport::NumberHelper.number_to_human_size(max_size)
      )
    end

    # Check file format
    file_extension = File.extname(uploaded_file.original_filename).downcase.delete('.')
    accepted_types = config[:accepted_types] || %w[csv xlsx xls json txt]
    
    unless accepted_types.include?(file_extension)
      errors << InvalidFileFormat.new(file_extension)
    end

    # Check MIME type
    unless valid_mime_type?(uploaded_file, file_extension)
      errors << InvalidFileFormat.new("MIME type mismatch for .#{file_extension} file")
    end

    errors.any? ? Result.failure(errors) : Result.success
  end

  def perform_security_checks(uploaded_file)
    errors = []

    # Basic content validation
    if uploaded_file.size > 0
      begin
        # Read first few bytes to check for suspicious content
        uploaded_file.rewind
        header = uploaded_file.read(1024)
        uploaded_file.rewind

        # Check for executable signatures
        if contains_executable_signature?(header)
          errors << ValidationFailed.new('file_content', 'File contains suspicious executable content')
        end

        # Check for script injections in text files
        if text_file?(uploaded_file) && contains_script_injection?(header)
          errors << ValidationFailed.new('file_content', 'File contains potentially malicious scripts')
        end
      rescue => e
        errors << ValidationFailed.new('file_reading', e.message)
      end
    end

    errors.any? ? Result.failure(errors) : Result.success
  end

  def extract_comprehensive_metadata(uploaded_file)
    {
      original_filename: uploaded_file.original_filename,
      content_type: uploaded_file.content_type,
      file_size: uploaded_file.size,
      file_extension: File.extname(uploaded_file.original_filename).downcase.delete('.'),
      upload_timestamp: Time.current.iso8601,
      user_id: user.id,
      organization_id: organization.id,
      checksum: calculate_checksum(uploaded_file),
      estimated_rows: estimate_row_count(uploaded_file),
      encoding: detect_encoding(uploaded_file)
    }
  end

  def create_data_source(uploaded_file, metadata, options)
    DataSource.create!(
      user: user,
      organization: organization,
      source_type: 'file_upload',
      name: options[:name] || generate_data_source_name(uploaded_file),
      description: options[:description] || "File upload: #{uploaded_file.original_filename}",
      status: 'pending',
      configuration: {
        original_filename: metadata[:original_filename],
        file_size: metadata[:file_size],
        content_type: metadata[:content_type],
        checksum: metadata[:checksum],
        upload_settings: registry.file_upload_settings
      },
      metadata: metadata
    )
  end

  def store_file_securely(uploaded_file, data_source)
    begin
      # Create secure storage path
      storage_path = generate_secure_storage_path(data_source)
      
      # Ensure directory exists
      FileUtils.mkdir_p(File.dirname(storage_path))
      
      # Copy file to secure location
      File.open(storage_path, 'wb') do |file|
        uploaded_file.rewind
        file.write(uploaded_file.read)
      end
      
      # Update data source with storage path
      data_source.update!(
        configuration: data_source.configuration.merge(
          storage_path: storage_path,
          stored_at: Time.current.iso8601
        )
      )
      
      Result.success(storage_path: storage_path)
    rescue => e
      Result.failure("File storage failed: #{e.message}")
    end
  end

  def create_extraction_job(data_source, metadata)
    ExtractionJob.create!(
      data_source: data_source,
      user: user,
      job_type: 'file_upload',
      status: 'pending',
      configuration: {
        file_metadata: metadata,
        processing_options: {
          timeout: registry.file_upload_settings[:processing_timeout] || 300,
          chunk_size: calculate_optimal_chunk_size(metadata[:file_size]),
          parallel_processing: should_use_parallel_processing?(metadata)
        }
      }
    )
  end

  def queue_processing_job(extraction_job)
    FileProcessingJob.perform_later(
      extraction_job.id,
      priority: calculate_job_priority(extraction_job)
    )
  end

  # Helper methods

  def valid_mime_type?(uploaded_file, extension)
    expected_types = {
      'csv' => ['text/csv', 'application/csv', 'text/plain'],
      'xlsx' => ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
      'xls' => ['application/vnd.ms-excel'],
      'json' => ['application/json', 'text/json'],
      'txt' => ['text/plain']
    }
    
    expected_types[extension]&.include?(uploaded_file.content_type)
  end

  def contains_executable_signature?(header)
    executable_signatures = [
      "\x4D\x5A", # PE executable
      "\x7F\x45\x4C\x46", # ELF executable
      "\xCA\xFE\xBA\xBE", # Java class file
      "\xFE\xED\xFA", # Mach-O executable
    ]
    
    executable_signatures.any? { |sig| header.start_with?(sig) }
  end

  def contains_script_injection?(content)
    dangerous_patterns = [
      /<script[^>]*>/i,
      /javascript:/i,
      /vbscript:/i,
      /on\w+\s*=/i,
      /eval\s*\(/i,
      /exec\s*\(/i
    ]
    
    dangerous_patterns.any? { |pattern| content.match?(pattern) }
  end

  def text_file?(uploaded_file)
    %w[csv txt json].include?(File.extname(uploaded_file.original_filename).downcase.delete('.'))
  end

  def calculate_checksum(uploaded_file)
    uploaded_file.rewind
    checksum = Digest::SHA256.hexdigest(uploaded_file.read)
    uploaded_file.rewind
    checksum
  end

  def estimate_row_count(uploaded_file)
    return nil unless text_file?(uploaded_file)
    
    uploaded_file.rewind
    sample = uploaded_file.read(10.kilobytes)
    uploaded_file.rewind
    
    return nil if sample.blank?
    
    lines_in_sample = sample.count("\n")
    return nil if lines_in_sample == 0
    
    total_size = uploaded_file.size
    estimated_total_lines = (total_size.to_f / sample.size * lines_in_sample).round
    
    # Subtract 1 for header if CSV
    estimated_total_lines -= 1 if uploaded_file.original_filename.downcase.end_with?('.csv')
    
    [estimated_total_lines, 0].max
  end

  def detect_encoding(uploaded_file)
    return 'binary' unless text_file?(uploaded_file)
    
    uploaded_file.rewind
    sample = uploaded_file.read(1.kilobyte)
    uploaded_file.rewind
    
    return 'utf-8' if sample.valid_encoding? && sample.encoding.name == 'UTF-8'
    
    # Try to detect encoding
    begin
      detected = CharlockHolmes::EncodingDetector.detect(sample)
      detected[:encoding] if detected && detected[:confidence] > 0.7
    rescue
      'unknown'
    end
  end

  def generate_data_source_name(uploaded_file)
    base_name = File.basename(uploaded_file.original_filename, '.*')
    "#{base_name}_#{Time.current.strftime('%Y%m%d_%H%M%S')}"
  end

  def generate_secure_storage_path(data_source)
    Rails.root.join(
      'storage',
      'uploads',
      organization.id.to_s,
      data_source.id.to_s,
      "#{SecureRandom.hex(16)}_#{data_source.configuration['original_filename']}"
    ).to_s
  end

  def calculate_optimal_chunk_size(file_size)
    case file_size
    when 0..1.megabyte
      1000
    when 1.megabyte..10.megabytes
      5000
    when 10.megabytes..50.megabytes
      10000
    else
      20000
    end
  end

  def should_use_parallel_processing?(metadata)
    metadata[:file_size] > 10.megabytes && metadata[:estimated_rows].to_i > 10000
  end

  def calculate_job_priority(extraction_job)
    file_size = extraction_job.configuration.dig('file_metadata', 'file_size') || 0
    
    case file_size
    when 0..1.megabyte
      'high'
    when 1.megabyte..10.megabytes
      'normal'
    else
      'low'
    end
  end

  def estimate_processing_time(uploaded_file)
    base_time = 30 # seconds
    size_factor = uploaded_file.size.to_f / 1.megabyte
    
    (base_time + (size_factor * 10)).round
  end

  def extract_performance_metadata(uploaded_file)
    {
      file_size: uploaded_file&.size || 0,
      file_type: uploaded_file&.content_type,
      file_name: uploaded_file&.original_filename
    }
  end
end