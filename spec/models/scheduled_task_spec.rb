require 'rails_helper'

RSpec.describe ScheduledTask, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:task_template) { create(:task_template, organization: organization) }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:task_template) }
    it { should belong_to(:created_by).class_name('User') }
    it { should have_many(:scheduled_task_runs).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:scheduled_task, organization: organization, task_template: task_template, created_by: user) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(ScheduledTask::STATUSES) }
    it { should validate_presence_of(:schedule_type) }
    it { should validate_inclusion_of(:schedule_type).in_array(ScheduledTask::SCHEDULE_TYPES) }

    context 'when schedule_type is once' do
      before { subject.schedule_type = 'once' }
      it { should validate_presence_of(:scheduled_at) }
    end

    context 'when schedule_type is custom' do
      before { subject.schedule_type = 'custom' }
      it { should validate_presence_of(:cron_expression) }
    end

    context 'when schedule_type is daily' do
      before { subject.schedule_type = 'daily' }
      it { should validate_presence_of(:time_of_day) }
    end

    context 'when schedule_type is weekly' do
      before { subject.schedule_type = 'weekly' }
      it { should validate_presence_of(:time_of_day) }
      it { should validate_presence_of(:days_of_week) }
    end

    context 'when schedule_type is monthly' do
      before { subject.schedule_type = 'monthly' }
      it { should validate_presence_of(:time_of_day) }
      it { should validate_presence_of(:day_of_month) }
      it { should validate_numericality_of(:day_of_month).is_greater_than_or_equal_to(1).is_less_than_or_equal_to(31) }
    end
  end

  describe 'scopes' do
    let!(:active_task) { create(:scheduled_task, organization: organization, status: 'active') }
    let!(:paused_task) { create(:scheduled_task, organization: organization, status: 'paused') }
    let!(:due_task) { create(:scheduled_task, organization: organization, status: 'active', next_run_at: 1.hour.ago) }
    let!(:future_task) { create(:scheduled_task, organization: organization, status: 'active', next_run_at: 1.hour.from_now) }

    describe '.active' do
      it 'returns only active tasks' do
        expect(ScheduledTask.active).to include(active_task, due_task, future_task)
        expect(ScheduledTask.active).not_to include(paused_task)
      end
    end

    describe '.paused' do
      it 'returns only paused tasks' do
        expect(ScheduledTask.paused).to include(paused_task)
        expect(ScheduledTask.paused).not_to include(active_task)
      end
    end

    describe '.due_for_execution' do
      it 'returns active tasks with next_run_at in the past' do
        expect(ScheduledTask.due_for_execution).to include(due_task)
        expect(ScheduledTask.due_for_execution).not_to include(future_task, paused_task)
      end
    end
  end

  describe '#should_run?' do
    let(:task) { create(:scheduled_task, organization: organization, status: 'active', next_run_at: 1.minute.ago) }

    it 'returns true for active task past its run time' do
      expect(task.should_run?).to be true
    end

    it 'returns false for paused task' do
      task.update!(status: 'paused')
      expect(task.should_run?).to be false
    end

    it 'returns false for expired task' do
      task.update!(status: 'expired')
      expect(task.should_run?).to be false
    end

    it 'returns false if max runs reached' do
      task.update!(max_runs: 5, run_count: 5)
      expect(task.should_run?).to be false
    end

    it 'returns false if next_run_at is in future' do
      task.update!(next_run_at: 1.hour.from_now)
      expect(task.should_run?).to be false
    end
  end

  describe '#execute!' do
    let(:task) { create(:scheduled_task,
      organization: organization,
      task_template: task_template,
      status: 'active',
      next_run_at: 1.minute.ago
    ) }

    it 'creates a pipeline execution' do
      expect {
        task.execute!
      }.to change { PipelineExecution.count }.by(1)
    end

    it 'creates a task from template' do
      expect {
        task.execute!
      }.to change { Task.count }.by(1)
    end

    it 'creates a scheduled task run' do
      expect {
        task.execute!
      }.to change { task.scheduled_task_runs.count }.by(1)
    end

    it 'increments run count' do
      expect {
        task.execute!
      }.to change { task.reload.run_count }.by(1)
    end

    it 'calculates next run time' do
      task.update!(schedule_type: 'daily', time_of_day: Time.current)
      task.execute!
      expect(task.reload.next_run_at).to be > Time.current
    end

    it 'marks as completed if one-time task' do
      task.update!(schedule_type: 'once')
      task.execute!
      expect(task.reload.status).to eq('completed')
    end

    it 'marks as completed if max runs reached' do
      task.update!(max_runs: 1)
      task.execute!
      expect(task.reload.status).to eq('completed')
    end
  end

  describe '#calculate_next_run_at' do
    let(:task) { build(:scheduled_task, organization: organization, status: 'active') }

    context 'daily schedule' do
      before do
        task.schedule_type = 'daily'
        task.time_of_day = Time.parse('14:00')
      end

      it 'schedules for same day if time not passed' do
        allow(Time).to receive(:current).and_return(Time.parse('2024-01-01 10:00'))
        task.calculate_next_run_at
        expect(task.next_run_at).to eq(Time.parse('2024-01-01 14:00'))
      end

      it 'schedules for next day if time passed' do
        allow(Time).to receive(:current).and_return(Time.parse('2024-01-01 16:00'))
        task.calculate_next_run_at
        expect(task.next_run_at).to eq(Time.parse('2024-01-02 14:00'))
      end
    end

    context 'weekly schedule' do
      before do
        task.schedule_type = 'weekly'
        task.time_of_day = Time.parse('14:00')
        task.days_of_week = [ 'monday', 'wednesday', 'friday' ]
      end

      it 'schedules for next valid day' do
        # Assuming current day is Tuesday
        allow(Time).to receive(:current).and_return(Time.parse('2024-01-02 10:00')) # Tuesday
        task.calculate_next_run_at
        # Should schedule for Wednesday
        expect(task.next_run_at.wday).to eq(3) # Wednesday
      end
    end

    context 'monthly schedule' do
      before do
        task.schedule_type = 'monthly'
        task.time_of_day = Time.parse('14:00')
        task.day_of_month = 15
      end

      it 'schedules for current month if day not passed' do
        allow(Time).to receive(:current).and_return(Time.parse('2024-01-10 10:00'))
        task.calculate_next_run_at
        expect(task.next_run_at).to eq(Time.parse('2024-01-15 14:00'))
      end

      it 'schedules for next month if day passed' do
        allow(Time).to receive(:current).and_return(Time.parse('2024-01-20 10:00'))
        task.calculate_next_run_at
        expect(task.next_run_at).to eq(Time.parse('2024-02-15 14:00'))
      end
    end
  end

  describe '#pause! and #resume!' do
    let(:task) { create(:scheduled_task, organization: organization, status: 'active') }

    it 'pauses the task' do
      task.pause!
      expect(task.status).to eq('paused')
      expect(task.paused_at).to be_present
    end

    it 'resumes the task' do
      task.pause!
      task.resume!
      expect(task.status).to eq('active')
      expect(task.resumed_at).to be_present
    end
  end

  describe '#schedule_description' do
    let(:task) { build(:scheduled_task, organization: organization) }

    it 'returns description for once schedule' do
      task.schedule_type = 'once'
      task.scheduled_at = Time.parse('2024-01-15 14:00')
      expect(task.schedule_description).to eq('Once at 2024-01-15 14:00')
    end

    it 'returns description for daily schedule' do
      task.schedule_type = 'daily'
      task.time_of_day = Time.parse('14:00')
      expect(task.schedule_description).to include('Daily at')
    end

    it 'returns description for weekly schedule' do
      task.schedule_type = 'weekly'
      task.time_of_day = Time.parse('14:00')
      task.days_of_week = [ 'monday', 'wednesday' ]
      expect(task.schedule_description).to include('Weekly on monday, wednesday')
    end

    it 'returns description for monthly schedule' do
      task.schedule_type = 'monthly'
      task.time_of_day = Time.parse('14:00')
      task.day_of_month = 15
      expect(task.schedule_description).to include('Monthly on day 15')
    end

    it 'returns description for custom schedule' do
      task.schedule_type = 'custom'
      task.cron_expression = '0 0 * * *'
      expect(task.schedule_description).to eq('Custom: 0 0 * * *')
    end
  end

  describe '#run_statistics' do
    let(:task) { create(:scheduled_task, organization: organization) }
    let!(:successful_run) { create(:scheduled_task_run, scheduled_task: task, status: 'completed', duration_seconds: 60) }
    let!(:failed_run) { create(:scheduled_task_run, scheduled_task: task, status: 'failed') }

    it 'returns correct statistics' do
      stats = task.run_statistics
      expect(stats[:total_runs]).to eq(2)
      expect(stats[:successful_runs]).to eq(1)
      expect(stats[:failed_runs]).to eq(1)
      expect(stats[:average_duration]).to eq(60)
    end
  end
end
