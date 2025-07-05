# TaskTemplate Model
# Defines reusable task templates for common pipeline operations
# Supports customizable configurations and execution modes
class TaskTemplate < ApplicationRecord
  belongs_to :organization
  has_many :tasks

  # Constants
  CATEGORIES = %w[extraction transformation validation notification approval data_quality custom].freeze

  # Validations
  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :task_type, presence: true, inclusion: { in: Task::TASK_TYPES }
  validates :execution_mode, presence: true, inclusion: { in: Task::EXECUTION_MODES }
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :default_timeout, numericality: { greater_than: 0 }, allow_nil: true
  validates :default_priority, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :default_weight, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_execution_mode, ->(mode) { where(execution_mode: mode) }
  scope :for_pipeline_type, ->(type) { where("tags LIKE ?", "%#{type}%") }
  scope :search, ->(query) { where("name ILIKE ? OR description ILIKE ?", "%#{query}%", "%#{query}%") }

  # Callbacks
  before_create :set_defaults

  # Instance methods
  def create_task_from_template(pipeline_execution, overrides = {})
    task_attributes = {
      pipeline_execution: pipeline_execution,
      name: overrides[:name] || name,
      description: overrides[:description] || description,
      task_type: task_type,
      execution_mode: execution_mode,
      configuration: merge_configurations(template_config, overrides[:configuration]),
      timeout_seconds: overrides[:timeout_seconds] || default_timeout || 300,
      priority: overrides[:priority] || default_priority || 0,
      task_template: self,
      metadata: {
        template_id: id,
        template_name: name,
        created_from_template: true
      }
    }

    Task.create!(task_attributes)
  end

  def duplicate_template(new_name = nil)
    new_template = dup
    new_template.name = new_name || "#{name} (Copy)"
    new_template.active = false # Start as inactive
    new_template.save!
    new_template
  end

  def applicable_for?(pipeline_type)
    return true if tags.blank?
    tag_list.include?(pipeline_type.to_s.downcase)
  end

  def tag_list
    tags.to_s.split(",").map(&:strip).map(&:downcase)
  end

  def add_tag(tag)
    current_tags = tag_list
    current_tags << tag.downcase unless current_tags.include?(tag.downcase)
    self.tags = current_tags.join(", ")
  end

  def remove_tag(tag)
    current_tags = tag_list
    current_tags.delete(tag.downcase)
    self.tags = current_tags.join(", ")
  end

  # Template library methods
  def self.common_templates
    {
      extraction: [
        {
          name: "API Data Extraction",
          description: "Extract data from REST API endpoints",
          task_type: "extraction",
          execution_mode: "automated",
          category: "extraction",
          template_config: {
            method: "GET",
            pagination: true,
            rate_limit: 100,
            retry_strategy: "exponential_backoff"
          }
        },
        {
          name: "Database Query Extraction",
          description: "Extract data using SQL queries",
          task_type: "extraction",
          execution_mode: "automated",
          category: "extraction",
          template_config: {
            query_type: "select",
            batch_size: 1000,
            timeout: 300
          }
        },
        {
          name: "File Upload Processing",
          description: "Process uploaded CSV/Excel files",
          task_type: "extraction",
          execution_mode: "manual",
          category: "extraction",
          template_config: {
            accepted_formats: [ "csv", "xlsx", "xls" ],
            max_file_size: 104857600, # 100MB
            encoding: "UTF-8"
          }
        }
      ],
      transformation: [
        {
          name: "Data Normalization",
          description: "Normalize and standardize data formats",
          task_type: "transformation",
          execution_mode: "automated",
          category: "transformation",
          template_config: {
            operations: [ "trim_whitespace", "lowercase_keys", "parse_dates" ],
            date_format: "ISO8601"
          }
        },
        {
          name: "Data Deduplication",
          description: "Remove duplicate records based on key fields",
          task_type: "transformation",
          execution_mode: "automated",
          category: "transformation",
          template_config: {
            dedup_keys: [],
            keep_strategy: "first",
            case_sensitive: false
          }
        },
        {
          name: "Field Mapping",
          description: "Map source fields to destination schema",
          task_type: "transformation",
          execution_mode: "manual",
          category: "transformation",
          template_config: {
            auto_map: true,
            strict_mode: false,
            default_values: {}
          }
        }
      ],
      validation: [
        {
          name: "Data Quality Check",
          description: "Comprehensive data quality validation",
          task_type: "validation",
          execution_mode: "automated",
          category: "data_quality",
          template_config: {
            checks: [ "completeness", "accuracy", "consistency", "validity" ],
            threshold: 95,
            fail_on_error: false
          }
        },
        {
          name: "Schema Validation",
          description: "Validate data against defined schema",
          task_type: "validation",
          execution_mode: "automated",
          category: "validation",
          template_config: {
            strict_mode: true,
            allow_extra_fields: false,
            coerce_types: true
          }
        },
        {
          name: "Business Rules Validation",
          description: "Apply custom business rule validations",
          task_type: "validation",
          execution_mode: "approval_required",
          category: "validation",
          template_config: {
            rules: [],
            continue_on_failure: true,
            generate_report: true
          }
        }
      ],
      notification: [
        {
          name: "Success Notification",
          description: "Send notification on successful completion",
          task_type: "notification",
          execution_mode: "automated",
          category: "notification",
          template_config: {
            channels: [ "email" ],
            include_summary: true,
            include_metrics: true
          }
        },
        {
          name: "Error Alert",
          description: "Send alert on pipeline errors",
          task_type: "notification",
          execution_mode: "automated",
          category: "notification",
          template_config: {
            channels: [ "email", "slack" ],
            severity: "high",
            include_stack_trace: false
          }
        }
      ],
      approval: [
        {
          name: "Manager Approval",
          description: "Require manager approval before proceeding",
          task_type: "approval",
          execution_mode: "approval_required",
          category: "approval",
          template_config: {
            approver_role: "manager",
            timeout_hours: 24,
            auto_approve: false
          }
        },
        {
          name: "Data Review Checkpoint",
          description: "Manual review of processed data",
          task_type: "approval",
          execution_mode: "manual",
          category: "approval",
          template_config: {
            review_items: [ "data_quality", "business_rules", "completeness" ],
            require_notes: true
          }
        }
      ]
    }
  end

  def self.create_default_templates_for(organization)
    common_templates.each do |category, templates|
      templates.each do |template_attrs|
        organization.task_templates.create!(
          template_attrs.merge(
            active: true,
            default_timeout: 300,
            default_priority: 0,
            default_weight: 1
          )
        )
      end
    end
  end

  private

  def set_defaults
    self.active = true if active.nil?
    self.template_config ||= {}
    self.default_timeout ||= 300
    self.default_priority ||= 0
    self.default_weight ||= 1
  end

  def merge_configurations(base_config, override_config)
    return base_config if override_config.blank?
    base_config.deep_merge(override_config)
  end
end
