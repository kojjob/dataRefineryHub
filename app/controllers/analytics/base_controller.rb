class Analytics::BaseController < DataflowProController
  before_action :authenticate_user!
  before_action :ensure_organization_member

  protected

  def calculate_date_range(range)
    case range
    when "7_days"
      [ 7.days.ago.beginning_of_day, Time.current.end_of_day ]
    when "30_days"
      [ 30.days.ago.beginning_of_day, Time.current.end_of_day ]
    when "90_days"
      [ 90.days.ago.beginning_of_day, Time.current.end_of_day ]
    when "1_year"
      [ 1.year.ago.beginning_of_day, Time.current.end_of_day ]
    when "custom"
      start_date = params[:start_date].present? ? Date.parse(params[:start_date]).beginning_of_day : 30.days.ago.beginning_of_day
      end_date = params[:end_date].present? ? Date.parse(params[:end_date]).end_of_day : Time.current.end_of_day
      [ start_date, end_date ]
    else
      [ 30.days.ago.beginning_of_day, Time.current.end_of_day ]
    end
  end

  def calculate_percentage_change(old_value, new_value)
    return 0 if old_value.nil? || old_value.zero?
    ((new_value - old_value) / old_value.to_f * 100).round(1)
  end

  def calculate_variance(values)
    return 0 if values.empty?
    mean = values.sum / values.length.to_f
    variance = values.sum { |v| (v - mean) ** 2 } / values.length.to_f
    Math.sqrt(variance)
  end

  # Common data access helpers
  def extraction_jobs_scope
    ExtractionJob.joins(:data_source)
      .where(data_sources: { organization_id: current_organization.id })
      .where(created_at: @start_date..@end_date)
  end

  def raw_data_records_scope
    RawDataRecord.joins(:data_source)
      .where(data_sources: { organization_id: current_organization.id })
      .where(created_at: @start_date..@end_date)
  end

  def order_records_scope
    RawDataRecord.joins(:data_source)
      .where(data_sources: { organization_id: current_organization.id, source_type: [ "shopify", "woocommerce", "stripe" ] })
      .where(record_type: "order")
      .where(created_at: @start_date..@end_date)
  end

  def customer_records_scope
    RawDataRecord.joins(:data_source)
      .where(data_sources: { organization_id: current_organization.id, source_type: [ "shopify", "woocommerce", "stripe" ] })
      .where(record_type: "customer")
      .where(created_at: @start_date..@end_date)
  end

  def product_records_scope
    RawDataRecord.joins(:data_source)
      .where(data_sources: { organization_id: current_organization.id, source_type: [ "shopify", "woocommerce" ] })
      .where(record_type: "product")
      .where(created_at: @start_date..@end_date)
  end
end
