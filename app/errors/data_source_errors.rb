# frozen_string_literal: true

module DataSourceErrors
  class BaseError < StandardError
    attr_reader :code, :context

    def initialize(message = nil, code: nil, context: {})
      super(message)
      @code = code
      @context = context
    end

    def to_h
      {
        error: self.class.name.demodulize,
        message: message,
        code: code,
        context: context
      }
    end
  end

  class InvalidFileFormat < BaseError
    def initialize(format = nil)
      super(
        "Invalid file format#{format ? ": #{format}" : ''}",
        code: 'INVALID_FORMAT'
      )
    end
  end

  class FileSizeExceeded < BaseError
    def initialize(size = nil, limit = nil)
      message = 'File size exceeds limit'
      message += " (#{size} > #{limit})" if size && limit
      super(message, code: 'SIZE_EXCEEDED')
    end
  end

  class ProcessingTimeout < BaseError
    def initialize(timeout = nil)
      message = 'File processing timed out'
      message += " after #{timeout} seconds" if timeout
      super(message, code: 'PROCESSING_TIMEOUT')
    end
  end

  class ExtractionFailed < BaseError
    def initialize(source_type = nil, reason = nil)
      message = 'Data extraction failed'
      message += " for #{source_type}" if source_type
      message += ": #{reason}" if reason
      super(message, code: 'EXTRACTION_FAILED')
    end
  end

  class ValidationFailed < BaseError
    def initialize(field = nil, reason = nil)
      message = 'Data validation failed'
      message += " for field '#{field}'" if field
      message += ": #{reason}" if reason
      super(message, code: 'VALIDATION_FAILED')
    end
  end

  class ConnectionFailed < BaseError
    def initialize(source_type = nil, reason = nil)
      message = 'Connection failed'
      message += " to #{source_type}" if source_type
      message += ": #{reason}" if reason
      super(message, code: 'CONNECTION_FAILED')
    end
  end

  class AuthenticationFailed < BaseError
    def initialize(source_type = nil)
      message = 'Authentication failed'
      message += " for #{source_type}" if source_type
      super(message, code: 'AUTH_FAILED')
    end
  end

  class RateLimitExceeded < BaseError
    def initialize(source_type = nil, retry_after = nil)
      message = 'Rate limit exceeded'
      message += " for #{source_type}" if source_type
      context = retry_after ? { retry_after: retry_after } : {}
      super(message, code: 'RATE_LIMIT_EXCEEDED', context: context)
    end
  end
end