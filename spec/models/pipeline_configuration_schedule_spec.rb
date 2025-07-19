# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PipelineConfiguration, 'Schedule integration' do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:pipeline) do
    create(:pipeline_configuration,
           organization: organization,
           created_by: user)
  end

  describe '#schedule' do
    context 'when schedule fields are present' do
      before do
        pipeline.update!(
          schedule_type: 'daily',
          schedule_expression: '10:00',
          schedule_timezone: 'UTC'
        )
      end

      it 'returns a Schedule value object' do
        expect(pipeline.schedule).to be_a(Domain::PipelineManagement::ValueObjects::Schedule)
        expect(pipeline.schedule.type).to eq('daily')
        expect(pipeline.schedule.expression).to eq('10:00')
        expect(pipeline.schedule.timezone).to eq('UTC')
      end

      it 'memoizes the schedule object' do
        schedule1 = pipeline.schedule
        schedule2 = pipeline.schedule
        expect(schedule1).to be(schedule2) # Same object instance
      end
    end

    context 'when schedule fields are not present' do
      it 'returns nil' do
        expect(pipeline.schedule).to be_nil
      end
    end

    context 'when schedule fields are invalid' do
      before do
        pipeline.update_columns(
          schedule_type: 'cron',
          schedule_expression: 'invalid cron',
          schedule_timezone: 'UTC'
        )
      end

      it 'returns nil' do
        expect(pipeline.schedule).to be_nil
      end
    end
  end

  describe '#schedule=' do
    let(:schedule) do
      Domain::PipelineManagement::ValueObjects::Schedule.new(
        type: 'interval',
        expression: '30',
        timezone: 'America/New_York'
      )
    end

    it 'sets the schedule fields from value object' do
      pipeline.schedule = schedule
      
      expect(pipeline.schedule_type).to eq('interval')
      expect(pipeline.schedule_expression).to eq('30')
      expect(pipeline.schedule_timezone).to eq('America/New_York')
    end

    it 'clears schedule fields when set to nil' do
      pipeline.update!(
        schedule_type: 'daily',
        schedule_expression: '10:00',
        schedule_timezone: 'UTC'
      )
      
      pipeline.schedule = nil
      
      expect(pipeline.schedule_type).to be_nil
      expect(pipeline.schedule_expression).to be_nil
      expect(pipeline.schedule_timezone).to be_nil
    end
  end

  describe '#scheduled?' do
    it 'returns true when schedule is present' do
      pipeline.update!(
        schedule_type: 'daily',
        schedule_expression: '10:00'
      )
      
      expect(pipeline).to be_scheduled
    end

    it 'returns false when schedule is not present' do
      expect(pipeline).not_to be_scheduled
    end
  end

  describe '#next_scheduled_run' do
    context 'with daily schedule' do
      before do
        pipeline.update!(
          schedule_type: 'daily',
          schedule_expression: '14:30',
          schedule_timezone: 'UTC',
          last_executed_at: Time.parse('2024-01-15 10:00:00 UTC')
        )
      end

      it 'calculates next run time correctly' do
        next_run = pipeline.next_scheduled_run
        expect(next_run).to eq(Time.parse('2024-01-15 14:30:00 UTC'))
      end
    end

    context 'without schedule' do
      it 'returns nil' do
        expect(pipeline.next_scheduled_run).to be_nil
      end
    end
  end
end
