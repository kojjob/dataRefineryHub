class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"

  # Add security headers to all emails
  before_action :add_security_headers

  private

  def add_security_headers
    # Add email security headers to prevent client-side attacks
    headers["X-Content-Type-Options"] = "nosniff"
    headers["X-Frame-Options"] = "DENY"
    headers["X-XSS-Protection"] = "1; mode=block"
    headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

    # Content Security Policy for emails (limited support but good practice)
    headers["Content-Security-Policy"] = "default-src 'none'; img-src 'self' data: https:; style-src 'unsafe-inline'"

    # Prevent automatic email processing/parsing by untrusted clients
    headers["X-Auto-Response-Suppress"] = "All"
    headers["X-Mailer-Type"] = "Rails Application"
  end
end
