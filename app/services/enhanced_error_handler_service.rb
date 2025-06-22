# Enhanced Error Handling Service for ETL Pipeline
# Provides comprehensive error categorization, retry strategies, and dead letter queue management
class EnhancedErrorHandlerService
  # Error categories for different handling strategies
  TRANSIENT_ERRORS = [
    Net::TimeoutError,
    Timeout::Error,
    Net::HTTPServerError,
    Errno::ECONNRESET,
    Errno::ECONNREFUSED,
    Errno::EHOSTUNREACH,
    OpenSSL::SSL::SSLError
  ].freeze

  AUTHENTICATION_ERRORS = [
    Net::HTTPUnauthorized,
    Net::HTTPForbidden,
    BaseExtractor::AuthenticationError
  ].freeze

  RATE_LIMIT_ERRORS = [
    Net::HTTPTooManyRequests,
    BaseExtractor::RateLimitError
  ].freeze

  PERMANENT_ERRORS = [
    Net::HTTPNotFound,
    Net::HTTPBadRequest,
    Net::HTTPUnprocessableEntity,
    BaseExtractor::DataValidationError,
    JSON::ParserError,
    ArgumentError
  ].freeze

  # Retry strategies
  RETRY_STRATEGIES = {
    exponential: ->(attempt) { [ 2**attempt, 300 ].min }, # Max 5 minutes
    linear: ->(attempt) { [ attempt * 30, 300 ].min },     # 30s, 60s, 90s...
    fixed: ->(attempt) { 60 },                          # Fixed 1 minute
    fibonacci: ->(attempt) { fibonacci_delay(attempt) }   # Fibonacci sequence
  }.freeze

  attr_reader :context, :circuit_breaker, :dead_letter_queue

  def initialize(context:, circuit_breaker_config: {})
    @context = context

    # Load configuration from centralized manager
    error_config = EtlConfigurationManager.error_handling_config
    cb_config = EtlConfigurationManager.circuit_breaker_config(context)

    # Merge configurations
    merged_cb_config = cb_config.merge(circuit_breaker_config)

    @circuit_breaker = CircuitBreakerService.for("#{context}_circuit_breaker", merged_cb_config)
    @dead_letter_queue = []
    @logger = Rails.logger
    @metrics = ErrorMetrics.new(context)

    # Store merged configuration for reference
    @config = {
      retry_strategies: error_config[:retry_strategies],
      retry_limits: error_config[:retry_limits],
      dead_letter_queue: error_config[:dead_letter_queue],
      circuit_breaker: merged_cb_config
    }
  end

  # Main error handling method
  def handle_error(error, operation:, attempt: 1, max_attempts: 3, strategy: :exponential, **metadata)
    error_category = categorize_error(error)

    # Log error with context
    log_error(error, operation, attempt, error_category, metadata)

    # Update metrics
    @metrics.record_error(error_category, operation)

    # Determine if we should retry
    should_retry = should_retry_error?(error_category, attempt, max_attempts)

    if should_retry
      delay = calculate_retry_delay(strategy, attempt)
      schedule_retry(operation, attempt + 1, delay, metadata)
      { action: :retry, delay: delay, attempt: attempt + 1 }
    else
      handle_permanent_failure(error, operation, attempt, metadata)
      { action: :fail, reason: error_category }
    end
  end

  # Execute operation with circuit breaker and error handling
  def execute_with_protection(operation_name, max_attempts: 3, strategy: :exponential, &block)
    attempt = 1

    begin
      @circuit_breaker.call(&block)
    rescue CircuitBreakerService::CircuitBreakerOpenError => e
      handle_circuit_breaker_open(operation_name, e)
      raise
    rescue => error
      result = handle_error(
        error,
        operation: operation_name,
        attempt: attempt,
        max_attempts: max_attempts,
        strategy: strategy
      )

      if result[:action] == :retry && attempt < max_attempts
        sleep(result[:delay])
        attempt = result[:attempt]
        retry
      else
        raise
      end
    end
  end

  # Get error handling metrics
  def metrics
    {
      context: @context,
      circuit_breaker: @circuit_breaker.metrics,
      error_metrics: @metrics.summary,
      dead_letter_queue_size: @dead_letter_queue.size
    }
  end

  # Process dead letter queue
  def process_dead_letter_queue
    processed = 0
    failed = 0

    @dead_letter_queue.dup.each do |dead_letter|
      begin
        if should_retry_dead_letter?(dead_letter)
          retry_dead_letter(dead_letter)
          @dead_letter_queue.delete(dead_letter)
          processed += 1
        end
      rescue => error
        @logger.error "Failed to process dead letter: #{error.message}"
        failed += 1
      end
    end

    { processed: processed, failed: failed, remaining: @dead_letter_queue.size }
  end

  private

  def categorize_error(error)
    case error
    when *TRANSIENT_ERRORS
      :transient
    when *AUTHENTICATION_ERRORS
      :authentication
    when *RATE_LIMIT_ERRORS
      :rate_limit
    when *PERMANENT_ERRORS
      :permanent
    when CircuitBreakerService::CircuitBreakerOpenError
      :circuit_breaker
    else
      # Check error message for common patterns
      message = error.message.downcase
      if message.include?("timeout") || message.include?("connection")
        :transient
      elsif message.include?("rate limit") || message.include?("too many requests")
        :rate_limit
      elsif message.include?("unauthorized") || message.include?("forbidden")
        :authentication
      else
        :unknown
      end
    end
  end

  def should_retry_error?(category, attempt, max_attempts)
    return false if attempt >= max_attempts

    case category
    when :transient, :rate_limit, :circuit_breaker
      true
    when :authentication
      attempt == 1 # Only retry once for auth errors
    when :permanent
      false
    when :unknown
      attempt <= 2 # Conservative retry for unknown errors
    else
      false
    end
  end

  def calculate_retry_delay(strategy, attempt)
    delay_calculator = RETRY_STRATEGIES[strategy] || RETRY_STRATEGIES[:exponential]
    base_delay = delay_calculator.call(attempt)

    # Add jitter to prevent thundering herd
    jitter = rand(0.1..0.3) * base_delay
    (base_delay + jitter).round(2)
  end

  def schedule_retry(operation, attempt, delay, metadata)
    @logger.info "Scheduling retry for #{operation} (attempt #{attempt}) in #{delay} seconds"

    # In a real implementation, you might use a job scheduler here
    # For now, we'll just log the retry scheduling
  end

  def handle_permanent_failure(error, operation, attempt, metadata)
    dead_letter = {
      error: error,
      operation: operation,
      attempt: attempt,
      metadata: metadata,
      failed_at: Time.current,
      context: @context
    }

    @dead_letter_queue << dead_letter
    @logger.error "Operation #{operation} failed permanently after #{attempt} attempts. Added to dead letter queue."

    # Notify monitoring systems
    notify_permanent_failure(dead_letter)
  end

  def handle_circuit_breaker_open(operation, error)
    @logger.warn "Circuit breaker open for #{operation}: #{error.message}"
    @metrics.record_circuit_breaker_open(operation)
  end

  def should_retry_dead_letter?(dead_letter)
    # Retry dead letters after a cooling-off period
    cooling_period = 1.hour
    dead_letter[:failed_at] < (Time.current - cooling_period)
  end

  def retry_dead_letter(dead_letter)
    @logger.info "Retrying dead letter for #{dead_letter[:operation]}"
    # Implementation would depend on the specific operation type
  end

  def notify_permanent_failure(dead_letter)
    # Integration point for monitoring/alerting systems
    # Could send to Slack, PagerDuty, etc.
  end

  def log_error(error, operation, attempt, category, metadata)
    log_data = {
      operation: operation,
      attempt: attempt,
      category: category,
      error_class: error.class.name,
      error_message: error.message,
      context: @context,
      metadata: metadata
    }

    case category
    when :permanent
      @logger.error "Permanent error in #{operation}: #{log_data.to_json}"
    when :transient, :rate_limit
      @logger.warn "Transient error in #{operation}: #{log_data.to_json}"
    else
      @logger.info "Error in #{operation}: #{log_data.to_json}"
    end
  end

  def self.fibonacci_delay(attempt)
    fib_sequence = [ 1, 1 ]
    (2..attempt).each { |i| fib_sequence[i] = fib_sequence[i-1] + fib_sequence[i-2] }
    [ fib_sequence[attempt - 1] * 10, 300 ].min # Scale by 10 seconds, max 5 minutes
  end

  # Inner class for tracking error metrics
  class ErrorMetrics
    def initialize(context)
      @context = context
      @error_counts = Hash.new(0)
      @operation_errors = Hash.new { |h, k| h[k] = Hash.new(0) }
      @circuit_breaker_opens = 0
      @start_time = Time.current
    end

    def record_error(category, operation)
      @error_counts[category] += 1
      @operation_errors[operation][category] += 1
    end

    def record_circuit_breaker_open(operation)
      @circuit_breaker_opens += 1
    end

    def summary
      {
        context: @context,
        uptime: Time.current - @start_time,
        total_errors: @error_counts.values.sum,
        error_breakdown: @error_counts,
        operation_errors: @operation_errors,
        circuit_breaker_opens: @circuit_breaker_opens,
        error_rate: calculate_error_rate
      }
    end

    private

    def calculate_error_rate
      uptime_hours = (Time.current - @start_time) / 1.hour
      return 0.0 if uptime_hours == 0
      (@error_counts.values.sum / uptime_hours).round(2)
    end
  end
end
