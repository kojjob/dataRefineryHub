# frozen_string_literal: true

module Ai
  module SpecializedAgents
    class BaseAgent
      attr_reader :organization, :focus_area, :configuration

      def initialize(organization, configuration = {})
        @organization = organization
        @configuration = default_configuration.merge(configuration)
        @focus_area = self.class.name.demodulize.gsub("Agent", "").downcase
      end

      def analyze(context = {})
        raise NotImplementedError, "Subclasses must implement analyze method"
      end

      def generate_insights(data, context = {})
        insights = []

        # Perform domain-specific analysis
        analysis_results = perform_analysis(data, context)

        # Convert analysis to insights
        analysis_results.each do |result|
          insight = build_insight(result)
          insights << insight if insight.valid?
        end

        # Prioritize insights
        prioritize_insights(insights)
      end

      def collaborate_with(other_agent, shared_context = {})
        # Share relevant insights with another agent
        my_insights = recent_insights

        # Get insights from other agent with shared context
        other_insights = other_agent.analyze(
          shared_context.merge(
            collaborating_agent: self.class.name,
            shared_insights: my_insights
          )
        )

        # Synthesize collaborative insights
        synthesize_collaborative_insights(my_insights, other_insights)
      end

      def learn_from_feedback(insight_id, feedback)
        insight = organization.ai_insights.find(insight_id)

        # Update learning data based on feedback
        update_learning_data(insight, feedback)

        # Adjust confidence thresholds
        adjust_confidence_levels(feedback)

        # Save configuration
        save_configuration
      end

      def get_capabilities
        {
          name: self.class.name.demodulize,
          focus_area: focus_area,
          capabilities: specific_capabilities,
          required_data: required_data_sources,
          output_types: supported_output_types,
          integration_points: integration_points
        }
      end

      def health_check
        {
          status: agent_status,
          last_analysis: last_analysis_time,
          insights_generated_today: today_insights_count,
          accuracy_score: calculate_accuracy_score,
          data_freshness: check_data_freshness,
          errors: recent_errors
        }
      end

      protected

      def default_configuration
        {
          enabled: true,
          confidence_threshold: 0.7,
          analysis_frequency: 1.hour,
          max_insights_per_run: 10,
          learning_rate: 0.1,
          priority_weights: {
            impact: 0.4,
            confidence: 0.3,
            urgency: 0.3
          }
        }
      end

      def perform_analysis(data, context)
        # Implemented by subclasses
        []
      end

      def build_insight(analysis_result)
        Ai::Insight.new(
          organization: organization,
          insight_type: detect_insight_type(analysis_result),
          title: generate_title(analysis_result),
          description: generate_description(analysis_result),
          confidence_score: calculate_confidence(analysis_result),
          impact_level: assess_impact(analysis_result),
          actionable: is_actionable?(analysis_result),
          metadata: build_metadata(analysis_result),
          recommendations: generate_recommendations(analysis_result),
          source: "#{self.class.name}",
          expires_at: calculate_expiry(analysis_result)
        )
      end

      def prioritize_insights(insights)
        insights.sort_by do |insight|
          # Calculate priority score
          impact_weight = configuration[:priority_weights][:impact]
          confidence_weight = configuration[:priority_weights][:confidence]
          urgency_weight = configuration[:priority_weights][:urgency]

          impact_score = impact_to_score(insight.impact_level)
          urgency_score = calculate_urgency_score(insight)

          -(
            (impact_score * impact_weight) +
            (insight.confidence_score * confidence_weight) +
            (urgency_score * urgency_weight)
          )
        end
      end

      def recent_insights
        organization.ai_insights
                    .where(source: self.class.name)
                    .where("created_at > ?", 24.hours.ago)
                    .order(created_at: :desc)
                    .limit(10)
      end

      def synthesize_collaborative_insights(my_insights, other_insights)
        # Look for patterns across insights
        collaborative_insights = []

        my_insights.each do |my_insight|
          related = find_related_insights(my_insight, other_insights)

          if related.any?
            combined_insight = create_combined_insight(my_insight, related)
            collaborative_insights << combined_insight
          end
        end

        collaborative_insights
      end

      def update_learning_data(insight, feedback)
        @learning_data ||= load_learning_data

        # Track prediction accuracy
        prediction_key = "#{insight.insight_type}_#{insight.metadata['prediction_type']}"
        @learning_data[prediction_key] ||= { correct: 0, total: 0 }

        @learning_data[prediction_key][:total] += 1
        @learning_data[prediction_key][:correct] += 1 if feedback[:accurate]

        # Save learning data
        save_learning_data(@learning_data)
      end

      def adjust_confidence_levels(feedback)
        return unless feedback[:confidence_adjustment]

        adjustment = feedback[:confidence_adjustment] * configuration[:learning_rate]
        configuration[:confidence_threshold] += adjustment
        configuration[:confidence_threshold] = configuration[:confidence_threshold].clamp(0.5, 0.95)
      end

      def save_configuration
        agent_config = Ai::AgentConfiguration.find_or_create_by(
          organization: organization,
          agent_type: self.class.name
        )

        agent_config.update!(
          settings: configuration,
          updated_at: Time.current
        )
      end

      def agent_status
        last_run = last_analysis_time

        if last_run.nil?
          :not_started
        elsif last_run < 1.hour.ago
          :idle
        elsif recent_errors.any?
          :degraded
        else
          :healthy
        end
      end

      def last_analysis_time
        organization.ai_insights
                    .where(source: self.class.name)
                    .maximum(:created_at)
      end

      def today_insights_count
        organization.ai_insights
                    .where(source: self.class.name)
                    .where("created_at > ?", Time.current.beginning_of_day)
                    .count
      end

      def calculate_accuracy_score
        learning_data = load_learning_data

        total_predictions = learning_data.values.sum { |v| v[:total] || 0 }
        correct_predictions = learning_data.values.sum { |v| v[:correct] || 0 }

        return 1.0 if total_predictions == 0

        (correct_predictions.to_f / total_predictions).round(2)
      end

      def check_data_freshness
        # Implemented by subclasses based on their data requirements
        :fresh
      end

      def recent_errors
        # Would track errors in production
        []
      end

      def load_learning_data
        agent_config = Ai::AgentConfiguration.find_by(
          organization: organization,
          agent_type: self.class.name
        )

        agent_config&.learning_data || {}
      end

      def save_learning_data(data)
        agent_config = Ai::AgentConfiguration.find_or_create_by(
          organization: organization,
          agent_type: self.class.name
        )

        agent_config.update!(learning_data: data)
      end

      # Helper methods
      def impact_to_score(impact_level)
        case impact_level
        when "critical" then 1.0
        when "high" then 0.8
        when "medium" then 0.5
        when "low" then 0.2
        else 0.1
        end
      end

      def calculate_urgency_score(insight)
        # Base urgency on time sensitivity
        if insight.expires_at.present?
          hours_until_expiry = (insight.expires_at - Time.current) / 1.hour

          if hours_until_expiry < 1
            1.0
          elsif hours_until_expiry < 24
            0.8
          elsif hours_until_expiry < 72
            0.5
          else
            0.2
          end
        else
          0.3 # Default urgency for non-expiring insights
        end
      end

      def find_related_insights(insight, other_insights)
        other_insights.select do |other|
          # Look for overlapping entities or topics
          insight_entities = insight.metadata["entities"] || []
          other_entities = other.metadata["entities"] || []

          (insight_entities & other_entities).any?
        end
      end

      def create_combined_insight(primary_insight, related_insights)
        Ai::Insight.new(
          organization: organization,
          insight_type: "cross_functional",
          title: "Multi-dimensional insight: #{primary_insight.title}",
          description: build_combined_description(primary_insight, related_insights),
          confidence_score: calculate_combined_confidence(primary_insight, related_insights),
          impact_level: "high",
          actionable: true,
          metadata: {
            primary_insight_id: primary_insight.id,
            related_insight_ids: related_insights.map(&:id),
            contributing_agents: ([ primary_insight.source ] + related_insights.map(&:source)).uniq
          },
          recommendations: merge_recommendations(primary_insight, related_insights),
          source: "AgentCollaboration"
        )
      end

      def build_combined_description(primary, related)
        base = primary.description

        related.each do |insight|
          base += " Additionally, #{insight.source} analysis shows: #{insight.description}"
        end

        base
      end

      def calculate_combined_confidence(primary, related)
        all_scores = [ primary.confidence_score ] + related.map(&:confidence_score)
        all_scores.sum / all_scores.size.to_f
      end

      def merge_recommendations(primary, related)
        all_recommendations = primary.recommendations || []

        related.each do |insight|
          all_recommendations += (insight.recommendations || [])
        end

        # Remove duplicates and prioritize
        all_recommendations.uniq.first(5)
      end

      # Abstract methods for subclasses
      def specific_capabilities
        raise NotImplementedError
      end

      def required_data_sources
        raise NotImplementedError
      end

      def supported_output_types
        raise NotImplementedError
      end

      def integration_points
        raise NotImplementedError
      end

      def detect_insight_type(analysis_result)
        "general"
      end

      def generate_title(analysis_result)
        "Insight from #{focus_area} analysis"
      end

      def generate_description(analysis_result)
        "Analysis revealed: #{analysis_result[:summary]}"
      end

      def calculate_confidence(analysis_result)
        analysis_result[:confidence] || 0.75
      end

      def assess_impact(analysis_result)
        analysis_result[:impact] || "medium"
      end

      def is_actionable?(analysis_result)
        analysis_result[:actionable] != false
      end

      def build_metadata(analysis_result)
        analysis_result[:metadata] || {}
      end

      def generate_recommendations(analysis_result)
        analysis_result[:recommendations] || []
      end

      def calculate_expiry(analysis_result)
        if analysis_result[:time_sensitive]
          Time.current + 24.hours
        else
          nil
        end
      end
    end
  end
end
