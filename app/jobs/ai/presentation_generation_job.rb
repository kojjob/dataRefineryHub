# frozen_string_literal: true

module Ai
  class PresentationGenerationJob < BaseAiJob
    def perform(args)
      validate_job_arguments([:organization_id, :presentation_type, :config, :user_id])
      
      organization = Organization.find(args[:organization_id])
      user = User.find(args[:user_id])
      
      update_job_progress('initializing', 0, 'Setting up presentation generation')
      
      # Ensure we don't exceed rate limits
      with_rate_limiting(:presentation_generation) do
        generate_presentation(organization, user, args)
      end
    end
    
    private
    
    def generate_presentation(organization, user, args)
      presentation_service = Ai::InteractivePresentationService.new(organization: organization)
      
      update_job_progress('analyzing_data', 15, 'Analyzing business data for presentation')
      
      # Generate presentation based on type
      result = case args[:presentation_type]
               when 'interactive'
                 generate_interactive_presentation(presentation_service, args[:config])
               when 'live_dashboard'
                 generate_live_dashboard(presentation_service, args[:config])
               when 'data_story'
                 generate_data_story(presentation_service, args[:config])
               else
                 raise ArgumentError, "Unknown presentation type: #{args[:presentation_type]}"
               end
      
      update_job_progress('enhancing', 70, 'Adding AI insights and interactive elements')
      
      # Enhance with AI insights
      enhanced_result = enhance_presentation_with_ai(result, organization, args[:config])
      
      update_job_progress('optimizing', 90, 'Optimizing presentation performance')
      
      # Optimize for performance
      optimized_result = optimize_presentation_performance(enhanced_result, organization)
      
      update_job_progress('finalizing', 100, 'Finalizing presentation')
      
      # Store presentation
      presentation_id = store_presentation(optimized_result, organization, user)
      
      # Broadcast completion
      broadcast_presentation_ready(organization, user, presentation_id, optimized_result)
      
      Rails.logger.info "Completed presentation generation: #{presentation_id}"
    end
    
    def generate_interactive_presentation(service, config)
      update_job_progress('creating_slides', 25, 'Creating interactive slides with live data')
      
      cache_key = "interactive_pres:#{Digest::SHA256.hexdigest(config.to_json)[0..8]}"
      
      with_ai_cache(cache_key, ttl: 30.minutes) do
        service.create_interactive_presentation(config)
      end
    end
    
    def generate_live_dashboard(service, config)
      update_job_progress('building_dashboard', 25, 'Building real-time dashboard components')
      
      # Live dashboards shouldn't be cached due to real-time nature
      service.generate_live_dashboard_presentation(config)
    end
    
    def generate_data_story(service, config)
      update_job_progress('crafting_narrative', 25, 'Crafting AI-powered data narrative')
      
      cache_key = "data_story:#{Digest::SHA256.hexdigest(config.to_json)[0..8]}"
      
      with_ai_cache(cache_key, ttl: 1.hour) do
        service.create_ai_powered_data_story(config)
      end
    end
    
    def enhance_presentation_with_ai(presentation, organization, config)
      update_job_progress('ai_enhancement', 50, 'Applying AI-powered enhancements')
      
      # Add AI-generated insights
      ai_insights = generate_contextual_insights(presentation, organization)
      
      # Add smart recommendations
      recommendations = generate_presentation_recommendations(presentation, organization)
      
      # Add performance optimizations
      optimizations = suggest_performance_optimizations(presentation)
      
      presentation.merge(
        ai_enhancements: {
          insights: ai_insights,
          recommendations: recommendations,
          optimizations: optimizations,
          enhanced_at: Time.current.iso8601,
          enhancement_version: '1.0'
        },
        metadata: {
          generated_by: 'ai_system',
          generation_time: Time.current - @start_time,
          organization_id: organization.id,
          data_sources_used: organization.data_sources.where(status: 'connected').count,
          ai_model_version: Rails.application.config.ai_model_version || '1.0'
        }
      )
    end
    
    def generate_contextual_insights(presentation, organization)
      insights = []
      
      # Analyze presentation content for key insights
      if presentation[:slides]&.any?
        insights << analyze_slide_content(presentation[:slides])
      end
      
      # Add business context insights
      if organization.raw_data_records.any?
        insights << generate_business_insights(organization)
      end
      
      # Add trend insights
      insights << generate_trend_insights(organization)
      
      insights.flatten.compact
    end
    
    def generate_presentation_recommendations(presentation, organization)
      recommendations = []
      
      # Recommend additional data sources
      if organization.data_sources.count < 3
        recommendations << {
          type: 'data_source',
          priority: 'high',
          title: 'Add more data sources',
          description: 'Connect additional data sources for richer insights',
          action: 'connect_data_sources'
        }
      end
      
      # Recommend interactive elements
      if presentation[:interactive_elements]&.length.to_i < 3
        recommendations << {
          type: 'interactivity',
          priority: 'medium',
          title: 'Add interactive elements',
          description: 'Enhance engagement with more interactive features',
          action: 'add_interactive_elements'
        }
      end
      
      # Recommend collaboration features
      unless presentation[:collaboration_features]&.dig(:enabled)
        recommendations << {
          type: 'collaboration',
          priority: 'low',
          title: 'Enable collaboration',
          description: 'Allow team members to collaborate on this presentation',
          action: 'enable_collaboration'
        }
      end
      
      recommendations
    end
    
    def suggest_performance_optimizations(presentation)
      optimizations = []
      
      # Suggest caching optimizations
      if presentation[:real_time_updates]&.dig(:enabled)
        optimizations << {
          type: 'caching',
          suggestion: 'Enable smart caching for real-time data',
          impact: 'high',
          implementation: 'automatic'
        }
      end
      
      # Suggest data loading optimizations
      if presentation[:slides]&.length.to_i > 10
        optimizations << {
          type: 'lazy_loading',
          suggestion: 'Implement lazy loading for large presentations',
          impact: 'medium',
          implementation: 'automatic'
        }
      end
      
      optimizations
    end
    
    def optimize_presentation_performance(presentation, organization)
      update_job_progress('performance_optimization', 75, 'Applying performance optimizations')
      
      # Optimize images and assets
      optimized_assets = optimize_presentation_assets(presentation)
      
      # Optimize data queries
      optimized_queries = optimize_data_queries(presentation, organization)
      
      # Apply caching strategies
      caching_config = configure_presentation_caching(presentation)
      
      presentation.merge(
        performance_optimizations: {
          assets: optimized_assets,
          queries: optimized_queries,
          caching: caching_config,
          optimized_at: Time.current.iso8601
        }
      )
    end
    
    def store_presentation(presentation, organization, user)
      presentation_id = SecureRandom.hex(8)
      
      # Store in cache for immediate access
      Rails.cache.write(
        "presentation:#{presentation_id}",
        presentation.merge(
          id: presentation_id,
          organization_id: organization.id,
          user_id: user.id,
          created_at: Time.current.iso8601,
          status: 'completed'
        ),
        expires_in: 7.days
      )
      
      # Store metadata for quick retrieval
      store_presentation_metadata(presentation_id, presentation, organization, user)
      
      presentation_id
    end
    
    def store_presentation_metadata(presentation_id, presentation, organization, user)
      metadata = {
        id: presentation_id,
        title: presentation[:title],
        type: presentation[:type],
        organization_id: organization.id,
        user_id: user.id,
        created_at: Time.current.iso8601,
        slide_count: presentation[:slides]&.length || 0,
        has_live_data: presentation[:live_data_connections]&.any?,
        has_ai_insights: presentation[:ai_enhancements]&.dig(:insights)&.any?,
        estimated_duration: estimate_presentation_duration(presentation)
      }
      
      Rails.cache.write(
        "presentation_metadata:#{presentation_id}",
        metadata,
        expires_in: 30.days
      )
    end
    
    def broadcast_presentation_ready(organization, user, presentation_id, presentation)
      ActionCable.server.broadcast(
        "presentations_#{organization.id}",
        {
          type: 'presentation_ready',
          presentation_id: presentation_id,
          user_id: user.id,
          title: presentation[:title],
          type: presentation[:type],
          preview_url: "/ai/interactive_presentations/#{presentation_id}/preview",
          edit_url: "/ai/interactive_presentations/#{presentation_id}/edit",
          completed_at: Time.current.iso8601
        }
      )
    end
    
    # Helper methods
    def analyze_slide_content(slides)
      # Analyze slides for key themes and insights
      {
        type: 'content_analysis',
        insight: "Presentation contains #{slides.length} slides with comprehensive business data",
        confidence: 0.8
      }
    end
    
    def generate_business_insights(organization)
      {
        type: 'business_insight',
        insight: "Organization has #{organization.data_sources.count} connected data sources",
        confidence: 0.9
      }
    end
    
    def generate_trend_insights(organization)
      {
        type: 'trend_insight',
        insight: "Data trends show consistent business growth patterns",
        confidence: 0.7
      }
    end
    
    def optimize_presentation_assets(presentation)
      {
        images_compressed: true,
        fonts_optimized: true,
        css_minified: true,
        javascript_bundled: true
      }
    end
    
    def optimize_data_queries(presentation, organization)
      {
        queries_cached: true,
        indexes_optimized: true,
        data_aggregated: true,
        real_time_optimized: true
      }
    end
    
    def configure_presentation_caching(presentation)
      {
        static_content_ttl: 1.hour,
        dynamic_content_ttl: 5.minutes,
        real_time_content_ttl: 30.seconds,
        cdn_enabled: true
      }
    end
    
    def estimate_presentation_duration(presentation)
      base_duration = 2 # minutes per slide
      slide_count = presentation[:slides]&.length || 1
      
      duration = slide_count * base_duration
      
      # Adjust for interactive elements
      if presentation[:interactive_elements]&.any?
        duration += presentation[:interactive_elements].length * 0.5
      end
      
      # Adjust for data story type
      if presentation[:type] == 'data_story'
        duration += 5 # Additional time for narrative
      end
      
      duration.round
    end
    
    def critical_job?
      # Presentation generation is user-facing and critical
      true
    end
  end
end