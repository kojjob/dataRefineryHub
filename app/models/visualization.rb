class Visualization < ApplicationRecord
  belongs_to :organization
  belongs_to :data_source
  belongs_to :user

  validates :title, presence: true, length: { maximum: 255 }
  validates :chart_type, presence: true, inclusion: { in: %w[bar line pie doughnut horizontalBar] }
  validates :x_column, presence: true
  validates :y_column, presence: true
  validates :aggregation, presence: true, inclusion: { in: %w[sum avg count max min] }

  scope :by_data_source, ->(data_source) { where(data_source: data_source) }
  scope :by_user, ->(user) { where(user: user) }
  scope :recent, -> { order(created_at: :desc) }

  def config
    super || {}
  end

  def full_config
    {
      chart_type: chart_type,
      x_column: x_column,
      y_column: y_column,
      aggregation: aggregation,
      filter_column: filter_column,
      filter_value: filter_value,
      title: title
    }.merge(config)
  end

  def to_chart_config
    {
      type: chart_type,
      title: title,
      x_axis: x_column,
      y_axis: y_column,
      aggregation: aggregation,
      filters: {
        column: filter_column,
        value: filter_value
      }.compact
    }
  end
end
