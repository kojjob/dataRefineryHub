# frozen_string_literal: true

class DataSourceRegistry
  include Singleton

  def initialize
    @configurations = load_configurations
  end

  private

  def load_configurations
    config_file = Rails.root.join("config", "data_sources.yml")
    raw_config = YAML.load_file(config_file, aliases: true)[Rails.env] || {}

    # Convert string keys to symbols and process settings
    raw_config.deep_transform_keys(&:to_sym).tap do |config|
      config.each do |key, source_config|
        # Convert file size from MB to bytes for file_upload
        if key == :file_upload && source_config.dig(:settings, :max_size_mb)
          source_config[:settings][:max_size] = source_config[:settings][:max_size_mb].megabytes
        end
      end
    end
  rescue => e
    Rails.logger.error "Failed to load data source configurations: #{e.message}"
    {}
  end

  def self.all
    configurations
  end

  def self.available
    all.select { |_, config| config[:status] == "available" && config[:implemented] }
  end

  def self.coming_soon
    all.select { |_, config| config[:status] == "coming_soon" || !config[:implemented] }
  end

  def self.by_category(category)
    all.select { |_, config| config[:category] == category.to_s }
  end

  def self.find(source_type)
    all[source_type.to_sym]
  end

  def self.priority_integrations
    all.select { |_, config| config[:priority] <= 3 && config[:implemented] }
  end

  def self.growth_integrations
    all.select { |_, config| config[:priority].between?(4, 6) && config[:implemented] }
  end

  def self.enterprise_integrations
    all.select { |_, config| config[:priority] > 6 }
  end

  def self.configurations
    instance.send(:configurations)
  end

  def self.sync_frequency_options
    {
      "real-time" => "Real-time sync",
      "scheduled" => "Scheduled sync (daily)",
      "manual" => "Manual upload"
    }
  end

  def self.file_upload_settings
    find(:file_upload)&.dig(:settings) || {}
  end

  private

  def configurations
    @configurations
  end
end
