# frozen_string_literal: true

# This file contains sample data for testing the monitoring dashboard
# Run with: rails runner db/seeds/monitoring_data.rb

def create_monitoring_sample_data(organization)
  puts "Creating monitoring sample data for organization: #{organization.name}"

  # Create system metrics for the last 24 hours
  24.times do |i|
    SystemMetric.create!(
      organization: organization,
      recorded_at: i.hours.ago,
      cpu_usage: 30 + rand(40),
      memory_usage: 50 + rand(30),
      storage_usage: 70 + rand(15),
      active_connections: rand(10..50),
      queue_size: rand(0..100)
    )
  end

  # Create some active pipeline executions
  3.times do |i|
    data_source = organization.data_sources.sample || organization.data_sources.create!(
      name: "Sample Data Source #{i + 1}",
      source_type: ['shopify', 'quickbooks', 'stripe', 'google_analytics'].sample,
      status: 'connected',
      connection_config: { api_key: 'sample_key' }
    )

    execution = PipelineExecution.create!(
      organization: organization,
      data_source: data_source,
      status: ['running', 'pending', 'failed'].sample,
      started_at: rand(1..4).hours.ago,
      total_records: rand(10000..100000),
      records_processed: rand(5000..50000),
      error_message: nil,
      execution_config: {}
    )

    # Add pipeline metrics for running executions
    if execution.status == 'running'
      5.times do |j|
        PipelineMetric.create!(
          pipeline_execution: execution,
          recorded_at: j.minutes.ago,
          cpu_usage: 20 + rand(40),
          memory_usage_gb: 1.0 + rand(3.0),
          records_per_second: rand(100..2000),
          error_rate: rand(0.0..0.05)
        )
      end
    end
  end

  # Create alerts
  alert_configs = [
    { severity: 'critical', title: 'Storage Space Critical', message: 'Only 19% storage remaining. Consider archiving old data.' },
    { severity: 'high', title: 'High Memory Usage', message: "Pipeline 'Sales ETL' using 85% of allocated memory." },
    { severity: 'medium', title: 'Slow Query Performance', message: 'Database queries taking 3x longer than usual.' },
    { severity: 'low', title: 'API Rate Limit Warning', message: 'Approaching Shopify API rate limit (80% used).' },
    { severity: 'info', title: 'Scheduled Maintenance', message: 'System maintenance scheduled for Sunday 2:00 AM.' }
  ]

  alert_configs.each do |config|
    Alert.create!(
      organization: organization,
      severity: config[:severity],
      title: config[:title],
      message: config[:message],
      status: 'active',
      created_at: rand(1..48).hours.ago
    )
  end

  # Create timeline events
  event_types = [
    { type: 'pipeline_completed', title: 'Pipeline Completed', desc: 'Sales Data ETL finished successfully' },
    { type: 'pipeline_failed', title: 'Pipeline Failed', desc: 'Inventory Sync encountered an error' },
    { type: 'resource_alert', title: 'Resource Alert', desc: 'High memory usage detected' },
    { type: 'system_update', title: 'System Update', desc: 'Platform version 2.4.1 deployed successfully' },
    { type: 'data_quality_check', title: 'Data Quality Check', desc: 'Automated validation completed, 98% accuracy' }
  ]

  20.times do
    event = event_types.sample
    EventTimeline.create!(
      organization: organization,
      event_type: event[:type],
      title: event[:title],
      description: event[:desc],
      occurred_at: rand(1..72).hours.ago,
      metadata: {
        details: "#{rand(10000..99999)} records processed in #{rand(1..60)} minutes"
      }
    )
  end

  # Create system health checks
  check_types = ['database', 'cache', 'job_queue', 'storage', 'api_connections']
  
  check_types.each do |check_type|
    SystemHealthCheck.create!(
      organization: organization,
      check_type: check_type,
      status: rand > 0.2 ? 'healthy' : 'degraded',
      response_time_ms: rand(10.0..100.0),
      checked_at: 5.minutes.ago,
      details: {}
    )
  end

  puts "✓ Created monitoring sample data"
end

# Run for the first organization if it exists
if Organization.any?
  create_monitoring_sample_data(Organization.first)
else
  puts "No organizations found. Please create an organization first."
end
