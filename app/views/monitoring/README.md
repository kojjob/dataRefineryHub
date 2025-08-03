# Monitoring Dashboard

The monitoring dashboard provides real-time insights into your data pipeline performance, system health, and resource utilization.

## Features

### System Health Overview
- **Real-time health score**: Visual representation of overall system health
- **Uptime percentage**: 30-day uptime tracking
- **Component status**: Individual health checks for database, cache, job queue, storage, and APIs

### Pipeline Monitoring
- **Live pipeline activity**: Real-time status of running, queued, and failed pipelines
- **Progress tracking**: Detailed progress bars with ETA calculations
- **Performance metrics**: CPU, memory usage, and processing speed per pipeline

### Resource Utilization
- **CPU usage**: Real-time and historical CPU utilization
- **Memory usage**: System memory consumption tracking
- **Storage usage**: Available storage space monitoring

### Alerts & Notifications
- **Active alerts**: Categorized by severity (Critical, Warning, Info)
- **Alert history**: Timeline of recent system alerts
- **Smart notifications**: Contextual alerts based on system behavior

### Performance Analytics
- **Pipeline performance**: Success/failure rates by pipeline
- **Resource trends**: Historical resource usage patterns
- **Processing volume**: Records processed over time

### Event Timeline
- **System events**: Chronological view of pipeline completions, failures, and system updates
- **Event details**: Comprehensive information for each event
- **Visual indicators**: Color-coded event types for quick scanning

### System Logs
- **Real-time logs**: Live system log viewer with filtering
- **Log levels**: Filter by INFO, WARN, ERROR levels
- **Export capability**: Download logs for further analysis

## Usage

### Accessing the Dashboard
Navigate to `/monitoring/dashboard` when logged in to your organization.

### Time Range Selection
Use the dropdown in the header to select different time ranges:
- Last Hour
- Last 24 Hours
- Last 7 Days
- Last 30 Days

### Auto-Refresh
Toggle the auto-refresh switch to enable automatic updates every 30 seconds.

### Exporting Reports
Click the "Export Report" button to download a comprehensive monitoring report.

## Development

### Adding Sample Data
To populate the dashboard with sample data for testing:

```bash
rails runner db/seeds/monitoring_data.rb
```

### Required Models
The monitoring dashboard expects these models to have specific attributes:

1. **PipelineExecution**
   - `status`: running, pending, completed, failed
   - `progress_percentage`: method returning 0-100
   - `records_processed`, `total_records`: for progress calculation
   - `error_message`, `error_details`: for failed pipelines

2. **SystemMetric**
   - `cpu_usage`, `memory_usage`, `storage_usage`: percentage values
   - `recorded_at`: timestamp
   - `to_percentage_hash`: method returning hash of metrics

3. **Alert**
   - `severity`: critical, high, medium, low
   - `title`, `message`: alert content
   - `status`: active, resolved

4. **EventTimeline**
   - `event_type`: pipeline_completed, pipeline_failed, etc.
   - `title`, `description`: event details
   - `occurred_at`: timestamp
   - `metadata`: additional event data

5. **SystemHealthCheck**
   - `check_type`: database, cache, job_queue, storage, api_connections
   - `status`: healthy, degraded, unhealthy
   - `response_time_ms`: performance metric

### Styling
The dashboard uses a modern, clean design with:
- Light beige background (#f5f5f0)
- White cards with subtle shadows
- Consistent color scheme:
  - Success: #10b981 (green)
  - Warning: #f59e0b (orange)
  - Error: #ef4444 (red)
  - Info: #3b82f6 (blue)
  - Primary: #14b8a6 (teal)

### JavaScript Controllers
The dashboard uses Stimulus controllers for interactivity:
- `monitoring_refresh_controller`: Handles manual refresh
- `toggle_switch_controller`: Auto-refresh toggle
- `realtime_chart_controller`: Real-time metrics chart
- `performance_chart_controller`: Pipeline performance bar chart
- `resource_chart_controller`: Resource utilization line chart

### Performance Considerations
- Charts update without animations for smooth real-time updates
- Data is limited to reasonable timeframes to prevent overloading
- Auto-refresh can be disabled to reduce server load
- Efficient database queries with proper indexing

## Customization

### Adding New Metrics
1. Add the metric to the appropriate model
2. Update the controller to fetch the new data
3. Add the display logic to the view
4. Update the helper methods if needed

### Modifying Charts
Charts use Chart.js and can be customized in the respective Stimulus controllers.

### Changing the Design
Update the CSS in `app/assets/stylesheets/monitoring.css` to modify the appearance.
