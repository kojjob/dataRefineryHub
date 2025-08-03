# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../app/domain/pipeline_management/value_objects/retry_policy'

RSpec.describe Domain::PipelineManagement::ValueObjects::RetryPolicy do
  describe '#initialize' do
    context 'with valid attributes' do
      it 'creates a retry policy with default values' do
        policy = described_class.new(max_attempts: 3)

        expect(policy.max_attempts).to eq(3)
        expect(policy.backoff_strategy).to eq('exponential')
        expect(policy.initial_delay).to eq(60)
        expect(policy.max_delay).to eq(3600)
        expect(policy.multiplier).to eq(2.0)
      end

      it 'creates a retry policy with custom values' do
        policy = described_class.new(
          max_attempts: 5,
          backoff_strategy: 'linear',
          initial_delay: 30,
          max_delay: 1800,
          multiplier: 3
        )

        expect(policy.max_attempts).to eq(5)
        expect(policy.backoff_strategy).to eq('linear')
        expect(policy.initial_delay).to eq(30)
        expect(policy.max_delay).to eq(1800)
        expect(policy.multiplier).to eq(3.0)
      end

      it 'accepts all valid backoff strategies' do
        %w[constant linear exponential fibonacci].each do |strategy|
          policy = described_class.new(
            max_attempts: 3,
            backoff_strategy: strategy
          )
          expect(policy.backoff_strategy).to eq(strategy)
        end
      end
    end

    context 'with invalid attributes' do
      it 'raises error for zero max_attempts' do
        expect {
          described_class.new(max_attempts: 0)
        }.to raise_error(ActiveModel::ValidationError)
      end

      it 'raises error for negative max_attempts' do
        expect {
          described_class.new(max_attempts: -1)
        }.to raise_error(ActiveModel::ValidationError)
      end

      it 'raises error for too many max_attempts' do
        expect {
          described_class.new(max_attempts: 11)
        }.to raise_error(ActiveModel::ValidationError)
      end

      it 'raises error for invalid backoff strategy' do
        expect {
          described_class.new(
            max_attempts: 3,
            backoff_strategy: 'invalid'
          )
        }.to raise_error(ActiveModel::ValidationError)
      end

      it 'raises error when initial_delay exceeds max_delay' do
        expect {
          described_class.new(
            max_attempts: 3,
            initial_delay: 5000,
            max_delay: 1000
          )
        }.to raise_error(ActiveModel::ValidationError)
      end

      it 'raises error for invalid multiplier with exponential backoff' do
        expect {
          described_class.new(
            max_attempts: 3,
            backoff_strategy: 'exponential',
            multiplier: 1
          )
        }.to raise_error(ActiveModel::ValidationError)
      end
    end
  end

  describe '#delay_for_attempt' do
    context 'with constant backoff' do
      let(:policy) do
        described_class.new(
          max_attempts: 5,
          backoff_strategy: 'constant',
          initial_delay: 100
        )
      end

      it 'returns the same delay for all attempts' do
        expect(policy.delay_for_attempt(1)).to eq(100)
        expect(policy.delay_for_attempt(2)).to eq(100)
        expect(policy.delay_for_attempt(3)).to eq(100)
        expect(policy.delay_for_attempt(5)).to eq(100)
      end
    end

    context 'with linear backoff' do
      let(:policy) do
        described_class.new(
          max_attempts: 5,
          backoff_strategy: 'linear',
          initial_delay: 100
        )
      end

      it 'increases delay linearly' do
        expect(policy.delay_for_attempt(1)).to eq(100)
        expect(policy.delay_for_attempt(2)).to eq(200)
        expect(policy.delay_for_attempt(3)).to eq(300)
        expect(policy.delay_for_attempt(5)).to eq(500)
      end
    end

    context 'with exponential backoff' do
      let(:policy) do
        described_class.new(
          max_attempts: 5,
          backoff_strategy: 'exponential',
          initial_delay: 100,
          multiplier: 2
        )
      end

      it 'increases delay exponentially' do
        expect(policy.delay_for_attempt(1)).to eq(100)
        expect(policy.delay_for_attempt(2)).to eq(200)
        expect(policy.delay_for_attempt(3)).to eq(400)
        expect(policy.delay_for_attempt(4)).to eq(800)
        expect(policy.delay_for_attempt(5)).to eq(1600)
      end
    end

    context 'with fibonacci backoff' do
      let(:policy) do
        described_class.new(
          max_attempts: 6,
          backoff_strategy: 'fibonacci',
          initial_delay: 100
        )
      end

      it 'follows fibonacci sequence' do
        expect(policy.delay_for_attempt(1)).to eq(100)  # 1 * 100
        expect(policy.delay_for_attempt(2)).to eq(200)  # 2 * 100
        expect(policy.delay_for_attempt(3)).to eq(300)  # 3 * 100
        expect(policy.delay_for_attempt(4)).to eq(500)  # 5 * 100
        expect(policy.delay_for_attempt(5)).to eq(800)  # 8 * 100
        expect(policy.delay_for_attempt(6)).to eq(1300) # 13 * 100
      end
    end

    context 'with max_delay limit' do
      let(:policy) do
        described_class.new(
          max_attempts: 5,
          backoff_strategy: 'exponential',
          initial_delay: 100,
          max_delay: 500,
          multiplier: 3
        )
      end

      it 'caps delay at max_delay' do
        expect(policy.delay_for_attempt(1)).to eq(100)
        expect(policy.delay_for_attempt(2)).to eq(300)
        expect(policy.delay_for_attempt(3)).to eq(500) # Would be 900, capped at 500
        expect(policy.delay_for_attempt(4)).to eq(500) # Would be 2700, capped at 500
      end
    end

    context 'with invalid attempt numbers' do
      let(:policy) { described_class.new(max_attempts: 3) }

      it 'returns nil for attempts beyond max_attempts' do
        expect(policy.delay_for_attempt(4)).to be_nil
        expect(policy.delay_for_attempt(10)).to be_nil
      end

      it 'returns 0 for non-positive attempts' do
        expect(policy.delay_for_attempt(0)).to eq(0)
        expect(policy.delay_for_attempt(-1)).to eq(0)
      end
    end
  end

  describe '#should_retry?' do
    let(:policy) { described_class.new(max_attempts: 3) }

    context 'based on attempt number' do
      it 'returns true when attempts remain' do
        expect(policy.should_retry?(0)).to be true
        expect(policy.should_retry?(1)).to be true
        expect(policy.should_retry?(2)).to be true
      end

      it 'returns false when max attempts reached' do
        expect(policy.should_retry?(3)).to be false
        expect(policy.should_retry?(4)).to be false
      end
    end

    context 'with error handling' do
      it 'returns false for authentication errors' do
        expect(policy.should_retry?(1, 'Authentication failed')).to be false
        expect(policy.should_retry?(1, 'Invalid credentials')).to be false
        expect(policy.should_retry?(1, 'Authorization error')).to be false
      end

      it 'returns false for non-retryable exceptions' do
        error = ArgumentError.new('Invalid argument')
        expect(policy.should_retry?(1, error)).to be false

        error = NoMethodError.new('Method not found')
        expect(policy.should_retry?(1, error)).to be false
      end

      it 'returns true for retryable errors' do
        expect(policy.should_retry?(1, 'Connection timeout')).to be true
        expect(policy.should_retry?(1, 'Server error')).to be true
        expect(policy.should_retry?(1, RuntimeError.new('Temporary failure'))).to be true
      end
    end
  end

  describe '#exhausted?' do
    let(:policy) { described_class.new(max_attempts: 3) }

    it 'returns false when attempts remain' do
      expect(policy.exhausted?(0)).to be false
      expect(policy.exhausted?(1)).to be false
      expect(policy.exhausted?(2)).to be false
    end

    it 'returns true when max attempts reached' do
      expect(policy.exhausted?(3)).to be true
      expect(policy.exhausted?(4)).to be true
    end
  end

  describe '#to_h' do
    let(:policy) do
      described_class.new(
        max_attempts: 5,
        backoff_strategy: 'linear',
        initial_delay: 30,
        max_delay: 1800,
        multiplier: 3
      )
    end

    it 'returns hash representation' do
      expect(policy.to_h).to eq({
        max_attempts: 5,
        backoff_strategy: 'linear',
        initial_delay: 30,
        max_delay: 1800,
        multiplier: 3.0
      })
    end
  end

  describe '#==' do
    let(:policy1) do
      described_class.new(
        max_attempts: 3,
        backoff_strategy: 'exponential',
        initial_delay: 60
      )
    end

    it 'returns true for equal policies' do
      policy2 = described_class.new(
        max_attempts: 3,
        backoff_strategy: 'exponential',
        initial_delay: 60
      )

      expect(policy1).to eq(policy2)
    end

    it 'returns false for different max_attempts' do
      policy2 = described_class.new(
        max_attempts: 5,
        backoff_strategy: 'exponential',
        initial_delay: 60
      )

      expect(policy1).not_to eq(policy2)
    end

    it 'returns false for different strategies' do
      policy2 = described_class.new(
        max_attempts: 3,
        backoff_strategy: 'linear',
        initial_delay: 60
      )

      expect(policy1).not_to eq(policy2)
    end

    it 'returns false for different types' do
      expect(policy1).not_to eq('not a retry policy')
      expect(policy1).not_to eq(nil)
    end
  end

  describe 'real-world scenarios' do
    it 'handles database connection retry scenario' do
      policy = described_class.new(
        max_attempts: 5,
        backoff_strategy: 'exponential',
        initial_delay: 1,
        max_delay: 30,
        multiplier: 2
      )

      delays = (1..5).map { |i| policy.delay_for_attempt(i) }
      expect(delays).to eq([1, 2, 4, 8, 16])
    end

    it 'handles API rate limit scenario' do
      policy = described_class.new(
        max_attempts: 3,
        backoff_strategy: 'fibonacci',
        initial_delay: 60,
        max_delay: 300
      )

      expect(policy.delay_for_attempt(1)).to eq(60)
      expect(policy.delay_for_attempt(2)).to eq(120)
      expect(policy.delay_for_attempt(3)).to eq(180)
    end

    it 'handles quick retry scenario' do
      policy = described_class.new(
        max_attempts: 10,
        backoff_strategy: 'constant',
        initial_delay: 5
      )

      (1..10).each do |attempt|
        expect(policy.delay_for_attempt(attempt)).to eq(5)
      end
    end
  end
end