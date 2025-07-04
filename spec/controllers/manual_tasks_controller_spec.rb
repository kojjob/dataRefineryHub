require 'rails_helper'

RSpec.describe ManualTasksController, type: :controller do
  render_views
  
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:admin) { create(:user, :admin, organization: organization) }
  let(:pipeline_execution) { create(:pipeline_execution, organization: organization) }
  let(:task) { create(:task, pipeline_execution: pipeline_execution, execution_mode: 'manual') }
  
  before do
    sign_in user
  end
  
  describe 'GET #index' do
    it 'assigns pending tasks' do
      task.update(status: 'pending')
      get :index
      expect(assigns(:tasks)).to include(task)
    end
    
    it 'filters tasks by assignee when requested' do
      task.update(assignee: user, status: 'pending')
      other_task = create(:task, pipeline_execution: pipeline_execution, status: 'pending')
      
      get :index, params: { assigned_to_me: true }
      expect(assigns(:tasks)).to include(task)
      expect(assigns(:tasks)).not_to include(other_task)
    end
    
    it 'returns turbo stream format when requested' do
      get :index, format: :turbo_stream
      expect(response.content_type).to include('text/vnd.turbo-stream.html')
    end
  end
  
  describe 'GET #show' do
    it 'assigns the requested task' do
      get :show, params: { id: task.id }
      expect(assigns(:task)).to eq(task)
    end
    
    it 'loads task executions' do
      execution = create(:task_execution, task: task)
      get :show, params: { id: task.id }
      expect(assigns(:task_executions)).to include(execution)
    end
  end
  
  describe 'GET #execute' do
    before { task.update(assignee: user) }
    
    it 'renders the execute form' do
      get :execute, params: { id: task.id }
      expect(response).to render_template(:execute)
    end
  end
  
  describe 'POST #execute' do
    before { task.update(assignee: user) }
    
    it 'executes the task' do
      expect_any_instance_of(ManualTaskQueueService).to receive(:execute_manual_task)
        .with(task.id.to_s, user, anything)
      
      post :execute, params: { id: task.id, notes: 'Test execution' }
      expect(response).to redirect_to(manual_tasks_path)
    end
    
    it 'redirects with error on failure' do
      allow_any_instance_of(ManualTaskQueueService).to receive(:execute_manual_task)
        .and_raise('Test error')
      
      post :execute, params: { id: task.id }
      expect(response).to redirect_to(manual_task_path(task))
      expect(flash[:alert]).to include('Failed to execute task')
    end
  end
  
  describe 'POST #approve' do
    before do
      task.update(assignee: user, status: 'waiting_approval')
    end
    
    it 'approves and executes the task' do
      expect(task).to receive(:approve!).with(user).and_return(true)
      expect(task).to receive(:execute!).with(user)
      
      post :approve, params: { id: task.id }
      expect(response).to redirect_to(manual_tasks_path)
    end
    
    it 'returns turbo stream format when requested' do
      allow(task).to receive(:approve!).and_return(true)
      allow(task).to receive(:execute!)
      
      post :approve, params: { id: task.id }, format: :turbo_stream
      expect(response.content_type).to include('text/vnd.turbo-stream.html')
    end
  end
  
  describe 'POST #reject' do
    before do
      task.update(assignee: user, status: 'waiting_approval')
    end
    
    it 'rejects the task with reason' do
      expect(task).to receive(:reject!).with(user, 'Test reason').and_return(true)
      
      post :reject, params: { id: task.id, reason: 'Test reason' }
      expect(response).to redirect_to(manual_tasks_path)
    end
  end
  
  describe 'POST #auto_assign' do
    context 'as admin' do
      before { sign_in admin }
      
      it 'auto assigns tasks' do
        expect_any_instance_of(ManualTaskQueueService).to receive(:auto_assign_tasks)
          .and_return(2)
        
        post :auto_assign
        expect(response).to redirect_to(manual_tasks_path)
        expect(flash[:notice]).to include('Successfully auto-assigned 2 tasks')
      end
    end
    
    context 'as regular user' do
      it 'redirects with authorization error' do
        post :auto_assign
        expect(response).to redirect_to(root_path)
      end
    end
  end
  
  describe 'POST #clear_stale' do
    context 'as admin' do
      before { sign_in admin }
      
      it 'clears stale assignments' do
        expect_any_instance_of(ManualTaskQueueService).to receive(:clear_stale_assignments)
          .and_return(3)
        
        post :clear_stale
        expect(response).to redirect_to(manual_tasks_path)
        expect(flash[:notice]).to include('Cleared 3 stale task assignments')
      end
    end
  end
  
  private
  
  def sign_in(user)
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
  end
end