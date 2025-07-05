# frozen_string_literal: true

class Result
  attr_reader :data, :errors, :metadata

  def initialize(success:, data: nil, errors: [], metadata: {})
    @success = success
    @data = data
    @errors = Array(errors)
    @metadata = metadata
  end

  def success?
    @success
  end

  def failure?
    !success?
  end

  def error_messages
    errors.join(", ")
  end

  def to_h
    {
      success: success?,
      data: data,
      errors: errors,
      metadata: metadata
    }
  end

  def to_json(*args)
    to_h.to_json(*args)
  end

  class << self
    def success(data = nil, metadata = {})
      new(success: true, data: data, metadata: metadata)
    end

    def failure(errors, metadata = {})
      new(success: false, errors: errors, metadata: metadata)
    end

    def from_exception(exception, metadata = {})
      failure(
        "#{exception.class.name}: #{exception.message}",
        metadata.merge(backtrace: exception.backtrace&.first(5))
      )
    end
  end
end
