# frozen_string_literal: true

module Ai
  module IndustryPackages
    class EcommercePackage
      include ActionView::Helpers::NumberHelper

      # Industry benchmarks based on 2024 data
      METRICS = {
        conversion_rate: {
          benchmark: 3.1,
          unit: "%",
          good: 4.0,
          excellent: 5.0,
          description: "Percentage of visitors who make a purchase"
        },
        cart_abandonment_rate: {
          benchmark: 69.8,
          unit: "%",
          good: 65.0,
          excellent: 60.0,
          description: "Percentage of users who add items but don't purchase"
        },
        average_order_value: {
          benchmark: 95,
          unit: "$",
          good: 120,
          excellent: 150,
          description: "Average amount spent per order"
        },
        customer_lifetime_value: {
          benchmark: 168,
          unit: "$",
          good: 250,
          excellent: 400,
          description: "Total revenue from a customer over their lifetime"
        },
        repeat_purchase_rate: {
          benchmark: 28,
          unit: "%",
          good: 35,
          excellent: 45,
          description: "Percentage of customers who purchase again"
        },
        product_page_views_to_purchase: {
          benchmark: 8.2,
          unit: "views",
          good: 6.0,
          excellent: 4.0,
          description: "Average product views before purchase"
        },
        mobile_conversion_rate: {
          benchmark: 2.2,
          unit: "%",
          good: 3.0,
          excellent: 4.0,
          description: "Mobile visitor conversion rate"
        },
        email_conversion_rate: {
          benchmark: 4.3,
          unit: "%",
          good: 6.0,
          excellent: 8.0,
          description: "Email campaign conversion rate"
        },
        inventory_turnover: {
          benchmark: 6,
          unit: "times/year",
          good: 8,
          excellent: 12,
          description: "How often inventory is sold and replaced"
        },
        return_rate: {
          benchmark: 8.5,
          unit: "%",
          good: 6.0,
          excellent: 4.0,
          description: "Percentage of orders returned"
        }
      }.freeze

      # Seasonal patterns for different product categories
      SEASONAL_PATTERNS = {
        electronics: {
          peak_months: [ 11, 12 ], # Black Friday, Holiday
          slow_months: [ 2, 3, 4 ],
          peak_multiplier: 2.5
        },
        fashion: {
          peak_months: [ 3, 4, 9, 10 ], # Spring/Fall collections
          slow_months: [ 1, 7 ],
          peak_multiplier: 1.8
        },
        home_garden: {
          peak_months: [ 4, 5, 6 ], # Spring/Summer
          slow_months: [ 11, 12, 1 ],
          peak_multiplier: 2.0
        },
        toys_games: {
          peak_months: [ 11, 12 ], # Holiday season
          slow_months: [ 1, 2, 3, 4, 5, 6 ],
          peak_multiplier: 4.0
        }
      }.freeze

      attr_reader :organization

      def initialize(organization)
        @organization = organization
      end

      def analyze_performance
        insights = []

        # Core e-commerce metrics
        insights << analyze_conversion_funnel
        insights << analyze_cart_abandonment
        insights << analyze_customer_value
        insights << analyze_product_performance
        insights << analyze_inventory_health
        insights << analyze_marketing_effectiveness
        insights << analyze_seasonal_trends
        insights << analyze_mobile_performance

        # Competitive analysis
        insights << benchmark_against_industry

        # Opportunities
        insights << identify_growth_opportunities

        insights.compact
      end

      def seasonal_insights
        current_month = Date.current.month
        insights = []

        # Detect product categories
        categories = detect_product_categories

        categories.each do |category|
          pattern = SEASONAL_PATTERNS[category] || SEASONAL_PATTERNS[:electronics]

          if pattern[:peak_months].include?(current_month + 1)
            insights << {
              type: :seasonal_preparation,
              title: "Prepare for #{category.to_s.humanize} peak season",
              description: "Peak season for #{category} starts next month. Historical data shows #{pattern[:peak_multiplier]}x normal sales.",
              recommendations: [
                "Increase inventory by #{((pattern[:peak_multiplier] - 1) * 100).round}%",
                "Prepare marketing campaigns",
                "Ensure website can handle #{pattern[:peak_multiplier]}x traffic",
                "Train additional customer service staff",
                "Review and optimize checkout process"
              ],
              priority: "high",
              time_sensitive: true
            }
          end
        end

        insights
      end

      def optimization_recommendations
        recommendations = []

        metrics = calculate_current_metrics

        METRICS.each do |metric_key, benchmark|
          current_value = metrics[metric_key]
          next unless current_value

          performance = assess_performance(current_value, benchmark)

          if performance == :poor
            recommendations << generate_improvement_recommendation(metric_key, current_value, benchmark)
          elsif performance == :good
            recommendations << generate_optimization_recommendation(metric_key, current_value, benchmark)
          end
        end

        recommendations
      end

      private

      def analyze_conversion_funnel
        # Get funnel data
        visitors = get_visitor_count(30.days)
        add_to_carts = get_add_to_cart_count(30.days)
        checkouts_started = get_checkout_started_count(30.days)
        orders = get_order_count(30.days)

        # Calculate conversion rates
        browse_to_cart = visitors > 0 ? (add_to_carts.to_f / visitors * 100) : 0
        cart_to_checkout = add_to_carts > 0 ? (checkouts_started.to_f / add_to_carts * 100) : 0
        checkout_to_order = checkouts_started > 0 ? (orders.to_f / checkouts_started * 100) : 0
        overall_conversion = visitors > 0 ? (orders.to_f / visitors * 100) : 0

        # Identify bottlenecks
        biggest_drop = identify_funnel_bottleneck(browse_to_cart, cart_to_checkout, checkout_to_order)

        if overall_conversion < METRICS[:conversion_rate][:benchmark]
          {
            type: :conversion_optimization,
            title: "Conversion rate #{overall_conversion.round(1)}% is below industry average",
            description: "Your conversion rate is #{(METRICS[:conversion_rate][:benchmark] - overall_conversion).round(1)} percentage points below the industry average.",
            details: {
              funnel_metrics: {
                visitors: visitors,
                add_to_carts: add_to_carts,
                checkouts_started: checkouts_started,
                orders: orders
              },
              conversion_rates: {
                browse_to_cart: browse_to_cart,
                cart_to_checkout: cart_to_checkout,
                checkout_to_order: checkout_to_order,
                overall: overall_conversion
              },
              biggest_drop: biggest_drop
            },
            recommendations: generate_funnel_recommendations(biggest_drop),
            impact: "high",
            confidence: 0.85
          }
        end
      end

      def analyze_cart_abandonment
        abandonment_rate = calculate_cart_abandonment_rate

        if abandonment_rate > METRICS[:cart_abandonment_rate][:good]
          abandoned_revenue = calculate_abandoned_cart_value

          {
            type: :cart_abandonment,
            title: "High cart abandonment rate: #{abandonment_rate.round(1)}%",
            description: "#{number_to_currency(abandoned_revenue)} in potential revenue abandoned in carts last 30 days.",
            details: {
              abandonment_rate: abandonment_rate,
              abandoned_revenue: abandoned_revenue,
              top_abandoned_products: get_top_abandoned_products(5),
              abandonment_reasons: analyze_abandonment_reasons
            },
            recommendations: [
              "Implement abandoned cart email series",
              "Simplify checkout process",
              "Display security badges prominently",
              "Offer guest checkout option",
              "Show shipping costs earlier",
              "Add progress indicators to checkout"
            ],
            impact: "high",
            confidence: 0.90
          }
        end
      end

      def analyze_customer_value
        avg_order_value = calculate_average_order_value
        customer_ltv = calculate_customer_lifetime_value
        repeat_rate = calculate_repeat_purchase_rate

        insights = []

        if avg_order_value < METRICS[:average_order_value][:benchmark]
          insights << {
            type: :low_order_value,
            title: "Average order value #{number_to_currency(avg_order_value)} below benchmark",
            description: "Increasing AOV by 20% would add #{number_to_currency(calculate_aov_impact(0.2))} monthly revenue.",
            recommendations: [
              "Implement product bundles",
              "Add upsell recommendations",
              "Offer free shipping thresholds",
              "Create volume discounts",
              "Suggest complementary products"
            ],
            impact: "medium",
            confidence: 0.82
          }
        end

        if repeat_rate < METRICS[:repeat_purchase_rate][:benchmark]
          insights << {
            type: :low_repeat_rate,
            title: "Low repeat purchase rate: #{repeat_rate.round(1)}%",
            description: "Only #{repeat_rate.round(1)}% of customers make a second purchase.",
            recommendations: [
              "Launch loyalty program",
              "Send personalized follow-up emails",
              "Offer first-time buyer discounts",
              "Improve post-purchase experience",
              "Create subscription options"
            ],
            impact: "high",
            confidence: 0.88
          }
        end

        insights.first
      end

      def analyze_product_performance
        # Get product performance data
        products = get_product_performance_data

        # Find underperformers
        underperformers = products.select { |p| p[:conversion_rate] < 1.0 }
        slow_movers = products.select { |p| p[:days_in_inventory] > 90 }

        if underperformers.any? || slow_movers.any?
          {
            type: :product_optimization,
            title: "#{underperformers.count + slow_movers.count} products need attention",
            description: "Underperforming products are impacting overall metrics.",
            details: {
              low_conversion_products: underperformers.first(5),
              slow_moving_inventory: slow_movers.first(5),
              tied_up_capital: calculate_slow_moving_inventory_value(slow_movers)
            },
            recommendations: [
              "Review product descriptions and images",
              "Adjust pricing on slow movers",
              "Run clearance promotions",
              "Improve product discovery",
              "Consider discontinuing poor performers"
            ],
            impact: "medium",
            confidence: 0.80
          }
        end
      end

      def analyze_inventory_health
        turnover_rate = calculate_inventory_turnover
        stockout_instances = count_stockouts(30.days)
        overstock_value = calculate_overstock_value

        issues = []

        if turnover_rate < METRICS[:inventory_turnover][:benchmark]
          issues << "Low inventory turnover (#{turnover_rate.round(1)}x/year)"
        end

        if stockout_instances > 10
          issues << "#{stockout_instances} stockouts in last 30 days"
        end

        if overstock_value > 50000
          issues << "#{number_to_currency(overstock_value)} in overstock"
        end

        if issues.any?
          {
            type: :inventory_optimization,
            title: "Inventory management needs optimization",
            description: issues.join(". "),
            details: {
              turnover_rate: turnover_rate,
              stockout_instances: stockout_instances,
              overstock_value: overstock_value,
              top_overstock_items: get_overstock_items(5)
            },
            recommendations: [
              "Implement demand forecasting",
              "Set up automatic reorder points",
              "Run promotions on overstock items",
              "Analyze sales velocity by SKU",
              "Optimize safety stock levels"
            ],
            impact: "medium",
            confidence: 0.85
          }
        end
      end

      def analyze_marketing_effectiveness
        channels = analyze_channel_performance
        email_metrics = analyze_email_performance

        underperforming_channels = channels.select { |c| c[:roi] < 2.0 }

        if underperforming_channels.any?
          {
            type: :marketing_optimization,
            title: "#{underperforming_channels.count} marketing channels underperforming",
            description: "Several channels showing ROI below 2.0x.",
            details: {
              channel_performance: channels,
              email_metrics: email_metrics,
              total_marketing_spend: calculate_total_marketing_spend,
              blended_cac: calculate_blended_cac
            },
            recommendations: [
              "Reallocate budget to high-ROI channels",
              "Test new creative formats",
              "Improve landing page conversion",
              "Refine audience targeting",
              "A/B test ad copy and images"
            ],
            impact: "high",
            confidence: 0.78
          }
        end
      end

      def analyze_mobile_performance
        mobile_conversion = calculate_mobile_conversion_rate
        mobile_traffic_share = calculate_mobile_traffic_share

        if mobile_conversion < METRICS[:mobile_conversion_rate][:benchmark] && mobile_traffic_share > 0.5
          {
            type: :mobile_optimization,
            title: "Mobile conversion rate needs improvement",
            description: "#{(mobile_traffic_share * 100).round}% of traffic is mobile but converts at only #{mobile_conversion.round(1)}%.",
            details: {
              mobile_conversion_rate: mobile_conversion,
              desktop_conversion_rate: calculate_desktop_conversion_rate,
              mobile_traffic_share: mobile_traffic_share,
              mobile_revenue_share: calculate_mobile_revenue_share
            },
            recommendations: [
              "Optimize mobile page load speed",
              "Simplify mobile checkout",
              "Implement mobile-specific features",
              "Test thumb-friendly button placement",
              "Add mobile payment options (Apple Pay, Google Pay)"
            ],
            impact: "high",
            confidence: 0.87
          }
        end
      end

      def benchmark_against_industry
        metrics = calculate_current_metrics

        below_benchmark = []
        above_benchmark = []

        METRICS.each do |key, benchmark|
          current = metrics[key]
          next unless current

          if current < benchmark[:benchmark]
            below_benchmark << {
              metric: key.to_s.humanize,
              current: current,
              benchmark: benchmark[:benchmark],
              gap: benchmark[:benchmark] - current,
              unit: benchmark[:unit]
            }
          elsif current > benchmark[:good]
            above_benchmark << {
              metric: key.to_s.humanize,
              current: current,
              benchmark: benchmark[:good],
              unit: benchmark[:unit]
            }
          end
        end

        {
          type: :industry_benchmark,
          title: "E-commerce performance vs industry standards",
          description: "#{below_benchmark.count} metrics below average, #{above_benchmark.count} above average.",
          details: {
            below_benchmark: below_benchmark,
            above_benchmark: above_benchmark,
            overall_score: calculate_industry_score(metrics)
          },
          recommendations: generate_benchmark_recommendations(below_benchmark),
          impact: "medium",
          confidence: 0.83
        }
      end

      def identify_growth_opportunities
        opportunities = []

        # International expansion
        if calculate_international_revenue_share < 0.1
          opportunities << {
            type: "international_expansion",
            potential_revenue: estimate_international_opportunity,
            description: "Expand to international markets"
          }
        end

        # Subscription model
        if !has_subscription_offering?
          opportunities << {
            type: "subscription_model",
            potential_revenue: estimate_subscription_opportunity,
            description: "Launch subscription service for consumables"
          }
        end

        # B2B sales
        if calculate_b2b_revenue_share < 0.2
          opportunities << {
            type: "b2b_expansion",
            potential_revenue: estimate_b2b_opportunity,
            description: "Develop B2B sales channel"
          }
        end

        if opportunities.any?
          {
            type: :growth_opportunities,
            title: "Identified #{opportunities.count} growth opportunities",
            description: "Total potential revenue: #{number_to_currency(opportunities.sum { |o| o[:potential_revenue] })}",
            details: {
              opportunities: opportunities,
              implementation_timeline: generate_growth_timeline(opportunities)
            },
            recommendations: opportunities.map { |o| o[:description] },
            impact: "high",
            confidence: 0.75
          }
        end
      end

      # Helper methods
      def calculate_current_metrics
        {
          conversion_rate: calculate_conversion_rate,
          cart_abandonment_rate: calculate_cart_abandonment_rate,
          average_order_value: calculate_average_order_value,
          customer_lifetime_value: calculate_customer_lifetime_value,
          repeat_purchase_rate: calculate_repeat_purchase_rate,
          mobile_conversion_rate: calculate_mobile_conversion_rate,
          email_conversion_rate: calculate_email_conversion_rate,
          inventory_turnover: calculate_inventory_turnover,
          return_rate: calculate_return_rate
        }
      end

      def assess_performance(current, benchmark)
        if current < benchmark[:benchmark]
          :poor
        elsif current >= benchmark[:excellent]
          :excellent
        elsif current >= benchmark[:good]
          :good
        else
          :average
        end
      end

      def generate_improvement_recommendation(metric, current, benchmark)
        improvement_needed = ((benchmark[:benchmark] - current) / current * 100).round

        {
          metric: metric.to_s.humanize,
          current: current,
          target: benchmark[:benchmark],
          improvement_needed: "#{improvement_needed}%",
          potential_impact: calculate_metric_impact(metric, improvement_needed),
          priority: determine_priority(metric)
        }
      end

      def detect_product_categories
        # Analyze product data to detect categories
        [ :electronics, :fashion ]
      end

      def get_visitor_count(period)
        # Fetch visitor data
        10000
      end

      def get_add_to_cart_count(period)
        # Fetch add to cart events
        2500
      end

      def get_checkout_started_count(period)
        # Fetch checkout started events
        1800
      end

      def get_order_count(period)
        # Fetch completed orders
        310
      end

      def identify_funnel_bottleneck(browse_to_cart, cart_to_checkout, checkout_to_order)
        bottlenecks = {
          browse_to_cart: browse_to_cart,
          cart_to_checkout: cart_to_checkout,
          checkout_to_order: checkout_to_order
        }

        bottlenecks.min_by { |_, v| v }.first
      end

      def generate_funnel_recommendations(bottleneck)
        case bottleneck
        when :browse_to_cart
          [
            "Improve product page descriptions",
            "Add customer reviews",
            "Show product in use",
            "Highlight unique value propositions",
            "Add urgency indicators"
          ]
        when :cart_to_checkout
          [
            "Simplify cart page",
            "Show security badges",
            "Add trust signals",
            "Display shipping options clearly",
            "Remove distractions"
          ]
        when :checkout_to_order
          [
            "Reduce form fields",
            "Offer guest checkout",
            "Show progress indicator",
            "Add payment options",
            "Improve error messages"
          ]
        end
      end

      def calculate_conversion_rate
        visitors = get_visitor_count(30.days)
        orders = get_order_count(30.days)

        visitors > 0 ? (orders.to_f / visitors * 100) : 0
      end

      def calculate_cart_abandonment_rate
        # Implementation would fetch actual data
        72.5
      end

      def calculate_abandoned_cart_value
        # Sum of abandoned cart values
        45000
      end

      def calculate_average_order_value
        # Average order value calculation
        87.50
      end

      def calculate_customer_lifetime_value
        # CLV calculation
        156.00
      end

      def calculate_repeat_purchase_rate
        # Repeat purchase rate
        24.5
      end

      def calculate_inventory_turnover
        # Inventory turnover calculation
        5.2
      end

      def calculate_mobile_conversion_rate
        # Mobile conversion rate
        1.8
      end

      def calculate_email_conversion_rate
        # Email conversion rate
        3.9
      end

      def calculate_return_rate
        # Return rate calculation
        9.2
      end
    end
  end
end
