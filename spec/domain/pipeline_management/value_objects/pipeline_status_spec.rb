# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Domain::PipelineManagement::ValueObjects::PipelineStatus do
  describe '#initialize' do
    it 'creates a status with required value' do
      status = described_class.new(value: 'active')
      
      expect(status.value).to eq('active')
      expect(status.changed_at).to be_within(1.second).of(Time.current)
      expect(status.changed_by).to be_nil
      expect(status.reason).to be_nil
    end

    it 'creates a status with all attributes' do
      user = 'user@example.com'
      time = 1.hour.ago
      status = described_class.new(
        value: 'paused',
        changed_at: time,
        changed_by: user,
        reason: 'Maintenance window'
      )
      
      expect(status.value).to eq('paused')
      expect(status.changed_at).to eq(time)
      expect(status.changed_by).to eq(user)
      expect(status.reason).to eq('Maintenance window')
    end

    it 'raises error for invalid status value' do
      expect {
        described_class.new(value: 'invalid')
      }.to raise_error(ArgumentError, 'Invalid status: invalid')
    end
  end

  describe 'status query methods' do
    it 'correctly identifies draft status' do
      status = described_class.new(value: 'draft')
      
      expect(status.draft?).to be true
      expect(status.active?).to be false
      expect(status.paused?).to be false
      expect(status.archived?).to be false
    end

    it 'correctly identifies active status' do
      status = described_class.new(value: 'active')
      
      expect(status.draft?).to be false
      expect(status.active?).to be true
      expect(status.paused?).to be false
      expect(status.archived?).to be false
    end

    it 'correctly identifies paused status' do
      status = described_class.new(value: 'paused')
      
      expect(status.draft?).to be false
      expect(status.active?).to be false
      expect(status.paused?).to be true
      expect(status.archived?).to be false
    end

    it 'correctly identifies archived status' do
      status = described_class.new(value: 'archived')
      
      expect(status.draft?).to be false
      expect(status.active?).to be false
      expect(status.paused?).to be false
      expect(status.archived?).to be true
    end
  end

  describe '#can_transition_to?' do
    context 'from draft' do
      let(:status) { described_class.new(value: 'draft') }

      it 'can transition to active' do
        expect(status.can_transition_to?('active')).to be true
      end

      it 'can transition to archived' do
        expect(status.can_transition_to?('archived')).to be true
      end

      it 'cannot transition to paused' do
        expect(status.can_transition_to?('paused')).to be false
      end

      it 'cannot transition to same status' do
        expect(status.can_transition_to?('draft')).to be false
      end
    end

    context 'from active' do
      let(:status) { described_class.new(value: 'active') }

      it 'can transition to paused' do
        expect(status.can_transition_to?('paused')).to be true
      end

      it 'can transition to archived' do
        expect(status.can_transition_to?('archived')).to be true
      end

      it 'cannot transition to draft' do
        expect(status.can_transition_to?('draft')).to be false
      end
    end

    context 'from paused' do
      let(:status) { described_class.new(value: 'paused') }

      it 'can transition to active' do
        expect(status.can_transition_to?('active')).to be true
      end

      it 'can transition to archived' do
        expect(status.can_transition_to?('archived')).to be true
      end

      it 'cannot transition to draft' do
        expect(status.can_transition_to?('draft')).to be false
      end
    end

    context 'from archived' do
      let(:status) { described_class.new(value: 'archived') }

      it 'cannot transition to any status' do
        expect(status.can_transition_to?('draft')).to be false
        expect(status.can_transition_to?('active')).to be false
        expect(status.can_transition_to?('paused')).to be false
      end
    end

    it 'returns false for invalid status' do
      status = described_class.new(value: 'active')
      expect(status.can_transition_to?('invalid')).to be false
    end
  end

  describe '#transition_to' do
    let(:user) { 'admin@example.com' }

    it 'creates new status with transition' do
      original = described_class.new(value: 'draft')
      new_status = original.transition_to('active', changed_by: user)

      expect(new_status.value).to eq('active')
      expect(new_status.changed_by).to eq(user)
      expect(new_status.changed_at).to be > original.changed_at
      expect(original.value).to eq('draft') # Original unchanged
    end

    it 'includes reason in transition' do
      original = described_class.new(value: 'active')
      new_status = original.transition_to(
        'paused',
        changed_by: user,
        reason: 'Scheduled maintenance'
      )

      expect(new_status.reason).to eq('Scheduled maintenance')
    end

    it 'raises error for invalid transition' do
      status = described_class.new(value: 'draft')
      
      expect {
        status.transition_to('paused')
      }.to raise_error(ArgumentError, 'Cannot transition from draft to paused')
    end
  end

  describe '#available_transitions' do
    it 'returns available transitions for each status' do
      expect(described_class.new(value: 'draft').available_transitions)
        .to eq(%w[active archived])
      
      expect(described_class.new(value: 'active').available_transitions)
        .to eq(%w[paused archived])
      
      expect(described_class.new(value: 'paused').available_transitions)
        .to eq(%w[active archived])
      
      expect(described_class.new(value: 'archived').available_transitions)
        .to eq([])
    end
  end

  describe 'business rule methods' do
    it '#executable? returns true only for active' do
      expect(described_class.new(value: 'draft').executable?).to be false
      expect(described_class.new(value: 'active').executable?).to be true
      expect(described_class.new(value: 'paused').executable?).to be false
      expect(described_class.new(value: 'archived').executable?).to be false
    end

    it '#editable? returns false only for archived' do
      expect(described_class.new(value: 'draft').editable?).to be true
      expect(described_class.new(value: 'active').editable?).to be true
      expect(described_class.new(value: 'paused').editable?).to be true
      expect(described_class.new(value: 'archived').editable?).to be false
    end

    it '#deletable? returns true for draft and archived' do
      expect(described_class.new(value: 'draft').deletable?).to be true
      expect(described_class.new(value: 'active').deletable?).to be false
      expect(described_class.new(value: 'paused').deletable?).to be false
      expect(described_class.new(value: 'archived').deletable?).to be true
    end

    it '#requires_reason_for_transition? returns true for paused and archived' do
      expect(described_class.new(value: 'draft').requires_reason_for_transition?).to be false
      expect(described_class.new(value: 'active').requires_reason_for_transition?).to be false
      expect(described_class.new(value: 'paused').requires_reason_for_transition?).to be true
      expect(described_class.new(value: 'archived').requires_reason_for_transition?).to be true
    end
  end

  describe '#duration_in_status' do
    it 'calculates time in current status' do
      status = described_class.new(
        value: 'active',
        changed_at: 2.hours.ago
      )

      expect(status.duration_in_status).to be_within(1.second).of(2.hours)
    end
  end

  describe '#to_s' do
    it 'returns the status value' do
      status = described_class.new(value: 'active')
      expect(status.to_s).to eq('active')
    end
  end

  describe '#to_h' do
    it 'returns hash with all attributes' do
      time = Time.current
      status = described_class.new(
        value: 'paused',
        changed_at: time,
        changed_by: 'user@example.com',
        reason: 'Maintenance'
      )

      expect(status.to_h).to eq({
        value: 'paused',
        changed_at: time,
        changed_by: 'user@example.com',
        reason: 'Maintenance'
      })
    end

    it 'omits nil values' do
      status = described_class.new(value: 'active')
      
      expect(status.to_h).to include(:value, :changed_at)
      expect(status.to_h).not_to include(:changed_by, :reason)
    end
  end

  describe '#==' do
    it 'compares by value only' do
      status1 = described_class.new(value: 'active', changed_by: 'user1')
      status2 = described_class.new(value: 'active', changed_by: 'user2')
      status3 = described_class.new(value: 'paused')

      expect(status1).to eq(status2)
      expect(status1).not_to eq(status3)
    end

    it 'returns false for different types' do
      status = described_class.new(value: 'active')
      
      expect(status).not_to eq('active')
      expect(status).not_to eq(nil)
    end
  end

  describe 'factory methods' do
    it '.draft creates draft status' do
      status = described_class.draft(changed_by: 'user@example.com')
      
      expect(status.value).to eq('draft')
      expect(status.changed_by).to eq('user@example.com')
    end

    it '.active creates active status' do
      status = described_class.active(changed_by: 'user@example.com')
      
      expect(status.value).to eq('active')
      expect(status.changed_by).to eq('user@example.com')
    end

    it '.paused creates paused status with reason' do
      status = described_class.paused(
        changed_by: 'user@example.com',
        reason: 'Maintenance'
      )
      
      expect(status.value).to eq('paused')
      expect(status.changed_by).to eq('user@example.com')
      expect(status.reason).to eq('Maintenance')
    end

    it '.archived creates archived status with reason' do
      status = described_class.archived(
        changed_by: 'user@example.com',
        reason: 'No longer needed'
      )
      
      expect(status.value).to eq('archived')
      expect(status.changed_by).to eq('user@example.com')
      expect(status.reason).to eq('No longer needed')
    end

    it '.from_string creates status from string' do
      status = described_class.from_string(
        'active',
        changed_by: 'user@example.com'
      )
      
      expect(status.value).to eq('active')
      expect(status.changed_by).to eq('user@example.com')
    end
  end
end