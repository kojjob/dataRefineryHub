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
    # SECURITY FIX: Sanitize HTML content to prevent XSS attacks
    @html_body = sanitize_html_content(params[:html_body])
    @text_body = params[:text_body]

    mail(
      to: @user.email,
      subject: sanitize_subject(params[:subject])
    ) do |format|
      format.text { render plain: @text_body }
      # SECURITY FIX: Don't use html_safe on user-controlled content
      format.html { render html: @html_body }
    end
  end

  # Report with PDF attachment
  def report_with_attachment
    @user = params[:user]
    @organization = params[:organization]
    @body = sanitize_text_content(params[:body])

    # SECURITY FIX: Validate PDF filename and content
    pdf_filename = sanitize_filename(params[:pdf_filename])
    pdf_content = params[:pdf_content]
    
    # Validate PDF content
    validate_pdf_content!(pdf_content) if pdf_content
    
    attachments[pdf_filename] = {
      mime_type: "application/pdf",
      content: pdf_content
    }

    mail(
      to: @user.email,
      subject: sanitize_subject(params[:subject])
    )
  end

  # Presentation delivery email
  def presentation_delivery
    @user = params[:user]
    @organization = params[:organization]
    @body = sanitize_text_content(params[:body])

    # SECURITY FIX: Secure file attachment handling - prevent path traversal
    attachment_path = validate_attachment_path!(params[:attachment_path])
    attachment_name = sanitize_filename(params[:attachment_name])
    
    attachments[attachment_name] = File.read(attachment_path)

    mail(
      to: @user.email,
      subject: sanitize_subject(params[:subject])
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
      subject: sanitize_subject(params[:subject] || default_subject)
    )
  end

  private

  def default_subject
    "#{@organization.name} - #{@report_type.humanize} Report - #{Date.current}"
  end

  # SECURITY METHODS: Sanitization and validation
  
  def sanitize_html_content(html)
    return "" if html.blank?
    
    # Allow only safe HTML tags and attributes
    ActionController::Base.helpers.sanitize(
      html,
      tags: %w[p br strong em b i u ul ol li h1 h2 h3 h4 h5 h6 div span table tr td th thead tbody],
      attributes: %w[class style],
      remove_contents: %w[script style],
      whitespace: :normalize
    )
  end
  
  def sanitize_text_content(text)
    return "" if text.blank?
    
    # Strip HTML tags and normalize whitespace
    ActionController::Base.helpers.strip_tags(text).squish.truncate(10000)
  end
  
  def sanitize_subject(subject)
    return "Data Refinery Report" if subject.blank?
    
    # Strip HTML tags and limit length
    sanitized = ActionController::Base.helpers.strip_tags(subject).squish
    sanitized.truncate(255)
  end
  
  def sanitize_filename(filename)
    return "report.pdf" if filename.blank?
    
    # Remove dangerous characters and normalize
    safe_name = filename.gsub(/[^a-zA-Z0-9\-_\.]/, '_')
    safe_name = safe_name.gsub(/_{2,}/, '_') # Remove multiple underscores
    safe_name.truncate(100)
  end
  
  def validate_attachment_path!(file_path)
    return nil if file_path.blank?
    
    # Define allowed directories for file attachments
    allowed_dirs = [
      Rails.root.join('tmp', 'reports').to_s,
      Rails.root.join('tmp', 'presentations').to_s,
      Rails.root.join('storage').to_s
    ]
    
    # Resolve absolute path to prevent path traversal
    resolved_path = File.expand_path(file_path)
    
    # Check if path is within allowed directories
    unless allowed_dirs.any? { |dir| resolved_path.start_with?(File.expand_path(dir)) }
      raise SecurityError, "File access denied: path outside allowed directories"
    end
    
    # Check if file exists and is a regular file
    unless File.exist?(resolved_path) && File.file?(resolved_path)
      raise ArgumentError, "Invalid file: #{file_path}"
    end
    
    # Check file size (10MB limit)
    if File.size(resolved_path) > 10.megabytes
      raise ArgumentError, "File too large: #{file_path}"
    end
    
    resolved_path
  end
  
  def validate_pdf_content!(content)
    return if content.blank?
    
    # Check if content starts with PDF magic number
    unless content.start_with?('%PDF-')
      raise ArgumentError, "Invalid PDF content"
    end
    
    # Check content size
    if content.bytesize > 10.megabytes
      raise ArgumentError, "PDF content too large"
    end
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
