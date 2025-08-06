# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../app/domain/pipeline_management/value_objects/schedule'

RSpec.describe Domain::PipelineManagement::ValueObjects::Schedule do
  describe '#initialize' do
    context 'with valid attributes' do
      it 'creates a cron schedule' do
        schedule = described_class.new(
          type: 'cron',
          expression: '0 */6 * * *',
          timezone: 'America/New_York'
        )

        expect(schedule.type).to eq('cron')
        expect(schedule.expression).to eq('0 */6 * * *')
        expect(schedule.timezone).to eq('America/New_York')
      end

      it 'creates an interval schedule' do
        schedule = described_class.new(
          type: 'interval',
          expression: '30',
          timezone: 'UTC'
        )

        expect(schedule.type).to eq('interval')
        expect(schedule.expression).to eq('30')
      end

      it 'creates a daily schedule' do
        schedule = described_class.new(
          type: 'daily',
          expression: '14:30',
          timezone: 'Europe/London'
        )

        expect(schedule.type).to eq('daily')
        expect(schedule.expression).to eq('14:30')
      end
    end

    context 'with invalid attributes' do
      it 'raises error for invalid type' do
        expect {
          described_class.new(
            type: 'invalid',
            expression: 'test'
          )
        }.to raise_error(ActiveModel::ValidationError)
      end

      it 'raises error for missing expression' do
        expect {
          described_class.new(
            type: 'daily',
            expression: nil
          )
        }.to raise_error(ActiveModel::ValidationError)
      end

      it 'raises error for invalid cron expression' do
        expect {
          described_class.new(
            type: 'cron',
            expression: 'invalid cron'
          )
        }.to raise_error(ActiveModel::ValidationError)
      end
    end
  end

  describe '#next_run_time' do
    let(:base_time) { Time.parse('2024-01-15 10:00:00 UTC') }

    context 'with cron schedule' do
      let(:schedule) do
        described_class.new(
          type: 'cron',
          expression: '0 */6 * * *', # Every 6 hours
          timezone: 'UTC'
        )
      end

      it 'calculates next run time' do
        next_time = schedule.next_run_time(from: base_time)
        expect(next_time).to eq(Time.parse('2024-01-15 12:00:00 UTC'))
      end
    end

    context 'with interval schedule' do
      let(:schedule) do
        described_class.new(
          type: 'interval',
          expression: '30', # 30 minutes
          timezone: 'UTC'
        )
      end

      it 'calculates next run time' do
        next_time = schedule.next_run_time(from: base_time)
        expect(next_time).to eq(base_time + 30.minutes)
      end
    end

    context 'with daily schedule' do
      let(:schedule) do
        described_class.new(
          type: 'daily',
          expression: '14:30',
          timezone: 'UTC'
        )
      end

      it 'calculates next run time for same day' do
        next_time = schedule.next_run_time(from: base_time)
        expect(next_time).to eq(Time.parse('2024-01-15 14:30:00 UTC'))
      end

      it 'calculates next run time for next day' do
        evening_time = Time.parse('2024-01-15 20:00:00 UTC')
        next_time = schedule.next_run_time(from: evening_time)
        expect(next_time).to eq(Time.parse('2024-01-16 14:30:00 UTC'))
      end
    end
  end

  describe '#to_h' do
    let(:schedule) do
      described_class.new(
        type: 'cron',
        expression: '0 0 * * *',
        timezone: 'UTC'
      )
    end

    it 'returns hash representation' do
      expect(schedule.to_h).to eq({
        type: 'cron',
        expression: '0 0 * * *',
        timezone: 'UTC'
      })
    end
  end

  describe '#==' do
    let(:schedule1) do
      described_class.new(
        type: 'daily',
        expression: '10:00',
        timezone: 'UTC'
      )
    end

    it 'returns true for equal schedules' do
      schedule2 = described_class.new(
        type: 'daily',
        expression: '10:00',
        timezone: 'UTC'
      )

      expect(schedule1).to eq(schedule2)
    end

    it 'returns false for different schedules' do
      schedule2 = described_class.new(
        type: 'daily',
        expression: '11:00',
        timezone: 'UTC'
      )

      expect(schedule1).not_to eq(schedule2)
    end

    it 'returns false for different types' do
      expect(schedule1).not_to eq('not a schedule')
    end
  end

  describe '#valid_for_scheduling?' do
    it 'returns true for active schedule' do
      schedule = described_class.new(
        type: 'cron',
        expression: '0 0 * * *',
        timezone: 'UTC'
      )

      expect(schedule.valid_for_scheduling?).to be true
    end

    it 'handles timezone conversions' do
      schedule = described_class.new(
        type: 'daily',
        expression: '10:00',
        timezone: 'America/New_York'
      )

      utc_time = Time.parse('2024-01-15 15:00:00 UTC') # 10:00 EST
      next_time = schedule.next_run_time(from: utc_time)

      expect(next_time.in_time_zone('America/New_York').hour).to eq(10)
    end
  end
end
