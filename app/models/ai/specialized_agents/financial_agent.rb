# frozen_string_literal: true

module Ai
  module SpecializedAgents
    class FinancialAgent < BaseAgent
      def specific_capabilities
        [
          'Cash flow analysis and forecasting',
          'Profitability analysis by product/service/customer',
          'Budget variance detection',
          'Financial health scoring',
          'Revenue recognition patterns',
          'Cost optimization opportunities',
          'Working capital management',
          'Financial risk assessment'
        ]
      end
      
      def required_data_sources
        %w[
          quickbooks
          stripe
          bank_accounts
          expense_systems
          payroll
          invoicing
        ]
      end
      
      def supported_output_types
        %w[
          financial_summary
          cash_flow_forecast
          profit_loss_statement
          budget_variance_report
          financial_health_score
          cost_analysis
          revenue_breakdown
        ]
      end
      
      def integration_points
        %w[
          accounting_software
          payment_processors
          banking_apis
          expense_management
          budgeting_tools
        ]
      end
      
      protected
      
      def perform_analysis(data, context)
        results = []
        
        # Cash flow analysis
        results << analyze_cash_flow(data)
        
        # Profitability analysis
        results << analyze_profitability(data)
        
        # Budget variance
        results << analyze_budget_variance(data)
        
        # Financial health
        results << calculate_financial_health(data)
        
        # Cost optimization
        results << identify_cost_savings(data)
        
        # Revenue trends
        results << analyze_revenue_trends(data)
        
        results.compact
      end
      
      private
      
      def analyze_cash_flow(data)
        # Get cash flow data
        inflows = calculate_cash_inflows
        outflows = calculate_cash_outflows
        
        current_balance = inflows - outflows
        runway_months = calculate_runway(current_balance, outflows)
        
        # Detect issues
        if runway_months < 3
          {
            type: :cash_flow_warning,
            severity: :critical,
            summary: "Cash runway is only #{runway_months.round(1)} months",
            details: {
              current_balance: current_balance,
              monthly_burn: outflows / 30,
              runway_months: runway_months
            },
            recommendations: [
              "Accelerate receivables collection",
              "Negotiate extended payment terms with suppliers",
              "Consider short-term financing options",
              "Reduce discretionary spending"
            ],
            confidence: 0.95,
            impact: 'critical',
            actionable: true,
            time_sensitive: true
          }
        elsif runway_months < 6
          {
            type: :cash_flow_caution,
            severity: :high,
            summary: "Cash position requires attention - #{runway_months.round(1)} months runway",
            details: {
              current_balance: current_balance,
              monthly_burn: outflows / 30,
              runway_months: runway_months
            },
            recommendations: [
              "Monitor cash position weekly",
              "Prepare contingency financing",
              "Review and optimize payment cycles"
            ],
            confidence: 0.90,
            impact: 'high',
            actionable: true
          }
        end
      end
      
      def analyze_profitability(data)
        # Calculate profitability metrics
        revenue = calculate_total_revenue
        costs = calculate_total_costs
        gross_margin = (revenue - costs) / revenue * 100
        
        # Analyze by segment
        segment_profitability = analyze_segment_profitability
        
        # Find underperforming segments
        underperformers = segment_profitability.select { |s| s[:margin] < 10 }
        
        if underperformers.any?
          {
            type: :profitability_concern,
            severity: :high,
            summary: "#{underperformers.count} segments have margins below 10%",
            details: {
              overall_margin: gross_margin,
              underperforming_segments: underperformers,
              revenue_at_risk: underperformers.sum { |s| s[:revenue] }
            },
            recommendations: [
              "Review pricing for low-margin segments",
              "Analyze cost structure for optimization",
              "Consider discontinuing unprofitable products",
              "Implement activity-based costing"
            ],
            confidence: 0.85,
            impact: 'high',
            actionable: true,
            metadata: {
              segments: underperformers,
              analysis_period: '30_days'
            }
          }
        end
      end
      
      def analyze_budget_variance(data)
        # Compare actual vs budget
        budget = get_current_budget
        actuals = get_actual_spending
        
        variances = calculate_variances(budget, actuals)
        
        # Find significant variances (>10%)
        significant_variances = variances.select { |v| v[:variance_percent].abs > 10 }
        
        if significant_variances.any?
          total_variance = significant_variances.sum { |v| v[:variance_amount] }
          
          {
            type: :budget_variance,
            severity: total_variance > 0 ? :medium : :high,
            summary: "#{significant_variances.count} budget categories show >10% variance",
            details: {
              total_variance: total_variance,
              variance_categories: significant_variances,
              biggest_variance: significant_variances.max_by { |v| v[:variance_percent].abs }
            },
            recommendations: generate_budget_recommendations(significant_variances),
            confidence: 0.88,
            impact: total_variance > 0 ? 'medium' : 'high',
            actionable: true
          }
        end
      end
      
      def calculate_financial_health(data)
        # Calculate key financial ratios
        metrics = {
          current_ratio: calculate_current_ratio,
          quick_ratio: calculate_quick_ratio,
          debt_to_equity: calculate_debt_to_equity,
          days_sales_outstanding: calculate_dso,
          gross_margin: calculate_gross_margin,
          operating_margin: calculate_operating_margin
        }
        
        # Score financial health
        health_score = score_financial_health(metrics)
        
        if health_score < 60
          {
            type: :financial_health_warning,
            severity: :high,
            summary: "Financial health score is #{health_score}/100 - requires attention",
            details: {
              score: health_score,
              metrics: metrics,
              weak_areas: identify_weak_areas(metrics)
            },
            recommendations: generate_health_recommendations(metrics),
            confidence: 0.82,
            impact: 'high',
            actionable: true
          }
        end
      end
      
      def identify_cost_savings(data)
        # Analyze spending patterns
        expenses = get_expense_data
        
        # Find optimization opportunities
        opportunities = []
        
        # Duplicate vendors
        duplicate_vendors = find_duplicate_vendors(expenses)
        if duplicate_vendors.any?
          opportunities << {
            type: 'vendor_consolidation',
            savings: calculate_consolidation_savings(duplicate_vendors),
            description: "Consolidate #{duplicate_vendors.count} duplicate vendor relationships"
          }
        end
        
        # Subscription optimization
        unused_subscriptions = find_unused_subscriptions
        if unused_subscriptions.any?
          opportunities << {
            type: 'subscription_optimization',
            savings: unused_subscriptions.sum { |s| s[:monthly_cost] },
            description: "Cancel or downgrade #{unused_subscriptions.count} underutilized subscriptions"
          }
        end
        
        # Volume discounts
        volume_opportunities = identify_volume_discount_opportunities
        if volume_opportunities.any?
          opportunities << {
            type: 'volume_discounts',
            savings: volume_opportunities.sum { |v| v[:potential_savings] },
            description: "Negotiate volume discounts with #{volume_opportunities.count} vendors"
          }
        end
        
        if opportunities.any?
          total_savings = opportunities.sum { |o| o[:savings] }
          
          {
            type: :cost_optimization,
            severity: :medium,
            summary: "Identified #{ActionController::Base.helpers.number_to_currency(total_savings)} in potential cost savings",
            details: {
              opportunities: opportunities,
              total_savings: total_savings,
              implementation_effort: assess_implementation_effort(opportunities)
            },
            recommendations: opportunities.map { |o| o[:description] },
            confidence: 0.78,
            impact: 'medium',
            actionable: true,
            metadata: {
              quick_wins: opportunities.select { |o| o[:type] == 'subscription_optimization' }
            }
          }
        end
      end
      
      def analyze_revenue_trends(data)
        # Get revenue data
        revenue_by_month = get_monthly_revenue(6)
        
        # Calculate trends
        growth_rate = calculate_growth_rate(revenue_by_month)
        seasonality = detect_seasonality(revenue_by_month)
        concentration = calculate_customer_concentration
        
        # Detect concerning trends
        if growth_rate < 0
          {
            type: :revenue_decline,
            severity: :critical,
            summary: "Revenue declining at #{(growth_rate * 100).round(1)}% monthly rate",
            details: {
              monthly_revenue: revenue_by_month,
              growth_rate: growth_rate,
              decline_started: find_decline_start(revenue_by_month),
              revenue_at_risk: calculate_revenue_at_risk(growth_rate)
            },
            recommendations: [
              "Analyze customer churn drivers",
              "Review competitive positioning",
              "Accelerate new customer acquisition",
              "Implement retention programs",
              "Consider new revenue streams"
            ],
            confidence: 0.92,
            impact: 'critical',
            actionable: true,
            time_sensitive: true
          }
        elsif concentration > 0.3
          {
            type: :customer_concentration_risk,
            severity: :high,
            summary: "Top 10% of customers represent #{(concentration * 100).round}% of revenue",
            details: {
              concentration_ratio: concentration,
              top_customers: get_top_customers(10),
              revenue_distribution: calculate_revenue_distribution
            },
            recommendations: [
              "Diversify customer base",
              "Strengthen relationships with key accounts",
              "Develop customer expansion strategies",
              "Create loyalty programs for top customers"
            ],
            confidence: 0.87,
            impact: 'high',
            actionable: true
          }
        end
      end
      
      # Helper methods for financial calculations
      def calculate_cash_inflows
        organization.raw_data_records
                    .where(record_type: 'payment', created_at: 30.days.ago..Time.current)
                    .sum('(data->>\'amount\')::decimal')
      end
      
      def calculate_cash_outflows
        organization.raw_data_records
                    .where(record_type: 'expense', created_at: 30.days.ago..Time.current)
                    .sum('(data->>\'amount\')::decimal')
      end
      
      def calculate_runway(balance, monthly_burn)
        return Float::INFINITY if monthly_burn <= 0
        balance / monthly_burn
      end
      
      def calculate_total_revenue
        organization.raw_data_records
                    .where(record_type: 'order', created_at: 30.days.ago..Time.current)
                    .sum('(data->>\'total\')::decimal')
      end
      
      def calculate_total_costs
        organization.raw_data_records
                    .where(record_type: 'expense', created_at: 30.days.ago..Time.current)
                    .sum('(data->>\'amount\')::decimal')
      end
      
      def analyze_segment_profitability
        # This would analyze profitability by product, customer segment, etc.
        []
      end
      
      def get_current_budget
        # Fetch budget data
        {}
      end
      
      def get_actual_spending
        # Fetch actual spending data
        {}
      end
      
      def calculate_variances(budget, actuals)
        # Compare budget vs actuals
        []
      end
      
      def generate_budget_recommendations(variances)
        recommendations = []
        
        variances.each do |variance|
          if variance[:variance_percent] > 0
            recommendations << "Investigate overspending in #{variance[:category]}"
          else
            recommendations << "Reallocate surplus from #{variance[:category]}"
          end
        end
        
        recommendations
      end
      
      def calculate_current_ratio
        # Current assets / Current liabilities
        1.5
      end
      
      def calculate_quick_ratio
        # (Current assets - Inventory) / Current liabilities
        1.2
      end
      
      def calculate_debt_to_equity
        # Total debt / Total equity
        0.4
      end
      
      def calculate_dso
        # Days Sales Outstanding
        45
      end
      
      def calculate_gross_margin
        # (Revenue - COGS) / Revenue
        0.35
      end
      
      def calculate_operating_margin
        # Operating income / Revenue
        0.15
      end
      
      def score_financial_health(metrics)
        # Scoring algorithm based on financial ratios
        score = 100
        
        score -= 20 if metrics[:current_ratio] < 1.0
        score -= 15 if metrics[:quick_ratio] < 0.8
        score -= 10 if metrics[:debt_to_equity] > 1.0
        score -= 10 if metrics[:days_sales_outstanding] > 60
        score -= 15 if metrics[:gross_margin] < 0.25
        score -= 10 if metrics[:operating_margin] < 0.05
        
        [score, 0].max
      end
      
      def identify_weak_areas(metrics)
        weak_areas = []
        
        weak_areas << 'liquidity' if metrics[:current_ratio] < 1.0
        weak_areas << 'leverage' if metrics[:debt_to_equity] > 1.0
        weak_areas << 'collections' if metrics[:days_sales_outstanding] > 60
        weak_areas << 'profitability' if metrics[:gross_margin] < 0.25
        
        weak_areas
      end
      
      def generate_health_recommendations(metrics)
        recommendations = []
        
        if metrics[:current_ratio] < 1.0
          recommendations << "Improve working capital management"
        end
        
        if metrics[:days_sales_outstanding] > 60
          recommendations << "Accelerate accounts receivable collection"
        end
        
        if metrics[:gross_margin] < 0.25
          recommendations << "Review pricing strategy and cost structure"
        end
        
        recommendations
      end
      
      def get_expense_data
        organization.raw_data_records
                    .where(record_type: 'expense')
                    .where(created_at: 90.days.ago..Time.current)
      end
      
      def find_duplicate_vendors(expenses)
        # Group by vendor and find duplicates
        []
      end
      
      def find_unused_subscriptions
        # Analyze subscription usage
        []
      end
      
      def identify_volume_discount_opportunities
        # Find vendors with high spend
        []
      end
      
      def calculate_consolidation_savings(vendors)
        # Estimate savings from vendor consolidation
        vendors.count * 500
      end
      
      def assess_implementation_effort(opportunities)
        # Categorize by implementation difficulty
        {
          easy: opportunities.count { |o| o[:type] == 'subscription_optimization' },
          medium: opportunities.count { |o| o[:type] == 'vendor_consolidation' },
          hard: opportunities.count { |o| o[:type] == 'volume_discounts' }
        }
      end
      
      def get_monthly_revenue(months)
        # Fetch revenue by month
        (1..months).map { |i| rand(80000..120000) }
      end
      
      def calculate_growth_rate(revenue_data)
        # Calculate month-over-month growth
        return 0 if revenue_data.size < 2
        
        (revenue_data.last - revenue_data.first) / revenue_data.first.to_f / revenue_data.size
      end
      
      def detect_seasonality(revenue_data)
        # Detect seasonal patterns
        {}
      end
      
      def calculate_customer_concentration
        # Calculate revenue concentration
        0.25
      end
      
      def find_decline_start(revenue_data)
        # Find when decline started
        "2 months ago"
      end
      
      def calculate_revenue_at_risk(growth_rate)
        # Project revenue loss
        current_revenue = 100000
        (current_revenue * growth_rate * 3).abs
      end
      
      def get_top_customers(count)
        # Get top revenue customers
        []
      end
      
      def calculate_revenue_distribution
        # Calculate revenue distribution
        {}
      end
    end
  end
end