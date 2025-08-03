# frozen_string_literal: true

class DeliveryPreferencesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_delivery_preference, only: [:show, :edit, :update, :destroy, :toggle]

  def index
    @delivery_preferences = current_user.delivery_preferences
                                        .includes(:organization)
                                        .order(report_type: :asc, channel: :asc)
    
    @grouped_preferences = @delivery_preferences.group_by(&:report_type)
  end

  def new
    @delivery_preference = current_user.delivery_preferences.build(
      organization: current_organization
    )
    
    # Pre-populate with sensible defaults
    @delivery_preference.channel = 'email'
    @delivery_preference.format = 'html'
    @delivery_preference.active = true
  end

  def create
    @delivery_preference = current_user.delivery_preferences.build(delivery_preference_params)
    @delivery_preference.organization = current_organization

    if @delivery_preference.save
      # Schedule if needed
      if @delivery_preference.scheduled?
        DeliverySchedulerJob.schedule_preference(@delivery_preference)
      end
      
      redirect_to delivery_preferences_path, 
                  notice: 'Delivery preference created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @recent_logs = @delivery_preference.delivery_logs
                                      .recent
                                      .limit(10)
  end

  def edit
  end

  def update
    # Check if schedule changed
    schedule_changed = @delivery_preference.schedule != delivery_preference_params[:schedule]
    
    if @delivery_preference.update(delivery_preference_params)
      # Reschedule if needed
      if schedule_changed
        if @delivery_preference.scheduled?
          DeliverySchedulerJob.schedule_preference(@delivery_preference)
        else
          DeliverySchedulerJob.remove_scheduled_preference(@delivery_preference)
        end
      end
      
      redirect_to delivery_preferences_path, 
                  notice: 'Delivery preference updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Remove any scheduled jobs
    if @delivery_preference.scheduled?
      DeliverySchedulerJob.remove_scheduled_preference(@delivery_preference)
    end
    
    @delivery_preference.destroy
    redirect_to delivery_preferences_path, 
                notice: 'Delivery preference removed successfully.'
  end

  def toggle
    @delivery_preference.toggle!(:active)
    
    # Update scheduling based on new state
    if @delivery_preference.active? && @delivery_preference.scheduled?
      DeliverySchedulerJob.schedule_preference(@delivery_preference)
    elsif !@delivery_preference.active? && @delivery_preference.scheduled?
      DeliverySchedulerJob.remove_scheduled_preference(@delivery_preference)
    end
    
    respond_to do |format|
      format.html { redirect_to delivery_preferences_path }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          @delivery_preference,
          partial: 'delivery_preference',
          locals: { delivery_preference: @delivery_preference }
        )
      end
    end
  end

  # Preview report in specified format
  def preview
    @delivery_preference = current_user.delivery_preferences
                                      .find_by(id: params[:id])
    
    unless @delivery_preference
      redirect_to delivery_preferences_path, alert: 'Preference not found'
      return
    end
    
    # Generate sample report data
    report_data = generate_sample_report_data(@delivery_preference.report_type)
    
    orchestrator = DeliveryOrchestratorService.new(
      organization: current_organization,
      report_type: @delivery_preference.report_type,
      report_data: report_data
    )
    
    @preview_content = orchestrator.preview(
      format: @delivery_preference.format,
      channel: @delivery_preference.channel
    )
    
    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  # Test delivery
  def test_delivery
    @delivery_preference = current_user.delivery_preferences
                                      .find_by(id: params[:id])
    
    unless @delivery_preference
      redirect_to delivery_preferences_path, alert: 'Preference not found'
      return
    end
    
    # Generate sample report data
    report_data = generate_sample_report_data(@delivery_preference.report_type)
    
    orchestrator = DeliveryOrchestratorService.new(
      organization: current_organization,
      report_type: @delivery_preference.report_type,
      report_data: report_data,
      options: { test_mode: true }
    )
    
    result = orchestrator.deliver_via_channel(
      user: current_user,
      channel: @delivery_preference.channel,
      format: @delivery_preference.format
    )
    
    if result[:success]
      redirect_to delivery_preferences_path, 
                  notice: "Test #{@delivery_preference.channel} sent successfully!"
    else
      redirect_to delivery_preferences_path, 
                  alert: "Test delivery failed: #{result[:error]}"
    end
  end

  private

  def set_delivery_preference
    @delivery_preference = current_user.delivery_preferences.find(params[:id])
  end

  def delivery_preference_params
    params.require(:delivery_preference).permit(
      :report_type, :channel, :format, :schedule, :active,
      :timezone, :delivery_time,
      options: {}
    )
  end

  def generate_sample_report_data(report_type)
    case report_type
    when 'daily_summary'
      {
        revenue: { total: 15234.50, change: 12.5, currency: 'USD' },
        orders: { count: 45, change: 8.2, average: 338.54 },
        customers: { new: 12, returning: 33, total_active: 156 },
        top_products: [
          { name: 'Premium Widget', units: 23, revenue: 4567.00 },
          { name: 'Basic Widget', units: 45, revenue: 2250.00 }
        ],
        insights: ['Revenue up 12.5% from yesterday', 'New customer acquisition trending up'],
        alerts: []
      }
    when 'weekly_report'
      {
        week_start: Date.current.beginning_of_week,
        week_end: Date.current.end_of_week,
        summary: {
          revenue: 95234.50,
          orders: 312,
          aov: 305.24,
          growth: 15.3
        },
        daily_breakdown: {
          'Monday' => { revenue: 12000, orders: 40 },
          'Tuesday' => { revenue: 15000, orders: 52 }
        }
      }
    else
      {
        title: report_type.humanize,
        generated_at: Time.current,
        sample_data: 'This is sample data for preview'
      }
    end
  end
end