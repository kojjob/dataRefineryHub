# Batch Processing Service for ETL Pipeline
# Optimizes data processing through intelligent batching strategies
class BatchProcessingService
  # Batch size configurations for different operations
  BATCH_CONFIGS = {
    extraction: {
      default_size: 1000,
      max_size: 5000,
      min_size: 100,
      memory_threshold: 100.megabytes
    },
    transformation: {
      default_size: 500,
      max_size: 2000,
      min_size: 50,
      memory_threshold: 50.megabytes
    },
    validation: {
      default_size: 2000,
      max_size: 10000,
      min_size: 200,
      memory_threshold: 200.megabytes
    },
    storage: {
      default_size: 1000,
      max_size: 3000,
      min_size: 100,
      memory_threshold: 75.megabytes
    }
  }.freeze

  attr_reader :operation_type, :config, :metrics

  def initialize(operation_type, custom_config = {})
    @operation_type = operation_type
    # Load configuration from centralized manager
    extraction_config = EtlConfigurationManager.batch_config(:extraction)
    transformation_config = EtlConfigurationManager.batch_config(:transformation)
    validation_config = EtlConfigurationManager.batch_config(:validation)
    storage_config = EtlConfigurationManager.batch_config(:storage)

    base_config = BATCH_CONFIGS[operation_type] || BATCH_CONFIGS[:extraction]
    enhanced_config = base_config.merge({
      adaptive_sizing_enabled: extraction_config[:adaptive_sizing_enabled]
    })

    @config = enhanced_config.merge(custom_config)
    @metrics = BatchMetrics.new(operation_type)
    @logger = Rails.logger
  end

  # Process data in optimized batches
  def process_in_batches(data, &block)
    return [] if data.empty?

    total_items = data.respond_to?(:count) ? data.count : data.size
    @logger.info "Starting batch processing for #{@operation_type}: #{total_items} items"

    start_time = Time.current
    results = []
    processed_count = 0
    batch_number = 1

    if data.respond_to?(:in_batches)
      # ActiveRecord relation
      data.in_batches(of: calculate_optimal_batch_size(data)) do |batch|
        processed_count += process_single_batch(batch, batch_number, results, total_items, processed_count, &block)
        batch_number += 1
      end
    else
      # Array or other enumerable
      batch_size = calculate_optimal_batch_size(data)
      data.each_slice(batch_size) do |batch|
        processed_count += process_single_batch(batch, batch_number, results, total_items, processed_count, &block)
        batch_number += 1
      end
    end

    total_duration = Time.current - start_time
    @logger.info "Batch processing completed: #{processed_count} items in #{total_duration.round(2)}s"

    @metrics.finalize(total_duration, processed_count)
    results
  end

  # Process data with parallel batching (for I/O bound operations)
  def process_in_parallel_batches(data, max_threads: 4, &block)
    return [] if data.empty?

    @logger.info "Starting parallel batch processing with #{max_threads} threads"

    batch_size = calculate_optimal_batch_size(data)
    batches = data.each_slice(batch_size).to_a
    results = []
    mutex = Mutex.new

    # Use thread pool for parallel processing
    threads = []
    batch_queue = Queue.new

    # Fill the queue with batches
    batches.each_with_index { |batch, index| batch_queue << [ batch, index + 1 ] }

    # Create worker threads
    max_threads.times do
      threads << Thread.new do
        while !batch_queue.empty?
          begin
            batch, batch_number = batch_queue.pop(true)

            batch_start_time = Time.current
            batch_result = yield(batch, batch_number)

            mutex.synchronize do
              results.concat(Array(batch_result))
              @metrics.record_batch(
                size: batch.size,
                duration: Time.current - batch_start_time,
                memory_used: 0, # Difficult to measure in parallel
                success: true
              )
            end

          rescue ThreadError
            # Queue is empty, exit thread
            break
          rescue => error
            @logger.error "Parallel batch #{batch_number} failed: #{error.message}"
            mutex.synchronize do
              @metrics.record_batch(
                size: batch&.size || 0,
                duration: 0,
                memory_used: 0,
                success: false,
                error: error
              )
            end
          end
        end
      end
    end

    # Wait for all threads to complete
    threads.each(&:join)

    @logger.info "Parallel batch processing completed: #{results.size} results"
    results
  end

  # Get processing metrics
  def processing_metrics
    @metrics.summary
  end

  # Reset metrics
  def reset_metrics!
    @metrics = BatchMetrics.new(@operation_type)
  end

  private

  def calculate_optimal_batch_size(data)
    # Start with default size
    base_size = @config[:default_size]

    # Adjust based on data characteristics
    if data.respond_to?(:first) && data.first
      estimated_item_size = estimate_item_size(data.first)
      memory_based_size = @config[:memory_threshold] / estimated_item_size
      base_size = [ base_size, memory_based_size ].min
    end

    # Apply historical performance adjustments
    performance_adjustment = @metrics.suggested_batch_size_adjustment
    adjusted_size = (base_size * performance_adjustment).to_i

    # Ensure within bounds
    [ [ adjusted_size, @config[:min_size] ].max, @config[:max_size] ].min
  end

  def estimate_item_size(item)
    case item
    when Hash
      item.to_json.bytesize
    when String
      item.bytesize
    when ActiveRecord::Base
      item.attributes.to_json.bytesize
    else
      1.kilobyte # Conservative estimate
    end
  end

  def adjust_batch_size_if_needed(duration, memory_used)
    # If processing is too slow, reduce batch size
    if duration > 30.seconds
      @config[:default_size] = [ @config[:default_size] * 0.8, @config[:min_size] ].max.to_i
      @logger.debug "Reduced batch size to #{@config[:default_size]} due to slow processing"
    end

    # If memory usage is too high, reduce batch size
    if memory_used > @config[:memory_threshold]
      @config[:default_size] = [ @config[:default_size] * 0.7, @config[:min_size] ].max.to_i
      @logger.debug "Reduced batch size to #{@config[:default_size]} due to high memory usage"
    end

    # If processing is fast and memory usage is low, increase batch size
    if duration < 5.seconds && memory_used < @config[:memory_threshold] * 0.5
      @config[:default_size] = [ @config[:default_size] * 1.2, @config[:max_size] ].min.to_i
      @logger.debug "Increased batch size to #{@config[:default_size]} due to efficient processing"
    end
  end

  def get_memory_usage
    # Get current memory usage (simplified)
    GC.stat[:heap_allocated_pages] * GC::INTERNAL_CONSTANTS[:HEAP_PAGE_SIZE]
  rescue
    0 # Fallback if memory measurement fails
  end

  def should_halt_on_error?(error)
    # Halt on critical errors, continue on transient ones
    case error
    when ActiveRecord::RecordNotFound,
         NoMethodError,
         ArgumentError,
         BaseExtractor::DataValidationError
      true
    when Net::TimeoutError,
         Errno::ECONNRESET,
         BaseExtractor::RateLimitError
      false
    else
      # Default to halting for unknown errors
      true
    end
  end

  # Inner class for tracking batch processing metrics
  class BatchMetrics
    attr_reader :operation_type, :batches_processed, :total_items, :total_duration,
                :successful_batches, :failed_batches, :average_batch_size,
                :average_processing_time, :total_memory_used

    def initialize(operation_type)
      @operation_type = operation_type
      @batches_processed = 0
      @total_items = 0
      @total_duration = 0
      @successful_batches = 0
      @failed_batches = 0
      @total_memory_used = 0
      @batch_durations = []
      @batch_sizes = []
      @errors = []
      @start_time = Time.current
    end

    def record_batch(size:, duration:, memory_used:, success:, error: nil)
      @batches_processed += 1
      @total_items += size
      @total_memory_used += memory_used
      @batch_durations << duration
      @batch_sizes << size

      if success
        @successful_batches += 1
      else
        @failed_batches += 1
        @errors << error if error
      end
    end

    def finalize(total_duration, total_items)
      @total_duration = total_duration
      @total_items = total_items
    end

    def summary
      {
        operation_type: @operation_type,
        batches_processed: @batches_processed,
        total_items: @total_items,
        total_duration: @total_duration,
        successful_batches: @successful_batches,
        failed_batches: @failed_batches,
        success_rate: success_rate,
        average_batch_size: average_batch_size,
        average_processing_time: average_processing_time,
        throughput: throughput,
        total_memory_used: @total_memory_used,
        errors: @errors.map(&:message)
      }
    end

    def suggested_batch_size_adjustment
      return 1.0 if @batch_durations.empty?

      avg_duration = @batch_durations.sum / @batch_durations.size

      # Suggest adjustment based on average processing time
      case avg_duration
      when 0..5
        1.2 # Increase batch size
      when 5..15
        1.0 # Keep current size
      when 15..30
        0.8 # Reduce batch size
      else
        0.6 # Significantly reduce batch size
      end
    end

    private

    def process_single_batch(batch, batch_number, results, total_items, processed_count, &block)
      batch_start_time = Time.current

      begin
        @logger.debug "Processing batch #{batch_number} (#{batch.size} items)"

        # Monitor memory usage before processing
        memory_before = get_memory_usage

        # Process the batch
        batch_result = yield(batch, batch_number)
        results.concat(Array(batch_result))

        # Monitor memory usage after processing
        memory_after = get_memory_usage
        memory_used = memory_after - memory_before

        # Update metrics
        batch_duration = Time.current - batch_start_time
        @metrics.record_batch(
          size: batch.size,
          duration: batch_duration,
          memory_used: memory_used,
          success: true
        )

        # Adaptive batch sizing based on performance
        adjust_batch_size_if_needed(batch_duration, memory_used)

        # Memory pressure relief
        if memory_used > @config[:memory_threshold]
          @logger.debug "High memory usage detected (#{memory_used.to_f / 1.megabyte}MB), triggering GC"
          GC.start
        end

        # Progress logging
        if batch_number % 10 == 0
          progress = ((processed_count + batch.size).to_f / total_items * 100).round(1)
          @logger.info "Batch processing progress: #{progress}% (#{processed_count + batch.size}/#{total_items})"
        end

        batch.size

      rescue => error
        @metrics.record_batch(
          size: batch.size,
          duration: Time.current - batch_start_time,
          memory_used: 0,
          success: false,
          error: error
        )

        @logger.error "Batch #{batch_number} failed: #{error.message}"

        # Decide whether to continue or halt based on error type
        if should_halt_on_error?(error)
          @logger.error "Halting batch processing due to critical error"
          raise error
        else
          @logger.warn "Continuing batch processing despite error in batch #{batch_number}"
          0
        end
      end
    end

    def success_rate
      return 0.0 if @batches_processed == 0
      (@successful_batches.to_f / @batches_processed * 100).round(2)
    end

    def average_batch_size
      return 0 if @batch_sizes.empty?
      (@batch_sizes.sum.to_f / @batch_sizes.size).round(2)
    end

    def average_processing_time
      return 0 if @batch_durations.empty?
      (@batch_durations.sum / @batch_durations.size).round(3)
    end

    def throughput
      return 0.0 if @total_duration == 0
      (@total_items.to_f / @total_duration).round(2)
    end
  end
end
