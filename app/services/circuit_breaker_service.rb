# Enhanced Circuit Breaker Service for ETL Pipeline
# Provides configurable circuit breaking with exponential backoff and metrics
class CircuitBreakerService
  class CircuitBreakerOpenError < StandardError; end
  class CircuitBreakerHalfOpenError < StandardError; end

  # Circuit states
  CLOSED = :closed
  OPEN = :open
  HALF_OPEN = :half_open

  # Load configuration from centralized manager
  def self.default_config
    EtlConfigurationManager.circuit_breaker_config(:default)
  end

  attr_reader :name, :config, :state, :failure_count, :success_count, :last_failure_time, :last_success_time

  def initialize(name, config = {})
    @name = name
    @config = self.class.default_config.merge(config)
    @state = CLOSED
    @failure_count = 0
    @success_count = 0
    @consecutive_timeouts = 0
    @last_failure_time = nil
    @last_success_time = nil
    @metrics = CircuitBreakerMetrics.new
    @logger = Rails.logger
  end

  # Execute block with circuit breaker protection
  def call(&block)
    case @state
    when CLOSED
      execute_closed(&block)
    when OPEN
      handle_open_circuit
    when HALF_OPEN
      execute_half_open(&block)
    end
  end

  # Check if circuit should transition from open to half-open
  def should_attempt_reset?
    return false unless @state == OPEN
    return false unless @last_failure_time

    timeout_period = calculate_timeout_period
    Time.current >= (@last_failure_time + timeout_period)
  end

  # Get circuit breaker metrics
  def metrics
    {
      name: @name,
      state: @state,
      failure_count: @failure_count,
      success_count: @success_count,
      failure_rate: calculate_failure_rate,
      last_failure_time: @last_failure_time,
      last_success_time: @last_success_time,
      next_retry_time: calculate_next_retry_time,
      consecutive_timeouts: @consecutive_timeouts
    }
  end

  # Reset circuit breaker to closed state
  def reset!
    @state = CLOSED
    @failure_count = 0
    @success_count = 0
    @consecutive_timeouts = 0
    @last_failure_time = nil
    log_state_change("reset")
  end

  # Force circuit breaker to open state
  def trip!
    @state = OPEN
    @last_failure_time = Time.current
    log_state_change("tripped")
  end

  private

  def execute_closed(&block)
    begin
      result = yield
      on_success
      result
    rescue => error
      on_failure(error)
      raise error
    end
  end

  def execute_half_open(&block)
    begin
      result = yield
      on_half_open_success
      result
    rescue => error
      on_half_open_failure(error)
      raise error
    end
  end

  def handle_open_circuit
    if should_attempt_reset?
      @state = HALF_OPEN
      @success_count = 0
      log_state_change("half_open")
      raise CircuitBreakerHalfOpenError, "Circuit breaker transitioning to half-open for #{@name}"
    else
      next_retry = calculate_next_retry_time
      raise CircuitBreakerOpenError, "Circuit breaker is open for #{@name}. Next retry at #{next_retry}"
    end
  end

  def on_success
    @success_count += 1
    @last_success_time = Time.current
    @consecutive_timeouts = 0

    # Reset failure count on success in closed state
    @failure_count = 0 if @state == CLOSED
  end

  def on_failure(error)
    @failure_count += 1
    @last_failure_time = Time.current

    if timeout_error?(error)
      @consecutive_timeouts += 1
    end

    if @failure_count >= @config[:failure_threshold]
      @state = OPEN
      log_state_change("opened", error)
    end
  end

  def on_half_open_success
    @success_count += 1
    @last_success_time = Time.current
    @consecutive_timeouts = 0

    if @success_count >= @config[:success_threshold]
      @state = CLOSED
      @failure_count = 0
      log_state_change("closed")
    end
  end

  def on_half_open_failure(error)
    @state = OPEN
    @failure_count += 1
    @last_failure_time = Time.current

    if timeout_error?(error)
      @consecutive_timeouts += 1
    end

    log_state_change("opened_from_half_open", error)
  end

  def calculate_timeout_period
    base_timeout = @config[:timeout_period]

    if @config[:exponential_backoff]
      # Exponential backoff with jitter
      timeout = base_timeout * (@config[:backoff_multiplier] ** @consecutive_timeouts)
      timeout = [ @config[:max_timeout_period], timeout ].min

      if @config[:jitter]
        jitter_amount = timeout * @config[:max_jitter] * (rand - 0.5) * 2
        timeout += jitter_amount
      end

      timeout
    else
      base_timeout
    end
  end

  def calculate_next_retry_time
    return nil unless @last_failure_time
    @last_failure_time + calculate_timeout_period
  end

  def calculate_failure_rate
    total_attempts = @failure_count + @success_count
    return 0.0 if total_attempts == 0
    (@failure_count.to_f / total_attempts * 100).round(2)
  end

  def timeout_error?(error)
    error.is_a?(Timeout::Error) ||
    error.is_a?(Net::TimeoutError) ||
    error.message.downcase.include?("timeout")
  end

  def log_state_change(event, error = nil)
    message = "Circuit breaker '#{@name}' #{event}"
    message += ": #{error.class.name} - #{error.message}" if error

    case event
    when "opened", "opened_from_half_open"
      @logger.warn message
    when "closed", "reset"
      @logger.info message
    else
      @logger.debug message
    end
  end

  # Class methods for managing multiple circuit breakers
  class << self
    def registry
      @registry ||= {}
    end

    def for(name, config = {})
      registry[name] ||= new(name, config)
    end

    def reset_all!
      registry.values.each(&:reset!)
    end

    def metrics_for_all
      registry.transform_values(&:metrics)
    end
  end

  # Metrics collection for circuit breaker
  class CircuitBreakerMetrics
    attr_reader :total_calls, :successful_calls, :failed_calls, :circuit_opens, :circuit_closes

    def initialize
      @total_calls = 0
      @successful_calls = 0
      @failed_calls = 0
      @circuit_opens = 0
      @circuit_closes = 0
      @state_changes = []
    end

    def record_success
      @total_calls += 1
      @successful_calls += 1
    end

    def record_failure
      @total_calls += 1
      @failed_calls += 1
    end

    def record_circuit_open
      @circuit_opens += 1
      @state_changes << { event: "opened", timestamp: Time.current }
    end

    def record_circuit_close
      @circuit_closes += 1
      @state_changes << { event: "closed", timestamp: Time.current }
    end

    def success_rate
      return 0.0 if @total_calls == 0
      (@successful_calls.to_f / @total_calls * 100).round(2)
    end

    def failure_rate
      return 0.0 if @total_calls == 0
      (@failed_calls.to_f / @total_calls * 100).round(2)
    end

    def to_h
      {
        total_calls: @total_calls,
        successful_calls: @successful_calls,
        failed_calls: @failed_calls,
        circuit_opens: @circuit_opens,
        circuit_closes: @circuit_closes,
        success_rate: success_rate,
        failure_rate: failure_rate,
        state_changes: @state_changes
      }
    end
  end
end
