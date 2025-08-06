# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationService, type: :service do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }

  describe "security measures" do
    describe ".create_notification" do
      it "sanitizes title and message for logging" do
        malicious_title = "Alert <script>alert('xss')</script>"
        malicious_message = "Message with password=secret123 and token=abc123"
        
        allow(Rails.logger).to receive(:info)
        
        NotificationService.create_notification(
          user: user,
          type: "data_sync_success",
          title: malicious_title,
          message: malicious_message,
          data: { key: "value" }
        )
        
        expect(Rails.logger).to have_received(:info) do |&block|
          log_message = block.call
          expect(log_message).not_to include("<script>")
          expect(log_message).to include("password=[REDACTED]")
        end
      end

      it "sanitizes sensitive data in metadata" do
        sensitive_data = {
          user_id: 123,
          password: "secret123",
          api_key: "key_12345",
          token: "token_67890"
        }
        
        allow(Rails.logger).to receive(:info)
        
        NotificationService.create_notification(
          user: user,
          type: "data_sync_success",
          title: "Test",
          message: "Test message",
          data: sensitive_data
        )
        
        expect(Rails.logger).to have_received(:info) do |&block|
          log_message = block.call
          expect(log_message).to include("password=[REDACTED]")
          expect(log_message).to include("api_key=[REDACTED]")
          expect(log_message).to include("token=[REDACTED]")
          expect(log_message).to include("user_id")
        end
      end
    end

    describe ".broadcast_notification" do
      let(:notification) { create(:notification, user: user, organization: organization) }

      it "sanitizes broadcast data" do
        notification.update!(
          title: "Test <script>alert('xss')</script>",
          message: "Message with <iframe src='evil.com'></iframe>",
          metadata: { password: "secret123" }
        )
        
        expect(ActionCable.server).to receive(:broadcast) do |channel, data|
          expect(data[:title]).not_to include("<script>")
          expect(data[:message]).not_to include("<iframe>")
          expect(data[:data]).not_to have_key("password")
        end
        
        NotificationService.broadcast_notification(user, notification)
      end
    end

    describe "sanitization methods" do
      subject { NotificationService }

      describe ".sanitize_for_log" do
        it "removes HTML tags and sensitive patterns" do
          text = "Alert <script>alert()</script> with password=secret123"
          result = subject.send(:sanitize_for_log, text)
          
          expect(result).not_to include("<script>")
          expect(result).to include("password=[REDACTED]")
        end

        it "truncates long text" do
          long_text = "a" * 1000
          result = subject.send(:sanitize_for_log, long_text)
          
          expect(result.length).to be <= 500
        end
      end

      describe ".sanitize_for_broadcast" do
        it "allows safe HTML tags only" do
          html = "<strong>Bold</strong><script>alert()</script><p>Text</p>"
          result = subject.send(:sanitize_for_broadcast, html)
          
          expect(result).to include("<strong>Bold</strong>")
          expect(result).not_to include("<script>")
          expect(result).not_to include("<p>") # p tag not in allowed list
        end
      end

      describe ".sanitize_metadata_for_log" do
        it "sanitizes hash metadata" do
          metadata = {
            user_id: 123,
            password: "secret",
            nested: { api_key: "key123" }
          }
          result = subject.send(:sanitize_metadata_for_log, metadata)
          
          expect(result[:user_id]).to eq(123)
          expect(result[:password]).to eq("[REDACTED]")
          expect(result[:nested][:api_key]).to eq("[REDACTED]")
        end

        it "limits array size" do
          large_array = (1..20).to_a
          result = subject.send(:sanitize_metadata_for_log, large_array)
          
          expect(result.length).to be <= 10
        end
      end

      describe ".sanitize_metadata_for_broadcast" do
        it "removes sensitive keys entirely" do
          metadata = {
            user_id: 123,
            password: "secret",
            public_info: "visible"
          }
          result = subject.send(:sanitize_metadata_for_broadcast, metadata)
          
          expect(result).to have_key("user_id")
          expect(result).to have_key("public_info")
          expect(result).not_to have_key("password")
        end
      end

      describe ".sensitive_key?" do
        it "identifies sensitive keys" do
          sensitive_keys = %w[password token secret api_key auth_token]
          safe_keys = %w[user_id name status count]
          
          sensitive_keys.each do |key|
            expect(subject.send(:sensitive_key?, key)).to be true
          end
          
          safe_keys.each do |key|
            expect(subject.send(:sensitive_key?, key)).to be false
          end
        end

        it "works with compound key names" do
          expect(subject.send(:sensitive_key?, "user_password")).to be true
          expect(subject.send(:sensitive_key?, "access_token_expires")).to be true
          expect(subject.send(:sensitive_key?, "user_email_password")).to be true
        end
      end
    end

    describe "logging security" do
      it "does not log sensitive information in error messages" do
        allow(Rails.logger).to receive(:error)
        
        # Simulate high priority notification with sensitive data
        notification = double(
          title: "System alert with password=secret123",
          metadata: { api_key: "key123" }
        )
        
        NotificationService.send(:send_additional_alerts, user, notification)
        
        expect(Rails.logger).to have_received(:error) do |message|
          expect(message).to include("password=[REDACTED]")
          expect(message).not_to include("secret123")
        end
      end
    end
  end
end