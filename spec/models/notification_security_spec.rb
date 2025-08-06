# frozen_string_literal: true

require "rails_helper"

RSpec.describe Notification, type: :model do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }

  describe "security validations" do
    describe "content sanitization" do
      it "sanitizes title before saving" do
        notification = build(:notification, 
          user: user,
          organization: organization,
          title: "Alert <script>alert('xss')</script> Test"
        )
        
        notification.save!
        expect(notification.title).not_to include("<script>")
        expect(notification.title).to include("Alert")
        expect(notification.title).to include("Test")
      end

      it "sanitizes message before saving" do
        notification = build(:notification,
          user: user,
          organization: organization,
          message: "Message with <iframe src='evil.com'></iframe> content"
        )
        
        notification.save!
        expect(notification.message).not_to include("<iframe>")
        expect(notification.message).to include("Message with")
        expect(notification.message).to include("content")
      end

      it "sanitizes metadata before saving" do
        notification = build(:notification,
          user: user,
          organization: organization,
          metadata: {
            description: "<script>alert('xss')</script>",
            password: "secret123",
            records_count: 100
          }
        )
        
        notification.save!
        expect(notification.metadata["description"]).not_to include("<script>")
        expect(notification.metadata).not_to have_key("password")
        expect(notification.metadata["records_count"]).to eq(100)
      end
    end

    describe "dangerous content validation" do
      it "rejects titles with dangerous content" do
        notification = build(:notification,
          user: user,
          organization: organization,
          title: "<script>alert('xss')</script>"
        )
        
        expect(notification).not_to be_valid
        expect(notification.errors[:title]).to include("contains invalid or potentially dangerous content")
      end

      it "rejects messages with dangerous content" do
        notification = build(:notification,
          user: user,
          organization: organization,
          message: "Click <a href='javascript:alert()'>here</a>"
        )
        
        expect(notification).not_to be_valid
        expect(notification.errors[:message]).to include("contains invalid or potentially dangerous content")
      end

      it "rejects metadata with dangerous content" do
        notification = build(:notification,
          user: user,
          organization: organization,
          metadata: {
            description: "<object data='evil.swf'></object>",
            records_count: 100
          }
        )
        
        expect(notification).not_to be_valid
        expect(notification.errors[:metadata]).to include("contains invalid content")
      end

      it "rejects metadata that is too large" do
        large_data = "x" * (11 * 1024) # 11KB
        notification = build(:notification,
          user: user,
          organization: organization,
          metadata: { large_field: large_data }
        )
        
        expect(notification).not_to be_valid
        expect(notification.errors[:metadata]).to include("is too large (maximum 10KB)")
      end
    end

    describe "content length limits" do
      it "validates title length" do
        long_title = "x" * 300
        notification = build(:notification,
          user: user,
          organization: organization,
          title: long_title
        )
        
        expect(notification).not_to be_valid
        expect(notification.errors[:title]).to include("is too long")
      end

      it "validates message length" do
        long_message = "x" * 6000
        notification = build(:notification,
          user: user,
          organization: organization,
          message: long_message
        )
        
        expect(notification).not_to be_valid
        expect(notification.errors[:message]).to include("is too long")
      end
    end

    describe "allowed metadata keys" do
      it "only preserves allowed metadata keys" do
        notification = build(:notification,
          user: user,
          organization: organization,
          metadata: {
            records_count: 100,         # Allowed
            error_message: "Failed",    # Allowed
            password: "secret123",      # Not allowed
            secret_key: "key123",       # Not allowed
            malicious_script: "<script>alert()</script>" # Not allowed
          }
        )
        
        notification.save!
        
        expect(notification.metadata).to have_key("records_count")
        expect(notification.metadata).to have_key("error_message")
        expect(notification.metadata).not_to have_key("password")
        expect(notification.metadata).not_to have_key("secret_key")
        expect(notification.metadata).not_to have_key("malicious_script")
      end
    end

    describe "array size limits" do
      it "limits array sizes in metadata" do
        large_array = (1..20).map { |i| "item_#{i}" }
        notification = build(:notification,
          user: user,
          organization: organization,
          metadata: {
            items: large_array
          }
        )
        
        notification.save!
        expect(notification.metadata["items"].length).to be <= 10
      end
    end

    describe "dangerous pattern detection" do
      let(:notification_base) do
        build(:notification, user: user, organization: organization)
      end

      context "with script tags" do
        it "detects script injection attempts" do
          patterns = [
            "<script>alert('xss')</script>",
            "<ScRiPt>alert('xss')</ScRiPt>",
            "<script src='evil.js'></script>"
          ]
          
          patterns.each do |pattern|
            notification = notification_base.dup
            notification.title = pattern
            expect(notification).not_to be_valid
          end
        end
      end

      context "with javascript protocols" do
        it "detects javascript: protocols" do
          patterns = [
            "javascript:alert('xss')",
            "JaVaScRiPt:alert('xss')",
            "&#x6A;&#x61;&#x76;&#x61;&#x73;&#x63;&#x72;&#x69;&#x70;&#x74;&#x3A;alert('xss')"
          ]
          
          patterns.each do |pattern|
            notification = notification_base.dup
            notification.message = pattern
            expect(notification).not_to be_valid
          end
        end
      end

      context "with event handlers" do
        it "detects event handler attributes" do
          patterns = [
            "onclick=alert('xss')",
            "onload=alert('xss')",
            "onerror=alert('xss')",
            "onmouseover=alert('xss')"
          ]
          
          patterns.each do |pattern|
            notification = notification_base.dup
            notification.title = "Test #{pattern}"
            expect(notification).not_to be_valid
          end
        end
      end

      context "with dangerous HTML elements" do
        it "detects dangerous HTML elements" do
          patterns = [
            "<iframe src='evil.com'></iframe>",
            "<object data='evil.swf'></object>",
            "<embed src='evil.swf'></embed>",
            "<link rel='stylesheet' href='evil.css'>",
            "<meta http-equiv='refresh' content='0;url=evil.com'>"
          ]
          
          patterns.each do |pattern|
            notification = notification_base.dup
            notification.message = pattern
            expect(notification).not_to be_valid
          end
        end
      end
    end
  end

  describe "character encoding security" do
    it "removes non-standard characters that could be used for encoding attacks" do
      notification = create(:notification,
        user: user,
        organization: organization,
        title: "Test\u0000\u0001\u0002 Title",
        message: "Message\u000B\u000C\u000E content"
      )
      
      expect(notification.title).not_to match(/[\u0000-\u001F]/)
      expect(notification.message).not_to match(/[\u0000-\u001F]/)
    end
  end

  describe "metadata conversion security" do
    it "safely handles non-hash metadata" do
      notification = build(:notification,
        user: user,
        organization: organization,
        metadata: "string_value"
      )
      
      notification.save!
      expect(notification.metadata).to be_a(Hash)
      expect(notification.metadata["data"]).to eq("string_value")
    end

    it "limits complex object serialization" do
      complex_object = OpenStruct.new(
        name: "test",
        secret: "hidden",
        nested: { deep: "value" }
      )
      
      notification = build(:notification,
        user: user,
        organization: organization,
        metadata: { object: complex_object }
      )
      
      notification.save!
      # Complex objects should be converted to strings and truncated
      expect(notification.metadata["object"]).to be_a(String)
      expect(notification.metadata["object"].length).to be <= 100
    end
  end
end