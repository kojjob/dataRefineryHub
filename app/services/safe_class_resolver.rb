# SafeClassResolver
# Safely resolves class names to actual classes using a whitelist approach
# Prevents arbitrary code execution through constantize
class SafeClassResolver
  class UnauthorizedClassError < StandardError; end
  
  # Whitelist of allowed classes that can be dynamically instantiated
  ALLOWED_CLASSES = {
    # ETL Jobs
    'DataExtractionJob' => DataExtractionJob,
    'DataTransformationJob' => DataTransformationJob,
    'DataLoadingJob' => DataLoadingJob,
    'PipelineExecutionJob' => PipelineExecutionJob,
    'DataSyncJob' => DataSyncJob,
    'DataQualityCheckJob' => DataQualityCheckJob,
    'WarehouseLoadJob' => WarehouseLoadJob,
    
    # ETL Services
    'DataExtractionService' => DataExtractionService,
    'DataTransformationService' => DataTransformationService,
    'WarehouseLoaderService' => WarehouseLoaderService,
    'DataQualityValidationService' => DataQualityValidationService,
    'DataTransformationPipelineService' => DataTransformationPipelineService,
    'EtlOrchestrationService' => EtlOrchestrationService,
    'CloudStorageService' => CloudStorageService,
    
    # Extractors
    'PostgresqlExtractor' => PostgresqlExtractor,
    'MysqlExtractor' => MysqlExtractor,
    'DatabaseExtractor' => DatabaseExtractor,
    'ApiExtractor' => ApiExtractor,
    'FileExtractor' => FileExtractor,
    'ShopifyExtractor' => ShopifyExtractor,
    'StripeExtractor' => StripeExtractor,
    'QuickbooksExtractor' => QuickbooksExtractor,
    
    # Delivery Channels
    'DeliveryChannels::EmailChannel' => DeliveryChannels::EmailChannel,
    'DeliveryChannels::SmsChannel' => DeliveryChannels::SmsChannel,
    'DeliveryChannels::SlackChannel' => DeliveryChannels::SlackChannel,
    'DeliveryChannels::WebhookChannel' => DeliveryChannels::WebhookChannel,
    'DeliveryChannels::InAppChannel' => DeliveryChannels::InAppChannel,
    
    # Models (for audit logs and similar)
    'User' => User,
    'Organization' => Organization,
    'Pipeline' => Pipeline,
    'DataSource' => DataSource,
    'ExtractionJob' => ExtractionJob,
    'PipelineExecution' => PipelineExecution,
    'Task' => Task,
    'AuditLog' => AuditLog,
    'IndustryTemplate' => IndustryTemplate,
    'DeliveryPreference' => DeliveryPreference,
    
    # Domain Events
    'Domain::PipelineManagement::Events::PipelineCreated' => 
      defined?(Domain::PipelineManagement::Events::PipelineCreated) ? 
      Domain::PipelineManagement::Events::PipelineCreated : nil,
    'Domain::PipelineManagement::Events::PipelineUpdated' => 
      defined?(Domain::PipelineManagement::Events::PipelineUpdated) ? 
      Domain::PipelineManagement::Events::PipelineUpdated : nil,
    'Domain::PipelineManagement::Events::PipelineDeleted' => 
      defined?(Domain::PipelineManagement::Events::PipelineDeleted) ? 
      Domain::PipelineManagement::Events::PipelineDeleted : nil,
    'Domain::PipelineManagement::Events::PipelineExecuted' => 
      defined?(Domain::PipelineManagement::Events::PipelineExecuted) ? 
      Domain::PipelineManagement::Events::PipelineExecuted : nil
  }.compact.freeze
  
  # Alternative mappings for common variations
  CLASS_ALIASES = {
    'PostgreSQLExtractor' => 'PostgresqlExtractor',
    'MySQLExtractor' => 'MysqlExtractor',
    'QuickBooksExtractor' => 'QuickbooksExtractor',
    'DataExtractionService' => 'DataExtractionService',
    'DataTransformationService' => 'DataTransformationService'
  }.freeze
  
  class << self
    def resolve(class_name, options = {})
      return nil if class_name.blank?
      
      # Normalize the class name
      normalized_name = normalize_class_name(class_name)
      
      # Check if it's in the whitelist
      klass = ALLOWED_CLASSES[normalized_name]
      
      # If not found, check aliases
      if klass.nil? && CLASS_ALIASES[normalized_name]
        klass = ALLOWED_CLASSES[CLASS_ALIASES[normalized_name]]
      end
      
      # If still not found and we're in a specific namespace, try to resolve it
      if klass.nil? && options[:namespace]
        namespaced_name = "#{options[:namespace]}::#{normalized_name}"
        klass = ALLOWED_CLASSES[namespaced_name]
      end
      
      # Raise error if class is not whitelisted
      if klass.nil?
        if options[:raise_on_error] != false
          raise UnauthorizedClassError, 
            "Class '#{class_name}' is not authorized for dynamic instantiation. " \
            "Add it to SafeClassResolver::ALLOWED_CLASSES if this is intentional."
        else
          Rails.logger.warn "Attempted to resolve unauthorized class: #{class_name}"
          return nil
        end
      end
      
      klass
    end
    
    def resolve!(class_name, options = {})
      resolve(class_name, options.merge(raise_on_error: true))
    end
    
    def authorized?(class_name)
      normalized_name = normalize_class_name(class_name)
      ALLOWED_CLASSES.key?(normalized_name) || 
        (CLASS_ALIASES[normalized_name] && ALLOWED_CLASSES.key?(CLASS_ALIASES[normalized_name]))
    end
    
    def add_allowed_class(class_name, klass)
      # This method should only be used during initialization
      # and should be protected in production
      if Rails.env.production?
        raise "Cannot modify allowed classes in production"
      end
      
      @additional_classes ||= {}
      @additional_classes[class_name] = klass
    end
    
    private
    
    def normalize_class_name(class_name)
      # Remove any leading :: and standardize the format
      class_name.to_s.gsub(/^::/, '')
    end
  end
  
  # Instance methods for compatibility
  def initialize(options = {})
    @options = options
  end
  
  def resolve(class_name)
    self.class.resolve(class_name, @options)
  end
  
  def resolve!(class_name)
    self.class.resolve!(class_name, @options)
  end
end