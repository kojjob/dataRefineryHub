# frozen_string_literal: true

class AiChatChannel < ApplicationCable::Channel
  def subscribed
    organization = Organization.find(params[:organization_id])
    user = User.find(params[:user_id])

    # Verify user has access to organization
    if user.organizations.include?(organization)
      stream_from "ai_chat_#{organization.id}_#{user.id}"

      # Send connection confirmation
      transmit(
        type: "connection_established",
        message: "Connected to AI Chat",
        timestamp: Time.current
      )
    else
      reject
    end
  end

  def unsubscribed
    # Clean up any resources
    stop_all_streams
  end

  def receive(data)
    case data["action"]
    when "typing"
      # Broadcast typing indicator
      broadcast_typing_indicator(data)
    when "mark_read"
      # Mark messages as read
      mark_messages_as_read(data["message_ids"])
    end
  end

  private

  def broadcast_typing_indicator(data)
    ActionCable.server.broadcast(
      "ai_chat_#{params[:organization_id]}_typing",
      {
        type: "typing_indicator",
        user_id: params[:user_id],
        typing: data["typing"],
        timestamp: Time.current
      }
    )
  end

  def mark_messages_as_read(message_ids)
    return unless message_ids.present?

    Ai::Query.where(id: message_ids, user_id: params[:user_id]).update_all(read_at: Time.current)
  end
end
