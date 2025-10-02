# frozen_string_literal: true

# Circuit Breaker pattern implementation for external service resilience
# Prevents cascading failures and provides graceful degradation
class CircuitBreaker
  class CircuitOpenError < StandardError; end
  class CircuitHalfOpenError < StandardError; end

  DEFAULTS = {
    failure_threshold: 5,        # Number of failures before opening circuit
    success_threshold: 2,         # Number of successes in half-open before closing
    timeout: 60,                  # Seconds before attempting to close circuit
    half_open_timeout: 30,        # Seconds for half-open state
    error_threshold_percentage: 50, # Percentage of errors to open circuit
    request_volume_threshold: 20,   # Minimum requests before percentage calculation
    sleep_window: 60,             # Time window for metrics calculation
    excluded_exceptions: []       # Exceptions that don't count as failures
  }.freeze

  attr_reader :name, :options, :state, :failure_count, :success_count,
              :last_failure_time, :last_success_time, :metrics

  def initialize(name, options = {})
    @name = name
    @options = DEFAULTS.merge(options)
    @state = :closed
    @failure_count = 0
    @success_count = 0
    @last_failure_time = nil
    @last_success_time = nil
    @half_open_start = nil
    @mutex = Mutex.new
    @metrics = CircuitBreakerMetrics.new(name)

    # Load state from cache if available
    load_state_from_cache
  end

  # Execute a block with circuit breaker protection
  def call(&block)
    raise ArgumentError, "Block required" unless block_given?

    @mutex.synchronize do
      case state
      when :open
        handle_open_state
      when :half_open
        handle_half_open_state(&block)
      when :closed
        handle_closed_state(&block)
      else
        raise "Unknown circuit state: #{state}"
      end
    end
  end

  # Manually trip the circuit breaker
  def trip!
    @mutex.synchronize do
      transition_to_open
    end
  end

  # Manually reset the circuit breaker
  def reset!
    @mutex.synchronize do
      transition_to_closed
      @failure_count = 0
      @success_count = 0
      @last_failure_time = nil
      @last_success_time = nil
      save_state_to_cache
    end
  end

  # Get current circuit breaker status
  def status
    {
      name: name,
      state: state,
      failure_count: failure_count,
      success_count: success_count,
      last_failure_time: last_failure_time,
      last_success_time: last_success_time,
      metrics: metrics.summary
    }
  end

  # Check if circuit is allowing requests
  def allow_request?
    case state
    when :closed, :half_open
      true
    when :open
      should_attempt_reset?
    else
      false
    end
  end

  private

  def handle_open_state
    if should_attempt_reset?
      transition_to_half_open
      # Don't execute block yet, just transition state
      raise CircuitHalfOpenError, "Circuit breaker '#{name}' is attempting reset"
    else
      metrics.record_rejection
      raise CircuitOpenError, "Circuit breaker '#{name}' is open"
    end
  end

  def handle_half_open_state(&block)
    begin
      start_time = Time.current
      result = yield

      record_success
      metrics.record_success(Time.current - start_time)

      # Check if we should close the circuit
      if @success_count >= options[:success_threshold]
        transition_to_closed
      end

      result
    rescue => e
      handle_error(e)
      transition_to_open
      raise
    end
  end

  def handle_closed_state(&block)
    begin
      start_time = Time.current
      result = yield

      record_success
      metrics.record_success(Time.current - start_time)
      result
    rescue => e
      handle_error(e)

      # Check if we should open the circuit
      if should_open_circuit?
        transition_to_open
      end

      raise
    end
  end

  def handle_error(error)
    # Don't count excluded exceptions as failures
    return if options[:excluded_exceptions].include?(error.class)

    record_failure(error)
    metrics.record_failure(error)
  end

  def record_success
    @success_count += 1
    @last_success_time = Time.current

    # Reset failure count on success in closed state
    @failure_count = 0 if state == :closed
  end

  def record_failure(error)
    @failure_count += 1
    @last_failure_time = Time.current

    Rails.logger.warn(
      "Circuit breaker '#{name}' failure ##{@failure_count}: #{error.class} - #{error.message}"
    )
  end

  def should_open_circuit?
    # Check absolute failure threshold
    return true if @failure_count >= options[:failure_threshold]

    # Check percentage-based threshold
    if metrics.request_count >= options[:request_volume_threshold]
      error_percentage = metrics.error_percentage
      return true if error_percentage >= options[:error_threshold_percentage]
    end

    false
  end

  def should_attempt_reset?
    return false unless state == :open
    return false if @last_failure_time.nil?

    Time.current - @last_failure_time >= options[:timeout]
  end

  def transition_to_open
    @state = :open
    @failure_count = 0
    @success_count = 0
    save_state_to_cache

    Rails.logger.error("Circuit breaker '#{name}' opened")
    notify_state_change(:open)
  end

  def transition_to_half_open
    @state = :half_open
    @half_open_start = Time.current
    @success_count = 0
    @failure_count = 0
    save_state_to_cache

    Rails.logger.info("Circuit breaker '#{name}' half-open")
    notify_state_change(:half_open)
  end

  def transition_to_closed
    @state = :closed
    @failure_count = 0
    @success_count = 0
    @half_open_start = nil
    save_state_to_cache

    Rails.logger.info("Circuit breaker '#{name}' closed")
    notify_state_change(:closed)
  end

  def notify_state_change(new_state)
    # Send notifications about state changes
    CircuitBreakerNotifier.notify(name, new_state) if defined?(CircuitBreakerNotifier)

    # Record metrics
    metrics.record_state_change(new_state)

    # Trigger any callbacks
    if options[:on_state_change]
      options[:on_state_change].call(name, new_state)
    end
  end

  def cache_key
    "circuit_breaker:#{name}"
  end

  def save_state_to_cache
    Rails.cache.write(
      cache_key,
      {
        state: @state,
        failure_count: @failure_count,
        success_count: @success_count,
        last_failure_time: @last_failure_time,
        last_success_time: @last_success_time,
        half_open_start: @half_open_start
      },
      expires_in: 24.hours
    )
  end

  def load_state_from_cache
    cached_state = Rails.cache.read(cache_key)
    return unless cached_state

    @state = cached_state[:state].to_sym
    @failure_count = cached_state[:failure_count] || 0
    @success_count = cached_state[:success_count] || 0
    @last_failure_time = cached_state[:last_failure_time]
    @last_success_time = cached_state[:last_success_time]
    @half_open_start = cached_state[:half_open_start]

    # Check if we should auto-transition based on timeouts
    if @state == :open && should_attempt_reset?
      transition_to_half_open
    elsif @state == :half_open && @half_open_start
      # Check if half-open has timed out
      if Time.current - @half_open_start > options[:half_open_timeout]
        transition_to_open
      end
    end
  end
end

# Metrics tracking for circuit breakers
class CircuitBreakerMetrics
  attr_reader :name

  def initialize(name)
    @name = name
    @window_size = 60 # seconds
  end

  def record_success(duration)
    key = "circuit_metrics:#{name}:success"
    timestamp = Time.current.to_i

    # Store in sorted set with timestamp as score
    Rails.cache.write(
      "#{key}:#{timestamp}",
      { duration: duration, timestamp: timestamp },
      expires_in: @window_size.seconds
    )

    increment_counter(:success)
  end

  def record_failure(error)
    key = "circuit_metrics:#{name}:failure"
    timestamp = Time.current.to_i

    Rails.cache.write(
      "#{key}:#{timestamp}",
      {
        error_class: error.class.name,
        error_message: error.message,
        timestamp: timestamp
      },
      expires_in: @window_size.seconds
    )

    increment_counter(:failure)
  end

  def record_rejection
    increment_counter(:rejection)
  end

  def record_state_change(new_state)
    key = "circuit_metrics:#{name}:state_changes"
    timestamp = Time.current.to_i

    Rails.cache.write(
      "#{key}:#{timestamp}",
      { state: new_state, timestamp: timestamp },
      expires_in: 24.hours
    )
  end

  def request_count
    success_count + failure_count
  end

  def success_count
    get_counter(:success)
  end

  def failure_count
    get_counter(:failure)
  end

  def rejection_count
    get_counter(:rejection)
  end

  def error_percentage
    total = request_count
    return 0.0 if total.zero?

    (failure_count.to_f / total * 100).round(2)
  end

  def success_rate
    total = request_count
    return 0.0 if total.zero?

    (success_count.to_f / total * 100).round(2)
  end

  def summary
    {
      request_count: request_count,
      success_count: success_count,
      failure_count: failure_count,
      rejection_count: rejection_count,
      error_percentage: error_percentage,
      success_rate: success_rate
    }
  end

  private

  def increment_counter(type)
    key = "circuit_metrics:#{name}:#{type}_count"
    Rails.cache.increment(key, 1, expires_in: @window_size.seconds)
  end

  def get_counter(type)
    key = "circuit_metrics:#{name}:#{type}_count"
    Rails.cache.read(key).to_i
  end
end

# Factory for managing circuit breakers
class CircuitBreakerFactory
  class << self
    def circuit_breakers
      @circuit_breakers ||= {}
    end

    def get(name, options = {})
      circuit_breakers[name] ||= CircuitBreaker.new(name, options)
    end

    def reset_all
      circuit_breakers.each_value(&:reset!)
    end

    def status_all
      circuit_breakers.transform_values(&:status)
    end
  end
end
