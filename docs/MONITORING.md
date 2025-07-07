# Monitoring and Observability Guide

## Overview

The Data Refinery Platform includes comprehensive monitoring and observability features to ensure reliable operations at scale.

## Components

### 1. Structured Logging

All logs are output in structured JSON format for easy parsing and analysis.

#### Usage in Controllers
```ruby
structured_logger.info "Processing request",
  user_id: current_user.id,
  action: "data_sync"
```

#### Usage in Jobs
```ruby
structured_logger.measure("Data extraction") do
  # Your code here
end
```

### 2. Metrics Collection

We use OpenTelemetry for metrics collection with support for multiple backends.

#### Available Metrics
- **API Metrics**: Request counts, duration, errors
- **Pipeline Metrics**: Execution counts, duration, failures
- **Business Metrics**: Active users, subscriptions, revenue
- **System Metrics**: Memory, CPU, database connections

#### Custom Metrics
```ruby
MetricsService.increment('custom.metric', tags: { type: 'example' })
MetricsService.histogram('operation.duration', 123.45, tags: { operation: 'sync' })
```

### 3. Health Checks

Multiple health check endpoints for monitoring:

- `/health` - Comprehensive health check
- `/ready` - Kubernetes readiness probe
- `/alive` - Kubernetes liveness probe
- `/metrics` - Prometheus metrics endpoint (requires auth)

### 4. Request Logging

All HTTP requests are automatically logged with:
- Request ID tracking
- User and organization context
- Performance metrics
- Error tracking

### 5. Job Monitoring

Background jobs include:
- Execution time tracking
- Retry attempt logging
- Failure analysis
- Queue metrics

## Configuration

### Environment Variables

```bash
# OpenTelemetry Configuration
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer your-token"

# Metrics Authentication
METRICS_USERNAME=metrics_user
METRICS_PASSWORD=secure_password

# Log Level
LOG_LEVEL=info # debug, info, warn, error
```

### Rails Configuration

Logging is configured in `config/initializers/logging.rb`

## Dashboards

### Grafana Dashboard

Import the dashboard from `monitoring/grafana-dashboard.json` for:
- API performance metrics
- Pipeline execution tracking
- Error rate monitoring
- Business KPIs

### Example Queries

**API Response Time (p95)**
```promql
histogram_quantile(0.95, 
  sum(rate(api_requests_duration_bucket[5m])) by (le, path)
)
```

**Pipeline Success Rate**
```promql
rate(pipeline_executions_total{status="success"}[5m]) / 
rate(pipeline_executions_total[5m])
```

**Active Organizations**
```promql
organizations_active
```

## Alerts

Configure alerts for:
- High error rates (>5% of requests)
- Slow API responses (p95 > 1s)
- Failed job queue buildup (>100)
- Circuit breaker activations
- Low disk space (<10%)

## Best Practices

1. **Use Structured Logging**
   - Always include relevant context
   - Use consistent field names
   - Avoid logging sensitive data

2. **Track Key Metrics**
   - Business KPIs
   - Technical performance
   - Error rates and types

3. **Set Up Alerts**
   - Define SLOs and SLIs
   - Alert on symptoms, not causes
   - Include runbooks in alerts

4. **Regular Reviews**
   - Weekly metrics review
   - Monthly trend analysis
   - Quarterly capacity planning

## Troubleshooting

### High Memory Usage
Check for:
- Large batch operations
- Memory leaks in jobs
- Unclosed connections

### Slow Queries
Monitor:
- Database query logs
- Missing indexes
- N+1 queries

### Job Queue Backup
Investigate:
- Circuit breaker status
- External API availability
- Resource constraints