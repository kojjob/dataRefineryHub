# frozen_string_literal: true

class ReportMailer < ApplicationMailer
  # Text-only report email
  def text_report
    @user = params[:user]
    @organization = params[:organization]
    @body = params[:body]

    mail(
      to: @user.email,
      subject: params[:subject],
      content_type: "text/plain"
    )
  end

  # HTML report email
  def html_report
    @user = params[:user]
    @organization = params[:organization]
    @html_body = params[:html_body]
    @text_body = params[:text_body]

    mail(
      to: @user.email,
      subject: params[:subject]
    ) do |format|
      format.text { render plain: @text_body }
      format.html { render html: @html_body.html_safe }
    end
  end

  # Report with PDF attachment
  def report_with_attachment
    @user = params[:user]
    @organization = params[:organization]
    @body = params[:body]

    attachments[params[:pdf_filename]] = {
      mime_type: "application/pdf",
      content: params[:pdf_content]
    }

    mail(
      to: @user.email,
      subject: params[:subject]
    )
  end

  # Presentation delivery email
  def presentation_delivery
    @user = params[:user]
    @organization = params[:organization]
    @body = params[:body]

    attachments[params[:attachment_name]] = File.read(params[:attachment_path])

    mail(
      to: @user.email,
      subject: params[:subject]
    )
  end

  # Multi-format report email
  def multi_format_report
    @user = params[:user]
    @organization = params[:organization]
    @report_data = params[:report_data]
    @report_type = params[:report_type]

    # Attach multiple formats if requested
    if params[:include_pdf]
      pdf_content = PdfReportGenerator.new(
        report: { type: @report_type, data: @report_data },
        organization: @organization,
        user: @user
      ).generate_pdf_content

      attachments["#{@report_type}_report.pdf"] = {
        mime_type: "application/pdf",
        content: pdf_content
      }
    end

    if params[:include_csv]
      csv_content = generate_csv_content(@report_data)
      attachments["#{@report_type}_data.csv"] = {
        mime_type: "text/csv",
        content: csv_content
      }
    end

    mail(
      to: @user.email,
      subject: params[:subject] || default_subject
    )
  end

  private

  def default_subject
    "#{@organization.name} - #{@report_type.humanize} Report - #{Date.current}"
  end

  def generate_csv_content(data)
    CSV.generate do |csv|
      # Add headers based on first data element
      if data.is_a?(Array) && data.first.is_a?(Hash)
        csv << data.first.keys.map(&:to_s)
        data.each { |row| csv << row.values }
      elsif data.is_a?(Hash)
        data.each do |section, values|
          csv << [ section.to_s.upcase ]

          if values.is_a?(Array) && values.first.is_a?(Hash)
            csv << values.first.keys.map(&:to_s)
            values.each { |row| csv << row.values }
          elsif values.is_a?(Hash)
            values.each { |k, v| csv << [ k.to_s, v.to_s ] }
          else
            csv << [ values.to_s ]
          end

          csv << [] # Empty row between sections
        end
      end
    end
  end
end
