# frozen_string_literal: true

class DataQualityNotificationMailer < ApplicationMailer
  default from: 'notifications@datarefinery.com'
  
  def quality_alert(user:, data_source:, report:)
    @user = user
    @data_source = data_source
    @report = report
    @organization = data_source.organization
    
    mail(
      to: @user.email,
      subject: "Data Quality Alert: #{@data_source.name} - Score: #{@report.overall_score}%"
    )
  end
  
  def validation_complete(user:, data_source:, report:)
    @user = user
    @data_source = data_source
    @report = report
    @organization = data_source.organization
    
    mail(
      to: @user.email,
      subject: "Data Quality Validation Complete: #{@data_source.name}"
    )
  end
  
  def weekly_quality_summary(user:, organization:, summary_data:)
    @user = user
    @organization = organization
    @summary = summary_data
    
    mail(
      to: @user.email,
      subject: "Weekly Data Quality Summary - #{@organization.name}"
    )
  end
  
  def critical_quality_issue(user:, data_source:, report:, issues:)
    @user = user
    @data_source = data_source
    @report = report
    @critical_issues = issues
    @organization = data_source.organization
    
    mail(
      to: @user.email,
      subject: "CRITICAL: Data Quality Issues Detected - #{@data_source.name}",
      priority: 'high'
    )
  end
end