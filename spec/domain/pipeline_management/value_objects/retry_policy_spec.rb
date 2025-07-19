# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../app/domain/pipeline_management/value_objects/retry_policy'

RSpec.describe Domain::PipelineManagement::ValueObjects::RetryPolicy do
  describe '#initialize' do
    context 'with valid attributes' do
      it 'creates a retry policy with defaults' do
        policy = described_class.new

        expect(policy.max_attempts).to eq(3)
        expect(policy.backoff_strategy).to eq('exponential')
        expect(policy.backoff_seconds).to eq(60)
        expect(policy.max_backoff_seconds).to eq(3600)
      end

      it 'creates a retry policy with custom values' do
        policy = described_class.new(
          max_attempts: 5,
          backoff_strategy: 'linear',
          backoff_seconds: 30,
          max_backoff_seconds: 1800
        )

        expect(policy.max_attempts).to eq(5)
        expect(policy.backoff_strategy).to eq('linear')
        expect(policy.backoff_seconds).to eq(30)
        expect(policy.max_backoff_seconds).to eq(1800)
      end
    end

    context 'with invalid attributes' do
      it 'raises error for invalid max_attempts' do
        expect {
          described_class.new(max_attempts: 0)
        }.to raise_error(ActiveModel::ValidationError)

        expect {
          described_class.new(max_attempts: 11)
        }.to raise_error(ActiveModel::ValidationError)
      end

      it 'raises error for invalid backoff_strategy' do
        expect {
          described_class.new(backoff_strategy: 'random')
        }.to raise_error(ActiveModel::ValidationError)
      end

      it 'raises error for invalid backoff_seconds' do
        expect {
          described_class.new(backoff_seconds: 0)
        }.to raise_error(ActiveModel::ValidationError)
      end
    end
  end

  describe '#calculate_delay' do
    context 'with exponential backoff' do
      let(:policy) do
        described_class.new(
          backoff_strategy: 'exponential',
          backoff_seconds: 10,
          max_backoff_seconds: 1000
        )
      end

      it 'calculates exponential delays' do
        expect(policy.calculate_delay(1)).to eq(10)   # 10 * 2^0
        expect(policy.calculate_delay(2)).to eq(20)   # 10 * 2^1
        expect(policy.calculate_delay(3)).to eq(40)   # 10 * 2^2
        expect(policy.calculate_delay(4)).to eq(80)   # 10 * 2^3
        expect(policy.calculate_delay(5)).to eq(160)  # 10 * 2^4
      end

      it 'caps delay at max_backoff_seconds' do
        expect(policy.calculate_delay(10)).to eq(1000) # Would be 5120, but capped
      end
    end

    context 'with linear backoff' do
      let(:policy) do
        described_class.new(
          backoff_strategy: 'linear',
          backoff_seconds: 30
        )
      end

      it 'calculates linear delays' do
        expect(policy.calculate_delay(1)).to eq(30)   # 30 * 1
        expect(policy.calculate_delay(2)).to eq(60)   # 30 * 2
        expect(policy.calculate_delay(3)).to eq(90)   # 30 * 3
        expect(policy.calculate_delay(4)).to eq(120)  # 30 * 4
      end
    end

    context 'with constant backoff' do
      let(:policy) do
        described_class.new(
          backoff_strategy: 'constant',
          backoff_seconds: 45
        )
      end

      it 'returns constant delay' do
        expect(policy.calculate_delay(1)).to eq(45)
        expect(policy.calculate_delay(2)).to eq(45)
        expect(policy.calculate_delay(3)).to eq(45)
        expect(policy.calculate_delay(10)).to eq(45)
      end
    end

    context 'with invalid attempt number' do
      let(:policy) { described_class.new }

      it 'returns 0 for attempt 0 or negative' do
        expect(policy.calculate_delay(0)).to eq(0)
        expect(policy.calculate_delay(-1)).to eq(0)
      end
    end
  end

  describe '#to_h' do
    let(:policy) do
      described_class.new(
        max_attempts: 5,
        backoff_strategy: 'linear',
        backoff_seconds: 30,
        max_backoff_seconds: 1800
      )
    end

    it 'returns hash representation' do
      expect(policy.to_h).to eq({
        max_attempts: 5,
        backoff_strategy: 'linear',
        backoff_seconds: 30,
        max_backoff_seconds: 1800
      })
    end
  end

  describe '#==' do
    let(:policy1) do
      described_class.new(
        max_attempts: 3,
        backoff_strategy: 'exponential',
        backoff_seconds: 60
      )
    end

    it 'returns true for equal policies' do
      policy2 = described_class.new(
        max_attempts: 3,
        backoff_strategy: 'exponential',
        backoff_seconds: 60
      )

      expect(policy1).to eq(policy2)
    end

    it 'returns false for different policies' do
      policy2 = described_class.new(
        max_attempts: 5,
        backoff_strategy: 'exponential',
        backoff_seconds: 60
      )

      expect(policy1).not_to eq(policy2)
    end

    it 'returns false for different types' do
      expect(policy1).not_to eq('not a policy')
    end
  end

  describe '#should_retry?' do
    let(:policy) { described_class.new(max_attempts: 3) }

    it 'returns true when attempts are below max' do
      expect(policy.should_retry?(1)).to be true
      expect(policy.should_retry?(2)).to be true
    end

    it 'returns false when attempts reach max' do
      expect(policy.should_retry?(3)).to be false
      expect(policy.should_retry?(4)).to be false
    end
  end
end
