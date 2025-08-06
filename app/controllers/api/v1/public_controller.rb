# API::V1::PublicController
# Public API endpoints that don't require authentication (for landing page demos)
class Api::V1::PublicController < ActionController::API
  before_action :set_default_format
  before_action :set_cors_headers

  # GET /api/v1/public/hero_stats
  def hero_stats
    render json: {
      success: true,
      timestamp: Time.current.iso8601,
      data: generate_hero_stats
    }
  end

  # GET /api/v1/public/demo_metrics
  def demo_metrics
    render json: {
      success: true,
      timestamp: Time.current.iso8601,
      data: generate_demo_metrics
    }
  end

  # GET /api/v1/public/metrics_stream
  def metrics_stream
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["Connection"] = "keep-alive"
    response.headers["X-Accel-Buffering"] = "no"

    begin
      loop do
        # Generate demo metrics for the stream
        metrics = generate_demo_stream_metrics

        # Send as Server-Sent Event
        response.stream.write("data: #{metrics.to_json}\n\n")

        # Update every 5 seconds
        sleep 5

        # Check if client is still connected
        break unless response.stream.closed?
      end
    rescue IOError, Errno::ECONNRESET => e
      Rails.logger.info "Client disconnected from public metrics stream: #{e.message}"
    ensure
      response.stream.close
    end
  end

  private

  def set_default_format
    request.format = :json
  end

  def set_cors_headers
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type"
  end

  def generate_hero_stats
    # Generate realistic demo data for the landing page hero section
    base_revenue = 125000
    base_users = 2847
    base_data_points = 1250000

    # Add some realistic variation
    revenue_variation = rand(-5000..8000)
    users_variation = rand(-50..120)
    data_variation = rand(-25000..45000)

    {
      metrics: {
        revenue_rate: base_revenue + revenue_variation,
        active_users: base_users + users_variation,
        data_points_processed: base_data_points + data_variation,
        processing_speed: "#{rand(850..1200)} records/sec",
        uptime: "99.#{rand(85..99)}%",
        success_rate: "#{rand(95..99)}.#{rand(10..99)}%"
      },
      trends: {
        revenue_growth: "#{rand(12..28)}%",
        user_growth: "#{rand(15..35)}%",
        efficiency_improvement: "#{rand(18..42)}%"
      },
      live_activity: {
        current_jobs: rand(8..24),
        queued_jobs: rand(2..12),
        completed_today: rand(450..850)
      }
    }
  end

  def generate_demo_metrics
    # Generate demo metrics for the feature cards on landing page
    {
      metrics: {
        data_sources_connected: rand(12..28),
        records_processed_today: rand(125000..285000),
        automation_savings: "#{rand(15..35)} hours/week",
        accuracy_improvement: "#{rand(85..95)}%",
        cost_reduction: "#{rand(25..45)}%",
        time_to_insights: "#{rand(2..8)} minutes"
      },
      real_time_stats: {
        current_throughput: "#{rand(800..1500)} records/min",
        active_pipelines: rand(6..18),
        data_quality_score: rand(92..98),
        system_health: "excellent"
      },
      recent_activity: [
        {
          type: "data_sync",
          source: "Shopify Store",
          status: "completed",
          records: rand(1000..5000),
          timestamp: rand(1..30).minutes.ago.iso8601
        },
        {
          type: "transformation",
          pipeline: "Customer Analytics",
          status: "running",
          progress: rand(45..85),
          timestamp: rand(1..15).minutes.ago.iso8601
        },
        {
          type: "alert",
          message: "Data quality threshold exceeded",
          severity: "info",
          timestamp: rand(5..60).minutes.ago.iso8601
        }
      ]
    }
  end

  def generate_demo_stream_metrics
    # Generate demo metrics for Server-Sent Events stream (used by landing page)
    {
      timestamp: Time.current.iso8601,
      organization_id: "demo",
      metrics: {
        active_jobs: rand(3..12),
        total_data_sources: rand(8..15),
        connected_sources: rand(6..12),
        records_processed_last_hour: rand(5000..15000),
        current_processing_rate: rand(80..150),
        system_health: "excellent",
        success_rate: rand(95..99),
        revenue_rate: 125000 + rand(-3000..5000),
        customer_activity: 2800 + rand(-100..200)
      },
      recent_activity: [
        {
          type: "sync_completed",
          message: "Shopify sync completed successfully",
          timestamp: rand(1..5).minutes.ago.iso8601,
          records: rand(500..2000)
        },
        {
          type: "transformation_started",
          message: "Customer segmentation analysis started",
          timestamp: rand(1..3).minutes.ago.iso8601
        }
      ],
      alerts: []
    }
  end
end
