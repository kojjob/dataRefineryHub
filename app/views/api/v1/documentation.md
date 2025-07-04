# Data Refinery Platform API v1 Documentation

## Overview

The Data Refinery Platform API provides programmatic access to pipeline execution, task management, and scheduling functionality. All API endpoints require authentication via API key.

## Authentication

Include your API key in the request header:
```
X-API-Key: your_api_key_here
```

Or as a query parameter:
```
?api_key=your_api_key_here
```

## Base URL

```
https://your-domain.com/api/v1
```

## Rate Limiting

API requests are rate-limited based on your subscription plan:
- Free Trial: 1,000 requests/month
- Starter: 10,000 requests/month
- Growth: 50,000 requests/month
- Scale: 200,000 requests/month
- Enterprise: Unlimited

Rate limit information is included in response headers:
- `X-RateLimit-Limit`: Maximum requests allowed
- `X-RateLimit-Remaining`: Requests remaining
- `X-RateLimit-Reset`: Unix timestamp when limit resets

## Common Response Formats

### Success Response
```json
{
  "data": {
    // Response data
  }
}
```

### Error Response
```json
{
  "error": {
    "message": "Error description",
    "status": 400,
    "details": ["Additional error details"]
  }
}
```

## Pagination

List endpoints support pagination via query parameters:
- `page`: Page number (default: 1)
- `per_page`: Items per page (default: 25, max: 100)

Pagination metadata is included in response headers:
- `X-Total-Count`: Total number of items
- `X-Page`: Current page
- `X-Per-Page`: Items per page
- `X-Total-Pages`: Total number of pages

---

## Pipeline Executions

### List Pipeline Executions

```http
GET /api/v1/pipelines
```

**Query Parameters:**
- `status`: Filter by status (comma-separated: `running,completed,failed`)
- `start_date`: Filter by start date (ISO 8601 format)
- `end_date`: Filter by end date (ISO 8601 format)
- `data_source_id`: Filter by data source ID
- `execution_mode`: Filter by execution mode (`automated,manual,scheduled`)
- `sort`: Sort field with direction (`started_at:desc`, `completed_at:asc`)
- `page`: Page number
- `per_page`: Items per page

**Response:**
```json
{
  "data": [
    {
      "id": 123,
      "pipeline_name": "Daily Order Sync",
      "status": "running",
      "execution_mode": "automated",
      "priority": 5,
      "started_at": "2024-01-15T10:30:00Z",
      "completed_at": null,
      "duration_seconds": null,
      "progress_percentage": 45,
      "total_tasks": 10,
      "completed_tasks": 4,
      "failed_tasks": 0,
      "data_source": {
        "id": 45,
        "name": "Shopify Store",
        "source_type": "shopify"
      },
      "user": {
        "id": 12,
        "email": "admin@example.com",
        "full_name": "Admin User"
      }
    }
  ]
}
```

### Get Pipeline Execution Details

```http
GET /api/v1/pipelines/:id
```

**Response:** Includes full pipeline details with tasks array.

### Create Pipeline Execution

```http
POST /api/v1/pipelines
```

**Request Body:**
```json
{
  "pipeline": {
    "pipeline_name": "Manual Product Import",
    "data_source_id": 45,
    "execution_mode": "manual",
    "priority": 7,
    "configuration": {
      "batch_size": 100,
      "skip_validation": false
    }
  }
}
```

### Pause Pipeline

```http
POST /api/v1/pipelines/:id/pause
```

### Resume Pipeline

```http
POST /api/v1/pipelines/:id/resume
```

### Cancel Pipeline

```http
POST /api/v1/pipelines/:id/cancel
```

### Retry Failed Pipeline

```http
POST /api/v1/pipelines/:id/retry
```

### Get Pipeline Tasks

```http
GET /api/v1/pipelines/:id/tasks
```

**Query Parameters:**
- `status`: Filter by task status
- `task_type`: Filter by task type
- `execution_mode`: Filter by execution mode

### Get Pipeline Logs

```http
GET /api/v1/pipelines/:id/logs
```

**Query Parameters:**
- `level`: Filter by log level (`info,warning,error`)
- `start_date`: Filter logs from date
- `end_date`: Filter logs to date

### Get Pipeline Statistics

```http
GET /api/v1/pipelines/statistics
```

**Response:**
```json
{
  "total_executions": 1543,
  "executions_by_status": {
    "completed": 1200,
    "failed": 143,
    "running": 5,
    "cancelled": 195
  },
  "executions_last_24h": 45,
  "average_duration": 324.5,
  "success_rate": 89.3,
  "executions_by_day": {
    "2024-01-15": {"completed": 20, "failed": 2},
    "2024-01-14": {"completed": 18, "failed": 1}
  },
  "top_failing_pipelines": [
    {
      "pipeline_name": "Complex ETL Process",
      "failure_count": 15
    }
  ]
}
```

---

## Tasks

### List Tasks

```http
GET /api/v1/tasks
```

**Query Parameters:**
- `status`: Filter by status
- `task_type`: Filter by type (`extraction,transformation,validation,notification,approval`)
- `execution_mode`: Filter by mode (`automated,manual,approval_required,hybrid`)
- `assignee_id`: Filter by assignee (use `unassigned` for unassigned tasks)
- `pipeline_id`: Filter by pipeline execution ID
- `pipeline_name`: Filter by pipeline name
- `start_date`: Filter by creation date
- `end_date`: Filter by creation date
- `sort`: Sort field (`created_at,priority,status,name`)

### Get Task Details

```http
GET /api/v1/tasks/:id
```

### Get Manual Task Queue

```http
GET /api/v1/tasks/manual_queue
```

**Query Parameters:**
- `assigned_to_me`: Boolean to filter tasks assigned to current user
- `pipeline_name`: Filter by pipeline name

**Response includes queue statistics and workload distribution.**

### Execute Manual Task

```http
POST /api/v1/tasks/:id/execute
```

### Approve Task

```http
POST /api/v1/tasks/:id/approve
```

**Request Body (optional):**
```json
{
  "execute_after_approval": true
}
```

### Reject Task

```http
POST /api/v1/tasks/:id/reject
```

**Request Body:**
```json
{
  "reason": "Data quality issues detected"
}
```

### Assign Task

```http
POST /api/v1/tasks/:id/assign
```

**Request Body (optional):**
```json
{
  "user_id": 45  // Omit to assign to self
}
```

### Unassign Task

```http
POST /api/v1/tasks/:id/unassign
```

### Cancel Task

```http
POST /api/v1/tasks/:id/cancel
```

### Retry Failed Task

```http
POST /api/v1/tasks/:id/retry
```

### Get Task Statistics

```http
GET /api/v1/tasks/statistics
```

---

## Task Templates

### List Task Templates

```http
GET /api/v1/task_templates
```

**Query Parameters:**
- `active`: Filter active templates only (`true`)
- `category`: Filter by category
- `execution_mode`: Filter by execution mode
- `tags`: Filter by tags (comma-separated)
- `q`: Search by name or description

### Get Template Library

```http
GET /api/v1/task_templates/library
```

**Query Parameters:**
- `category`: Filter library by category

### Get Task Template Details

```http
GET /api/v1/task_templates/:id
```

### Create Task Template

```http
POST /api/v1/task_templates
```

**Request Body:**
```json
{
  "task_template": {
    "name": "Custom Data Validation",
    "description": "Validates incoming data against business rules",
    "task_type": "validation",
    "execution_mode": "automated",
    "category": "validation",
    "tags": "data-quality, automated",
    "template_config": {
      "rules": ["required_fields", "data_types", "value_ranges"],
      "fail_on_error": true
    },
    "default_timeout": 600,
    "default_priority": 5
  }
}
```

### Import Templates from Library

```http
POST /api/v1/task_templates/import_from_library
```

**Request Body:**
```json
{
  "category": "extraction",  // Import all from category
  // OR
  "template_names": ["API Data Extraction", "Database Query Extraction"]
}
```

### Update Task Template

```http
PATCH /api/v1/task_templates/:id
```

### Delete Task Template

```http
DELETE /api/v1/task_templates/:id
```

### Duplicate Task Template

```http
POST /api/v1/task_templates/:id/duplicate
```

**Request Body (optional):**
```json
{
  "name": "My Custom Template Copy"
}
```

### Create Task from Template

```http
POST /api/v1/task_templates/:id/create_task
```

**Request Body:**
```json
{
  "pipeline_execution_id": 123,
  "name": "Extract Customer Data",  // Optional override
  "timeout_seconds": 300,  // Optional override
  "configuration": {  // Optional override/merge
    "batch_size": 500
  }
}
```

---

## Scheduled Tasks

### List Scheduled Tasks

```http
GET /api/v1/scheduled_tasks
```

**Query Parameters:**
- `active`: Filter active tasks only (`true`)
- `schedule_type`: Filter by type (`once,daily,weekly,monthly,custom`)
- `status`: Filter by status
- `next_run_from`: Filter tasks running after date
- `next_run_to`: Filter tasks running before date

### Get Upcoming Scheduled Tasks

```http
GET /api/v1/scheduled_tasks/upcoming
```

**Query Parameters:**
- `days`: Number of days ahead to look (default: 7)

### Get Scheduled Task Details

```http
GET /api/v1/scheduled_tasks/:id
```

### Create Scheduled Task

```http
POST /api/v1/scheduled_tasks
```

**Request Body:**
```json
{
  "scheduled_task": {
    "name": "Daily Customer Sync",
    "description": "Sync customer data every day at 2 AM",
    "task_template_id": 45,
    "schedule_type": "daily",
    "time_of_day": "02:00",
    "start_date": "2024-01-20",
    "end_date": "2024-12-31",
    "max_runs": 365,
    "configuration": {
      "data_source_id": 12
    }
  }
}
```

**Schedule Type Options:**

1. **Once**: Single execution
   ```json
   {
     "schedule_type": "once",
     "scheduled_at": "2024-01-20T14:30:00Z"
   }
   ```

2. **Daily**: Every day at specified time
   ```json
   {
     "schedule_type": "daily",
     "time_of_day": "14:30"
   }
   ```

3. **Weekly**: Specific days of week
   ```json
   {
     "schedule_type": "weekly",
     "time_of_day": "14:30",
     "days_of_week": ["monday", "wednesday", "friday"]
   }
   ```

4. **Monthly**: Specific day of month
   ```json
   {
     "schedule_type": "monthly",
     "time_of_day": "14:30",
     "day_of_month": 15
   }
   ```

5. **Custom**: Cron expression
   ```json
   {
     "schedule_type": "custom",
     "cron_expression": "0 2 * * 1-5"  // Weekdays at 2 AM
   }
   ```

### Update Scheduled Task

```http
PATCH /api/v1/scheduled_tasks/:id
```

### Delete Scheduled Task

```http
DELETE /api/v1/scheduled_tasks/:id
```

### Pause Scheduled Task

```http
POST /api/v1/scheduled_tasks/:id/pause
```

### Resume Scheduled Task

```http
POST /api/v1/scheduled_tasks/:id/resume
```

### Execute Scheduled Task Now

```http
POST /api/v1/scheduled_tasks/:id/execute_now
```

### Get Scheduled Task Runs

```http
GET /api/v1/scheduled_tasks/:id/runs
```

**Query Parameters:**
- `status`: Filter by run status
- `start_date`: Filter runs after date
- `end_date`: Filter runs before date

### Get Scheduled Tasks Statistics

```http
GET /api/v1/scheduled_tasks/statistics
```

---

## WebSocket Connections

For real-time updates, connect to our WebSocket endpoints:

### Pipeline Updates
```javascript
const cable = ActionCable.createConsumer('wss://your-domain.com/cable')

const subscription = cable.subscriptions.create(
  { 
    channel: "PipelineChannel", 
    pipeline_id: 123 
  },
  {
    received(data) {
      console.log('Pipeline update:', data)
    }
  }
)
```

### Manual Task Queue Updates
```javascript
const subscription = cable.subscriptions.create(
  { channel: "ManualTaskQueueChannel" },
  {
    received(data) {
      console.log('Queue update:', data)
    }
  }
)
```

### Task Execution Updates
```javascript
const subscription = cable.subscriptions.create(
  { 
    channel: "TaskExecutionChannel", 
    task_id: 456 
  },
  {
    received(data) {
      console.log('Task update:', data)
    }
  }
)
```

---

## Error Codes

| Status Code | Description |
|-------------|-------------|
| 200 | Success |
| 201 | Created |
| 204 | No Content |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 422 | Unprocessable Entity |
| 429 | Too Many Requests |
| 500 | Internal Server Error |

---

## SDK Examples

### Ruby
```ruby
require 'httparty'

class DataRefineryClient
  include HTTParty
  base_uri 'https://your-domain.com/api/v1'
  
  def initialize(api_key)
    @options = { headers: { 'X-API-Key' => api_key } }
  end
  
  def list_pipelines
    self.class.get('/pipelines', @options)
  end
  
  def execute_task(task_id)
    self.class.post("/tasks/#{task_id}/execute", @options)
  end
end

client = DataRefineryClient.new('your_api_key')
pipelines = client.list_pipelines
```

### Python
```python
import requests

class DataRefineryClient:
    def __init__(self, api_key):
        self.base_url = 'https://your-domain.com/api/v1'
        self.headers = {'X-API-Key': api_key}
    
    def list_pipelines(self):
        response = requests.get(
            f'{self.base_url}/pipelines',
            headers=self.headers
        )
        return response.json()
    
    def execute_task(self, task_id):
        response = requests.post(
            f'{self.base_url}/tasks/{task_id}/execute',
            headers=self.headers
        )
        return response.json()

client = DataRefineryClient('your_api_key')
pipelines = client.list_pipelines()
```

### JavaScript/Node.js
```javascript
const axios = require('axios');

class DataRefineryClient {
  constructor(apiKey) {
    this.client = axios.create({
      baseURL: 'https://your-domain.com/api/v1',
      headers: { 'X-API-Key': apiKey }
    });
  }
  
  async listPipelines() {
    const response = await this.client.get('/pipelines');
    return response.data;
  }
  
  async executeTask(taskId) {
    const response = await this.client.post(`/tasks/${taskId}/execute`);
    return response.data;
  }
}

const client = new DataRefineryClient('your_api_key');
const pipelines = await client.listPipelines();
```

---

## Webhooks

Configure webhooks in your organization settings to receive real-time notifications:

### Webhook Events
- `pipeline.started`
- `pipeline.completed`
- `pipeline.failed`
- `task.completed`
- `task.failed`
- `task.requires_approval`
- `scheduled_task.executed`

### Webhook Payload
```json
{
  "event": "pipeline.completed",
  "timestamp": "2024-01-15T10:45:00Z",
  "data": {
    "pipeline_id": 123,
    "pipeline_name": "Daily Order Sync",
    "status": "completed",
    "duration_seconds": 245,
    "tasks_completed": 10,
    "tasks_failed": 0
  }
}
```

### Webhook Security
All webhooks include an HMAC signature in the `X-Webhook-Signature` header for verification:

```ruby
def verify_webhook(payload, signature)
  expected = OpenSSL::HMAC.hexdigest(
    'SHA256',
    webhook_secret,
    payload
  )
  
  ActiveSupport::SecurityUtils.secure_compare(expected, signature)
end
```