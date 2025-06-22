class ScheduledUploadsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_data_source
  before_action :set_scheduled_upload, only: [ :show, :edit, :update, :destroy, :toggle_status, :execute_now ]
  before_action :authorize_data_source_access

  def index
    @scheduled_uploads = @data_source.scheduled_uploads
                                     .includes(:upload_logs)
                                     .order(created_at: :desc)
                                     .page(params[:page])
                                     .per(20)

    @scheduled_uploads = @scheduled_uploads.where(active: params[:status] == "active") if params[:status].present?
  end

  def show
    @upload_logs = @scheduled_upload.upload_logs
                                   .order(started_at: :desc)
                                   .page(params[:page])
                                   .per(10)

    @recent_executions = @scheduled_upload.upload_logs
                                          .order(started_at: :desc)
                                          .limit(5)

    @success_rate = @scheduled_upload.success_rate
  end

  def new
    @scheduled_upload = @data_source.scheduled_uploads.build
    @scheduled_upload.frequency = "daily"
    @scheduled_upload.active = true
  end

  def create
    @scheduled_upload = @data_source.scheduled_uploads.build(scheduled_upload_params)
    @scheduled_upload.user = current_user

    if @scheduled_upload.save
      redirect_to [ @data_source, @scheduled_upload ],
                  notice: "Scheduled upload was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @scheduled_upload.update(scheduled_upload_params)
      redirect_to [ @data_source, @scheduled_upload ],
                  notice: "Scheduled upload was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @scheduled_upload.destroy
    redirect_to data_source_scheduled_uploads_path(@data_source),
                notice: "Scheduled upload was successfully deleted."
  end

  def toggle_status
    @scheduled_upload.update!(active: !@scheduled_upload.active?)

    status_text = @scheduled_upload.active? ? "activated" : "deactivated"

    respond_to do |format|
      format.html do
        redirect_to [ @data_source, @scheduled_upload ],
                    notice: "Scheduled upload was successfully #{status_text}."
      end
      format.json do
        render json: {
          success: true,
          active: @scheduled_upload.active?,
          message: "Scheduled upload #{status_text}"
        }
      end
    end
  end

  def execute_now
    if @scheduled_upload.active?
      job = ScheduledUploadJob.perform_later(@scheduled_upload.id)

      respond_to do |format|
        format.html do
          redirect_to [ @data_source, @scheduled_upload ],
                      notice: "Scheduled upload execution has been queued."
        end
        format.json do
          render json: {
            success: true,
            job_id: job.job_id,
            message: "Execution queued successfully"
          }
        end
      end
    else
      respond_to do |format|
        format.html do
          redirect_to [ @data_source, @scheduled_upload ],
                      alert: "Cannot execute inactive scheduled upload."
        end
        format.json do
          render json: {
            success: false,
            message: "Cannot execute inactive scheduled upload"
          }, status: :unprocessable_entity
        end
      end
    end
  end

  def logs
    @upload_logs = @data_source.scheduled_uploads
                               .joins(:upload_logs)
                               .includes(:upload_logs)
                               .order("upload_logs.started_at DESC")
                               .page(params[:page])
                               .per(20)

    if params[:status].present?
      @upload_logs = @upload_logs.where(upload_logs: { status: params[:status] })
    end

    if params[:scheduled_upload_id].present?
      @upload_logs = @upload_logs.where(id: params[:scheduled_upload_id])
    end
  end

  private

  def set_data_source
    @data_source = current_user.data_sources.find(params[:data_source_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to data_sources_path, alert: "Data source not found."
  end

  def set_scheduled_upload
    @scheduled_upload = @data_source.scheduled_uploads.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to data_source_scheduled_uploads_path(@data_source),
                alert: "Scheduled upload not found."
  end

  def authorize_data_source_access
    unless @data_source.user == current_user
      redirect_to data_sources_path, alert: "Access denied."
    end
  end

  def scheduled_upload_params
    params.require(:scheduled_upload).permit(
      :name, :description, :frequency, :active, :file_pattern,
      :notification_emails, :webhook_url, :max_file_age_hours,
      :delete_after_processing, :retry_failed_files,
      configuration: {}
    )
  end
end
