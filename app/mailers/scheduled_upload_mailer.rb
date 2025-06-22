class ScheduledUploadMailer < ApplicationMailer
  default from: "notifications@datarefineryplatform.com"

  def execution_summary(scheduled_upload:, log_entry:, recipients:)
    @scheduled_upload = scheduled_upload
    @log_entry = log_entry
    @data_source = scheduled_upload.data_source
    @user = scheduled_upload.user

    @status_color = case @log_entry.status
    when "completed"
                      "#10B981" # Green
    when "completed_with_errors"
                      "#F59E0B" # Yellow
    when "failed"
                      "#EF4444" # Red
    else
                      "#6B7280" # Gray
    end

    @status_text = case @log_entry.status
    when "completed"
                     "Successfully Completed"
    when "completed_with_errors"
                     "Completed with Errors"
    when "failed"
                     "Failed"
    else
                     @log_entry.status.humanize
    end

    subject = "[Data Refinery] Scheduled Upload #{@status_text}: #{@scheduled_upload.name}"

    mail(
      to: recipients,
      subject: subject
    )
  end

  def error_notification(scheduled_upload:, error_message:, recipients:)
    @scheduled_upload = scheduled_upload
    @error_message = error_message
    @data_source = scheduled_upload.data_source
    @user = scheduled_upload.user

    subject = "[Data Refinery] Scheduled Upload Error: #{@scheduled_upload.name}"

    mail(
      to: recipients,
      subject: subject
    )
  end
end
