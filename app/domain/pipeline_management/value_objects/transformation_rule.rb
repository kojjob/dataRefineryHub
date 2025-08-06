# frozen_string_literal: true

module Domain
  module PipelineManagement
    module ValueObjects
      # Transformation rule value object
      class TransformationRule
        include ActiveModel::Model

        TYPES = %w[
          rename_field
          filter_rows
          calculate_field
          aggregate
          join
          pivot
          unpivot
          type_cast
          normalize
          custom_script
        ].freeze

        attr_reader :type, :name, :configuration, :position

        validates :type, inclusion: { in: TYPES }
        validates :name, presence: true
        validates :configuration, presence: true
        validates :position, numericality: { greater_than: 0 }
        validate :validate_configuration

        def initialize(type:, name:, configuration:, position: 1)
          @type = type
          @name = name
          @configuration = configuration.deep_symbolize_keys
          @position = position
          validate!
        end

        def apply_to(data)
          case type
          when "rename_field"
            apply_rename_field(data)
          when "filter_rows"
            apply_filter_rows(data)
          when "calculate_field"
            apply_calculate_field(data)
          when "type_cast"
            apply_type_cast(data)
          when "normalize"
            apply_normalize(data)
          else
            # For complex transformations, delegate to transformation engine
            data
          end
        end

        def to_h
          {
            type: type,
            name: name,
            configuration: configuration,
            position: position
          }
        end

        def ==(other)
          other.is_a?(self.class) &&
            type == other.type &&
            name == other.name &&
            configuration == other.configuration &&
            position == other.position
        end

        private

        def validate_configuration
          case type
          when "rename_field"
            validate_rename_field_config
          when "filter_rows"
            validate_filter_rows_config
          when "calculate_field"
            validate_calculate_field_config
          when "type_cast"
            validate_type_cast_config
          when "custom_script"
            validate_custom_script_config
          end
        end

        def validate_rename_field_config
          unless configuration[:from] && configuration[:to]
            errors.add(:configuration, "must include from and to fields")
          end
        end

        def validate_filter_rows_config
          unless configuration[:conditions]
            errors.add(:configuration, "must include conditions")
          end
        end

        def validate_calculate_field_config
          unless configuration[:field_name] && configuration[:expression]
            errors.add(:configuration, "must include field_name and expression")
          end
        end

        def validate_type_cast_config
          unless configuration[:field] && configuration[:target_type]
            errors.add(:configuration, "must include field and target_type")
          end
        end

        def validate_custom_script_config
          unless configuration[:language] && configuration[:script]
            errors.add(:configuration, "must include language and script")
          end
        end

        def apply_rename_field(data)
          from = configuration[:from].to_s
          to = configuration[:to].to_s

          data.map do |row|
            if row.key?(from)
              row.except(from).merge(to => row[from])
            else
              row
            end
          end
        end

        def apply_filter_rows(data)
          conditions = configuration[:conditions]

          data.select do |row|
            evaluate_conditions(row, conditions)
          end
        end

        def apply_calculate_field(data)
          field_name = configuration[:field_name].to_s
          expression = configuration[:expression]

          data.map do |row|
            row.merge(field_name => evaluate_expression(row, expression))
          end
        end

        def apply_type_cast(data)
          field = configuration[:field].to_s
          target_type = configuration[:target_type].to_s

          data.map do |row|
            if row.key?(field)
              row.merge(field => cast_value(row[field], target_type))
            else
              row
            end
          end
        end

        def apply_normalize(data)
          field = configuration[:field].to_s
          method = configuration[:method].to_s

          data.map do |row|
            if row.key?(field)
              row.merge(field => normalize_value(row[field], method))
            else
              row
            end
          end
        end

        def evaluate_conditions(row, conditions)
          # Simple condition evaluation - in production, use a proper expression evaluator
          conditions.all? do |condition|
            field = condition["field"]
            operator = condition["operator"]
            value = condition["value"]

            case operator
            when "="
              row[field] == value
            when "!="
              row[field] != value
            when ">"
              row[field] > value
            when "<"
              row[field] < value
            when "contains"
              row[field].to_s.include?(value.to_s)
            else
              true
            end
          end
        end

        def evaluate_expression(row, expression)
          # Simple expression evaluation - in production, use a proper expression evaluator
          # This is a placeholder implementation
          expression
        end

        def cast_value(value, target_type)
          case target_type
          when "integer"
            value.to_i
          when "float"
            value.to_f
          when "string"
            value.to_s
          when "boolean"
            ActiveModel::Type::Boolean.new.cast(value)
          when "date"
            Date.parse(value.to_s) rescue nil
          when "datetime"
            DateTime.parse(value.to_s) rescue nil
          else
            value
          end
        end

        def normalize_value(value, method)
          case method
          when "lowercase"
            value.to_s.downcase
          when "uppercase"
            value.to_s.upcase
          when "trim"
            value.to_s.strip
          when "remove_special_chars"
            value.to_s.gsub(/[^0-9A-Za-z\s]/, "")
          else
            value
          end
        end
      end
    end
  end
end
