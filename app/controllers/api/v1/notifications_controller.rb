class Api::V1::NotificationsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_notification, only: [ :show, :update, :destroy ]

  def index
    @notifications = current_user.notifications
                                 .includes(:notifiable)
                                 .recent
                                 .page(params[:page])
                                 .per(params[:per_page] || 20)

    # Filter by type if provided
    @notifications = @notifications.by_type(params[:type]) if params[:type].present?

    # Filter by read status if provided
    @notifications = @notifications.unread if params[:unread] == "true"
    @notifications = @notifications.read if params[:read] == "true"

    render json: {
      notifications: @notifications.map do |notification|
        {
          id: notification.id,
          title: notification.title,
          message: notification.message,
          type: notification.notification_type,
          priority: notification.priority_name,
          read: notification.read?,
          icon: notification.icon,
          color_class: notification.color_class,
          created_at: notification.created_at,
          read_at: notification.read_at,
          notifiable: notification.notifiable ? {
            type: notification.notifiable_type,
            id: notification.notifiable_id
          } : nil
        }
      end,
      pagination: {
        current_page: @notifications.current_page,
        total_pages: @notifications.total_pages,
        total_count: @notifications.total_count,
        per_page: @notifications.limit_value
      },
      unread_count: current_user.notifications.unread.count
    }
  end

  def show
    render json: {
      notification: {
        id: @notification.id,
        title: @notification.title,
        message: @notification.message,
        type: @notification.notification_type,
        priority: @notification.priority_name,
        read: @notification.read?,
        icon: @notification.icon,
        color_class: @notification.color_class,
        created_at: @notification.created_at,
        read_at: @notification.read_at,
        metadata: @notification.metadata,
        notifiable: @notification.notifiable ? {
          type: @notification.notifiable_type,
          id: @notification.notifiable_id,
          data: @notification.notifiable
        } : nil
      }
    }
  end

  def update
    if @notification.update(notification_params)
      render json: {
        notification: {
          id: @notification.id,
          read: @notification.read?,
          read_at: @notification.read_at
        }
      }
    else
      render json: { errors: @notification.errors }, status: :unprocessable_entity
    end
  end

  def mark_as_read
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_read!

    render json: {
      notification: {
        id: @notification.id,
        read: true,
        read_at: @notification.read_at
      }
    }
  end

  def mark_as_unread
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_unread!

    render json: {
      notification: {
        id: @notification.id,
        read: false,
        read_at: nil
      }
    }
  end

  def mark_all_as_read
    current_user.notifications.unread.update_all(read_at: Time.current)

    render json: {
      message: "All notifications marked as read",
      unread_count: 0
    }
  end

  def destroy
    @notification.destroy
    render json: { message: "Notification deleted" }
  end

  def unread_count
    render json: {
      unread_count: current_user.notifications.unread.count
    }
  end

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end

  def notification_params
    if params[:notification]
      params.require(:notification).permit(:read_at)
    else
      # Handle direct parameter passing for read_at
      params.permit(:read_at)
    end
  end
end
