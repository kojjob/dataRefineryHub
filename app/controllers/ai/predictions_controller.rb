module Ai
  class PredictionsController < DataflowProController
    before_action :authenticate_user!
    before_action :set_organization
    # The set_dataflow_navigation is inherited from DataflowProController

    def index
      @page_title = "Predictive Analytics Engine"
      @page_subtitle = "Advanced forecasting and trend analysis powered by machine learning"

      # Set active section for navigation
      @active_section = "predictive"

      # Sample data for demonstration - in production this would come from your models
      @predictions = {
        demand_forecast: {
          value: "+23%",
          text: "Product demand expected to increase in Q3",
          accuracy: 89,
          confidence: "High",
          model: "ARIMA Model",
          trend: "up"
        },
        customer_behavior: {
          value: "+15%",
          text: "Customer lifetime value trending upward",
          accuracy: 92,
          confidence: "High",
          model: "Neural Network",
          trend: "stable"
        },
        market_trends: {
          value: "-8%",
          text: "Competitive pressure may impact margins",
          accuracy: 76,
          confidence: "Medium",
          model: "Random Forest",
          trend: "down"
        },
        revenue_forecast: {
          value: "$2.4M",
          text: "Projected revenue for next quarter",
          accuracy: 94,
          range: "±5%",
          goal: "$2.2M",
          model: "Ensemble Model",
          trend: "up"
        }
      }

      @forecast_models = [
        {
          name: "Sales Forecasting",
          icon: "📈",
          status: "active",
          last_run: "2 hours ago",
          mape: "4.2%",
          r_squared: "0.96"
        },
        {
          name: "Churn Prediction",
          icon: "🎯",
          status: "active",
          precision: "91%",
          recall: "88%",
          f1_score: "0.89"
        },
        {
          name: "Price Optimization",
          icon: "💰",
          status: "training",
          progress: 67,
          eta: "15 min",
          epochs: "134/200"
        }
      ]

      @scenarios = {
        best_case: {
          revenue: "+32%",
          customers: "+18%",
          profit: "+28%",
          probability: "25%"
        },
        expected: {
          revenue: "+15%",
          customers: "+10%",
          profit: "+12%",
          probability: "60%"
        },
        worst_case: {
          revenue: "-5%",
          customers: "-2%",
          profit: "-8%",
          probability: "15%"
        }
      }
    end

    private

    def set_organization
      @organization = current_user.organization
    end
  end
end
