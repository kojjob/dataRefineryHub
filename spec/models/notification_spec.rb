require 'rails_helper'

RSpec.describe Notification, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:organization) }
    it { should belong_to(:notifiable).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:message) }
    it { should validate_length_of(:title).is_at_most(255) }
    it { should validate_inclusion_of(:notification_type).in_array(Notification::TYPES) }
    it { should validate_inclusion_of(:priority).in_array(Notification::PRIORITIES.values) }
  end

  describe 'scopes' do
    let!(:read_notification) { create(:notification, :read) }
    let!(:unread_notification) { create(:notification, :unread) }

    it 'returns unread notifications' do
      expect(Notification.unread).to include(unread_notification)
      expect(Notification.unread).not_to include(read_notification)
    end

    it 'returns read notifications' do
      expect(Notification.read).to include(read_notification)
      expect(Notification.read).not_to include(unread_notification)
    end

    it 'returns notifications in recent order' do
      older_notification = create(:notification, created_at: 2.days.ago)
      newer_notification = create(:notification, created_at: 1.day.ago)
      expect(Notification.recent.first).to eq(newer_notification)
    end
  end

  describe 'instance methods' do
    let(:notification) { create(:notification) }

    describe '#read?' do
      it 'returns false for unread notifications' do
        expect(notification.read?).to be false
      end

      it 'returns true for read notifications' do
        notification.update(read_at: Time.current)
        expect(notification.read?).to be true
      end
    end

    describe '#mark_as_read!' do
      it 'sets read_at timestamp' do
        expect { notification.mark_as_read! }.to change { notification.read_at }.from(nil)
        expect(notification.read?).to be true
      end
    end

    describe '#mark_as_unread!' do
      let(:read_notification) { create(:notification, :read) }

      it 'clears read_at timestamp' do
        expect { read_notification.mark_as_unread! }.to change { read_notification.read_at }.to(nil)
        expect(read_notification.read?).to be false
      end
    end

    describe '#priority_name' do
      it 'returns the priority name' do
        notification.update(priority: Notification::PRIORITIES[:high])
        expect(notification.priority_name).to eq(:high)
      end
    end

    describe '#high_priority?' do
      it 'returns true for high priority notifications' do
        notification.update(priority: Notification::PRIORITIES[:high])
        expect(notification.high_priority?).to be true
      end

      it 'returns false for normal priority notifications' do
        notification.update(priority: Notification::PRIORITIES[:normal])
        expect(notification.high_priority?).to be false
      end
    end

    describe '#icon' do
      it 'returns correct icon for success notifications' do
        notification.update(notification_type: 'data_sync_success')
        expect(notification.icon).to eq('✅')
      end

      it 'returns correct icon for failure notifications' do
        notification.update(notification_type: 'data_sync_failure')
        expect(notification.icon).to eq('❌')
      end
    end
  end

  describe 'class methods' do
    describe '.create_for_data_sync' do
      let(:data_source) { create(:data_source) }
      let(:organization) { data_source.organization }

      it 'creates success notifications for all organization users' do
        user1 = create(:user, organization: organization)
        user2 = create(:user, organization: organization)

        expect {
          Notification.create_for_data_sync(data_source, true, { records_count: 100 })
        }.to change { Notification.count }.by(2)

        notifications = Notification.where(notifiable: data_source)
        expect(notifications.pluck(:user_id)).to match_array([ user1.id, user2.id ])
        expect(notifications.first.notification_type).to eq('data_sync_success')
        expect(notifications.first.title).to include(data_source.name)
      end

      it 'creates failure notifications with proper priority' do
        user = create(:user, organization: organization)

        Notification.create_for_data_sync(data_source, false, { error_message: 'Connection failed' })

        notification = Notification.last
        expect(notification.notification_type).to eq('data_sync_failure')
        expect(notification.priority).to eq(Notification::PRIORITIES[:high])
        expect(notification.message).to include('Connection failed')
      end
    end
  end
end
