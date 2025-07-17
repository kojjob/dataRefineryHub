# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::AutomatedAction, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organizations: [organization]) }
  let(:insight) { create(:ai_insight, organization: organization) }
  
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:insight).optional }
    it { should belong_to(:approved_by).class_name('User').optional }
  end
  
  describe 'validations' do
    it { should validate_presence_of(:organization) }
    it { should validate_presence_of(:action_type) }
    it { should validate_inclusion_of(:status).in_array(%w[pending approved executing completed failed cancelled]) }
  end
  
  describe 'enums' do
    it { should define_enum_for(:status).with_values(
      pending: 0,
      approved: 1,
      executing: 2,
      completed: 3,
      failed: 4,
      cancelled: 5
    ) }
  end
  
  describe 'scopes' do
    let!(:pending_action) { create(:ai_automated_action, organization: organization, status: 'pending') }
    let!(:completed_action) { create(:ai_automated_action, organization: organization, status: 'completed') }
    let!(:failed_action) { create(:ai_automated_action, organization: organization, status: 'failed') }
    let!(:high_confidence_action) { create(:ai_automated_action, organization: organization, parameters: { confidence: 0.9 }) }
    
    describe '.actionable' do
      it 'returns pending and approved actions' do
        approved_action = create(:ai_automated_action, organization: organization, status: 'approved')
        expect(Ai::AutomatedAction.actionable).to contain_exactly(pending_action, approved_action)
      end
    end
    
    describe '.requiring_approval' do
      it 'returns pending actions' do
        expect(Ai::AutomatedAction.requiring_approval).to contain_exactly(pending_action)
      end
    end
    
    describe '.high_confidence' do
      it 'returns actions with confidence > 0.8' do
        expect(Ai::AutomatedAction.high_confidence).to contain_exactly(high_confidence_action)
      end
    end
  end
  
  describe 'state transitions' do
    let(:action) { create(:ai_automated_action, organization: organization) }
    
    describe '#approve!' do
      it 'transitions from pending to approved' do
        action.approved_by = user
        action.approve!
        expect(action.status).to eq('approved')
        expect(action.approved_at).to be_present
      end
      
      it 'raises error without approved_by' do
        expect { action.approve! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
    
    describe '#execute!' do
      before { action.update!(status: 'approved', approved_by: user) }
      
      it 'transitions to executing' do
        action.execute!
        expect(action.status).to eq('executing')
        expect(action.executed_at).to be_present
      end
    end
    
    describe '#complete!' do
      before { action.update!(status: 'executing') }
      
      it 'transitions to completed with result' do
        result = { success: true, message: 'Action completed' }
        action.complete!(result)
        expect(action.status).to eq('completed')
        expect(action.completed_at).to be_present
        expect(action.result).to eq(result)
      end
    end
    
    describe '#fail!' do
      before { action.update!(status: 'executing') }
      
      it 'transitions to failed with error' do
        error = 'Connection timeout'
        action.fail!(error)
        expect(action.status).to eq('failed')
        expect(action.result['error']).to eq(error)
      end
    end
    
    describe '#cancel!' do
      it 'can be cancelled from pending or approved state' do
        action.cancel!
        expect(action.status).to eq('cancelled')
      end
    end
  end
  
  describe 'instance methods' do
    let(:action) { create(:ai_automated_action, organization: organization) }
    
    describe '#requires_approval?' do
      context 'for high-impact actions' do
        let(:action) { create(:ai_automated_action, action_type: 'adjust_pricing') }
        
        it 'returns true' do
          expect(action.requires_approval?).to be true
        end
      end
      
      context 'for low-impact actions' do
        let(:action) { create(:ai_automated_action, action_type: 'send_notification') }
        
        it 'returns false' do
          expect(action.requires_approval?).to be false
        end
      end
    end
    
    describe '#description' do
      let(:action) { create(:ai_automated_action, 
        action_type: 'send_email',
        parameters: { recipient: 'user@example.com', subject: 'Report' }
      ) }
      
      it 'generates human-readable description' do
        expect(action.description).to include('Send email')
        expect(action.description).to include('user@example.com')
      end
    end
    
    describe '#estimated_impact' do
      context 'for revenue-impacting actions' do
        let(:action) { create(:ai_automated_action,
          action_type: 'create_campaign',
          parameters: { estimated_revenue: 5000 }
        ) }
        
        it 'returns impact estimate' do
          expect(action.estimated_impact).to include('revenue')
          expect(action.estimated_impact).to include('$5,000')
        end
      end
    end
    
    describe '#can_execute?' do
      it 'returns true for approved actions' do
        action.update!(status: 'approved', approved_by: user)
        expect(action.can_execute?).to be true
      end
      
      it 'returns false for non-approved actions' do
        expect(action.can_execute?).to be false
      end
    end
  end
  
  describe 'validations' do
    describe 'parameter validation' do
      it 'validates required parameters for action type' do
        action = build(:ai_automated_action,
          action_type: 'send_email',
          parameters: {} # Missing required params
        )
        expect(action).not_to be_valid
        expect(action.errors[:parameters]).to include('Missing required parameters')
      end
    end
  end
  
  describe 'callbacks' do
    describe 'after_create' do
      it 'sends notification for high-priority actions' do
        expect {
          create(:ai_automated_action,
            organization: organization,
            parameters: { priority: 'high' }
          )
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end
  end
end