# frozen_string_literal: true

class Presentation < ApplicationRecord
  belongs_to :organization
  belongs_to :user, optional: true
  
  validates :title, presence: true
  validates :template_type, presence: true, inclusion: { in: %w[executive_summary quarterly_review monthly_report custom] }
  validates :output_format, presence: true, inclusion: { in: %w[pdf powerpoint html] }
  validates :status, presence: true, inclusion: { in: %w[generating completed failed] }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: 'completed') }
  scope :by_template, ->(template) { where(template_type: template) }
  scope :by_format, ->(format) { where(output_format: format) }
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def generating?
    status == 'generating'
  end
  
  def file_exists?
    file_path.present? && File.exist?(file_path)
  end
  
  def file_size
    return 0 unless file_exists?
    File.size(file_path)
  end
  
  def formatted_file_size
    return "0 B" unless file_exists?
    
    size = file_size
    units = %w[B KB MB GB]
    
    return "#{size} B" if size < 1024
    
    units.each_with_index do |unit, index|
      if size < (1024 ** (index + 1))
        return "#{(size.to_f / (1024 ** index)).round(1)} #{unit}"
      end
    end
    
    "#{(size.to_f / (1024 ** 3)).round(1)} GB"
  end
  
  def slides_data
    return {} unless content.present?
    JSON.parse(content)
  rescue JSON::ParserError
    {}
  end
  
  def slides_count
    slides_data.dig('total_slides') || 0
  end
  
  def template_display_name
    template_type.humanize
  end
  
  def format_display_name
    case output_format
    when 'pdf'
      'PDF Document'
    when 'powerpoint'
      'PowerPoint Presentation'
    when 'html'
      'HTML Presentation'
    else
      output_format.upcase
    end
  end
  
  def can_download?
    completed? && file_exists?
  end
  
  def generation_duration
    return nil unless generated_at && created_at
    generated_at - created_at
  end
  
  def formatted_generation_duration
    duration = generation_duration
    return "N/A" unless duration
    
    if duration < 60
      "#{duration.round} seconds"
    else
      "#{(duration / 60).round} minutes"
    end
  end
  
  # Class methods for analytics
  def self.generation_stats
    {
      total_generated: completed.count,
      average_generation_time: average_generation_time,
      popular_templates: popular_templates,
      popular_formats: popular_formats,
      success_rate: success_rate
    }
  end
  
  def self.average_generation_time
    presentations = completed.where.not(generated_at: nil)
    return 0 if presentations.empty?
    
    total_time = presentations.sum { |p| p.generation_duration || 0 }
    (total_time / presentations.count).round(2)
  end
  
  def self.popular_templates
    group(:template_type).count.sort_by { |_, count| -count }.to_h
  end
  
  def self.popular_formats
    group(:output_format).count.sort_by { |_, count| -count }.to_h
  end
  
  def self.success_rate
    return 0 if count == 0
    (completed.count.to_f / count * 100).round(1)
  end
end