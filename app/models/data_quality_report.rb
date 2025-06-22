class DataQualityReport < ApplicationRecord
  belongs_to :data_source

  validates :overall_score, :completeness_score, :accuracy_score, 
           :consistency_score, :validity_score, :timeliness_score,
           presence: true, numericality: { in: 0..100 }
  validates :issues_count, :total_records, :valid_records,
           presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :run_at, presence: true

  scope :recent, -> { order(run_at: :desc) }
  scope :for_data_source, ->(data_source) { where(data_source: data_source) }
  scope :latest_for_each_source, -> { 
    joins(
      "INNER JOIN (
        SELECT data_source_id, MAX(run_at) as max_run_at 
        FROM data_quality_reports 
        GROUP BY data_source_id
      ) latest ON data_quality_reports.data_source_id = latest.data_source_id 
      AND data_quality_reports.run_at = latest.max_run_at"
    )
  }

  def self.latest_for_data_source(data_source)
    where(data_source: data_source).order(run_at: :desc).first
  end

  def quality_grade
    case overall_score
    when 90..100 then 'A'
    when 80..89 then 'B'
    when 70..79 then 'C'
    when 60..69 then 'D'
    else 'F'
    end
  end

  def quality_status
    case overall_score
    when 90..100 then 'excellent'
    when 80..89 then 'good'
    when 70..79 then 'fair'
    when 60..69 then 'poor'
    else 'critical'
    end
  end

  def issues
    report_data['issues'] || []
  end

  def recommendations
    report_data['recommendations'] || []
  end

  def validation_errors
    report_data['validation_errors'] || []
  end

  def summary
    {
      overall_score: overall_score,
      quality_grade: quality_grade,
      quality_status: quality_status,
      total_records: total_records,
      valid_records: valid_records,
      issues_count: issues_count,
      dimension_scores: {
        completeness: completeness_score,
        accuracy: accuracy_score,
        consistency: consistency_score,
        validity: validity_score,
        timeliness: timeliness_score
      }
    }
  end
end
