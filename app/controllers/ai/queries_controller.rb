# frozen_string_literal: true

module Ai
  class QueriesController < ApplicationController
    before_action :ensure_organization_member
    
    def index
      # Safely handle ai_insights in case the table doesn't exist yet
      @recent_insights = begin
        current_organization.ai_insights.recent.limit(10)
      rescue ActiveRecord::StatementInvalid => e
        Rails.logger.warn "ai_insights table not found: #{e.message}"
        []
      end
      
      @popular_queries = get_popular_query_examples
      @data_summary = fetch_organization_data_summary
    end
    
    def process_query
      query_text = params[:query]&.strip
      
      if query_text.blank?
        return render json: {
          success: false,
          error: "Please enter a query"
        }, status: :bad_request
      end
      
      begin
        # Process the natural language query
        query_service = Ai::NaturalLanguageQueryService.new(
          organization: current_organization,
          user_query: query_text
        )
        
        result = query_service.process_query
        
        # Store the query for future reference (if model exists)
        store_query_history(query_text, result) if defined?(AiQuery)
        
        render json: {
          success: true,
          query: query_text,
          result: result,
          suggestions: query_service.get_query_suggestions,
          processed_at: Time.current.iso8601
        }
        
      rescue => e
        Rails.logger.error "Natural language query processing failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        render json: {
          success: false,
          error: "Failed to process your query. Please try rephrasing it.",
          suggestions: get_fallback_suggestions,
          debug_error: Rails.env.development? ? e.message : nil
        }, status: :internal_server_error
      end
    end
    
    def suggestions
      partial_query = params[:q]&.strip || ""
      
      query_service = Ai::NaturalLanguageQueryService.new(
        organization: current_organization,
        user_query: ""
      )
      
      suggestions = query_service.get_query_suggestions(partial_query)
      
      render json: {
        suggestions: suggestions,
        generated_at: Time.current.iso8601
      }
    end
    
    def validate
      query_text = params[:query]&.strip
      
      if query_text.blank?
        return render json: {
          valid: false,
          message: "Please enter a query"
        }
      end
      
      query_service = Ai::NaturalLanguageQueryService.new(
        organization: current_organization,
        user_query: query_text
      )
      
      validation = query_service.validate_query(query_text)
      
      render json: {
        valid: validation[:can_process],
        confidence: validation[:confidence],
        missing_data: validation[:missing_data],
        suggestions: validation[:suggestions],
        message: build_validation_message(validation)
      }
    end
    
    def examples
      render json: {
        examples: get_query_examples_by_category,
        data_available: fetch_organization_data_summary
      }
    end
    
    def export
      query_id = params[:id]
      format = params[:format] || 'csv'
      
      # This would export query results
      # For now, return a placeholder
      render json: {
        success: true,
        message: "Export feature coming soon",
        requested_format: format
      }
    end
    
    private
    
    def store_query_history(query_text, result)
      # Store query for analytics and improvement
      # This assumes an AiQuery model exists
      begin
        current_organization.ai_queries.create!(
          query_text: query_text,
          query_type: result[:query_analysis][:query_type],
          confidence: result[:confidence],
          results_count: extract_results_count(result),
          processing_time: result[:processing_time],
          user: current_user,
          processed_at: Time.current
        )
      rescue => e
        Rails.logger.warn "Failed to store query history: #{e.message}"
      end
    end
    
    def get_popular_query_examples
      [
        {
          category: "Customer Analysis",
          queries: [
            "Show me customers who haven't ordered in 30 days",
            "Which customers spent the most this quarter?",
            "How many new customers did we get last week?",
            "Show me VIP customers with orders over $1000"
          ]
        },
        {
          category: "Revenue & Sales",
          queries: [
            "What's my revenue this month vs last month?",
            "Show me revenue by product category",
            "What's my average order value this week?",
            "Which days have the highest sales?"
          ]
        },
        {
          category: "Product Performance",
          queries: [
            "What products are trending up this month?",
            "Which products have the highest profit margins?",
            "Show me my best-selling products this quarter",
            "What products are declining in sales?"
          ]
        },
        {
          category: "Order Analysis",
          queries: [
            "Show me orders over $500 this month",
            "What's the average processing time for orders?",
            "Which orders are taking longest to fulfill?",
            "Show me refunded orders this week"
          ]
        }
      ]
    end

    def fetch_organization_data_summary
      {
        customers: current_organization.raw_data_records
                                      .where(record_type: "customer")
                                      .count,
        orders: current_organization.raw_data_records
                                   .where(record_type: "order")
                                   .count,
        products: current_organization.raw_data_records
                                     .where(record_type: "product")
                                     .count,
        data_sources: current_organization.data_sources.count,
        date_range: {
          earliest: current_organization.raw_data_records.minimum(:created_at),
          latest: current_organization.raw_data_records.maximum(:created_at)
        },
        last_updated: current_organization.raw_data_records.maximum(:created_at)
      }
    end
    
    def get_fallback_suggestions
      [
        "Try asking about customers, orders, products, or revenue",
        "Use specific time periods like 'this month' or 'last week'",
        "Ask for comparisons like 'this month vs last month'",
        "Be specific about what you want to see"
      ]
    end
    
    def build_validation_message(validation)
      if validation[:can_process]
        confidence_text = case validation[:confidence]
                         when 0.8..1.0 then "I'm confident I can answer this"
                         when 0.6..0.8 then "I should be able to help with this"
                         when 0.4..0.6 then "I'll try my best to answer this"
                         else "This query might need refinement"
                         end
        
        confidence_text
      else
        "I need more information to answer this query"
      end
    end
    
    def get_query_examples_by_category
      {
        beginner: [
          "How many customers do I have?",
          "What's my total revenue this month?",
          "Show me my recent orders"
        ],
        intermediate: [
          "Which customers haven't ordered in 60 days?",
          "Compare revenue this quarter vs last quarter",
          "What are my top 5 products by sales?"
        ],
        advanced: [
          "Show me customer lifetime value trends by segment",
          "Which products have declining sales but increasing margins?",
          "Analyze customer churn risk by order frequency"
        ]
      }
    end
    
    def extract_results_count(result)
      return 0 unless result[:results]
      
      if result[:results][:count]
        result[:results][:count]
      elsif result[:results][:customers]
        result[:results][:customers].count
      elsif result[:results][:orders]
        result[:results][:orders].count
      else
        0
      end
    end
  end
end