# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReportMailer, type: :mailer do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }

  describe "security measures" do
    describe "#html_report" do
      it "sanitizes HTML content to prevent XSS attacks" do
        malicious_html = "<script>alert('xss')</script><p>Safe content</p>"
        
        mail = ReportMailer.with(
          user: user,
          organization: organization,
          subject: "Test Report",
          html_body: malicious_html,
          text_body: "Safe text"
        ).html_report

        expect(mail.body.to_s).not_to include("<script>")
        expect(mail.body.to_s).to include("Safe content")
      end

      it "sanitizes subject line" do
        malicious_subject = "<script>alert('xss')</script>Safe Subject"
        
        mail = ReportMailer.with(
          user: user,
          organization: organization,
          subject: malicious_subject,
          html_body: "Safe content",
          text_body: "Safe text"
        ).html_report

        expect(mail.subject).not_to include("<script>")
        expect(mail.subject).to include("Safe Subject")
      end
    end

    describe "#report_with_attachment" do
      it "validates PDF content" do
        invalid_pdf = "This is not a PDF"
        
        expect {
          ReportMailer.with(
            user: user,
            organization: organization,
            subject: "PDF Report",
            body: "Report with attachment",
            pdf_content: invalid_pdf,
            pdf_filename: "report.pdf"
          ).report_with_attachment.deliver_now
        }.to raise_error(ArgumentError, "Invalid PDF content")
      end

      it "accepts valid PDF content" do
        valid_pdf = "%PDF-1.4\n%Valid PDF content here"
        
        expect {
          ReportMailer.with(
            user: user,
            organization: organization,
            subject: "PDF Report",
            body: "Report with attachment",
            pdf_content: valid_pdf,
            pdf_filename: "report.pdf"
          ).report_with_attachment.deliver_now
        }.not_to raise_error
      end

      it "sanitizes filename to prevent path traversal" do
        malicious_filename = "../../../etc/passwd"
        
        mail = ReportMailer.with(
          user: user,
          organization: organization,
          subject: "Test Report",
          body: "Safe content",
          pdf_content: "%PDF-1.4\n%Valid PDF content",
          pdf_filename: malicious_filename
        ).report_with_attachment

        # Filename should be sanitized
        attachment = mail.attachments.first
        expect(attachment.filename).not_to include("../")
        expect(attachment.filename).to match(/\A[a-zA-Z0-9_.-]+\z/)
      end
    end

    describe "#presentation_delivery" do
      let(:temp_file) { Tempfile.new(['test', '.pdf']) }
      
      before do
        temp_file.write("%PDF-1.4\nValid PDF content")
        temp_file.close
        # Create allowed directory
        FileUtils.mkdir_p(Rails.root.join('tmp', 'presentations'))
      end
      
      after do
        temp_file.unlink
      end

      it "prevents path traversal attacks" do
        malicious_path = "/etc/passwd"
        
        expect {
          ReportMailer.with(
            user: user,
            organization: organization,
            subject: "Presentation",
            body: "Content",
            attachment_path: malicious_path,
            attachment_name: "presentation.pdf"
          ).presentation_delivery.deliver_now
        }.to raise_error(SecurityError, /File access denied/)
      end

      it "validates file size limits" do
        # Create a large file (simulate > 10MB)
        large_file = Tempfile.new(['large', '.pdf'])
        large_file.write('a' * (11 * 1024 * 1024)) # 11MB
        large_file.close
        
        expect {
          ReportMailer.with(
            user: user,
            organization: organization,
            subject: "Large File",
            body: "Content",
            attachment_path: large_file.path,
            attachment_name: "large.pdf"
          ).presentation_delivery.deliver_now
        }.to raise_error(ArgumentError, /File too large/)
        
        large_file.unlink
      end
    end

    describe "sanitization methods" do
      subject { ReportMailer.new }

      describe "#sanitize_html_content" do
        it "removes dangerous script tags" do
          dangerous_html = "<script>alert('xss')</script><p>Safe</p><style>body{}</style>"
          result = subject.send(:sanitize_html_content, dangerous_html)
          
          expect(result).not_to include("<script>")
          expect(result).not_to include("<style>")
          expect(result).to include("<p>Safe</p>")
        end

        it "allows safe HTML tags" do
          safe_html = "<h1>Title</h1><p><strong>Bold</strong> and <em>italic</em></p><ul><li>Item</li></ul>"
          result = subject.send(:sanitize_html_content, safe_html)
          
          expect(result).to include("<h1>Title</h1>")
          expect(result).to include("<strong>Bold</strong>")
          expect(result).to include("<em>italic</em>")
        end
      end

      describe "#sanitize_filename" do
        it "removes dangerous characters" do
          dangerous_name = "../../../evil<script>.pdf"
          result = subject.send(:sanitize_filename, dangerous_name)
          
          expect(result).not_to include("../")
          expect(result).not_to include("<")
          expect(result).not_to include(">")
        end

        it "limits filename length" do
          long_name = "a" * 200 + ".pdf"
          result = subject.send(:sanitize_filename, long_name)
          
          expect(result.length).to be <= 100
        end
      end

      describe "#validate_attachment_path!" do
        it "only allows files in allowed directories" do
          temp_dir = Rails.root.join('tmp', 'reports')
          FileUtils.mkdir_p(temp_dir)
          
          safe_file = temp_dir.join('test.pdf')
          File.write(safe_file, 'test content')
          
          expect {
            subject.send(:validate_attachment_path!, safe_file.to_s)
          }.not_to raise_error
          
          File.delete(safe_file)
        end
      end
    end
  end

  describe "email security headers" do
    it "includes security headers in emails" do
      mail = ReportMailer.with(
        user: user,
        organization: organization,
        subject: "Test",
        body: "Content"
      ).text_report

      expect(mail.header['X-Content-Type-Options'].to_s).to eq('nosniff')
      expect(mail.header['X-Frame-Options'].to_s).to eq('DENY')
      expect(mail.header['X-XSS-Protection'].to_s).to eq('1; mode=block')
    end
  end
end