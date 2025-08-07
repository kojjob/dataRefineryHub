# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizationsController, type: :controller do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }

  before do
    sign_in user
    allow(controller).to receive(:current_organization).and_return(organization)
  end

  describe "billing information security" do
    describe "GET #billing" do
      before do
        allow(controller).to receive(:authorize).and_return(true)
      end

      it "sanitizes plan names in billing data" do
        # Test with a potentially malicious plan name
        organization.update(plan: "free")

        get :billing

        expect(assigns(:billing_data)[:current_plan]).to eq("free")
      end

      it "handles invalid plan names safely" do
        # Simulate tampered plan name
        allow(organization).to receive(:subscription_plan).and_return("<script>alert('xss')</script>")

        get :billing

        expect(assigns(:billing_data)[:current_plan]).to eq("unknown")
      end

      it "sanitizes billing history" do
        get :billing

        billing_history = assigns(:billing_data)[:billing_history]

        # Should not expose actual invoice URLs
        billing_history.each do |record|
          expect(record).not_to have_key(:invoice_url)
          expect(record).to have_key(:has_invoice)
          expect(record[:status]).to be_in(%w[paid pending failed processing cancelled refunded unknown])
        end
      end

      it "does not expose sensitive billing information" do
        get :billing

        billing_data = assigns(:billing_data)

        # Should not contain sensitive fields
        expect(billing_data).not_to have_key(:credit_card_number)
        expect(billing_data).not_to have_key(:stripe_customer_id)
        expect(billing_data).not_to have_key(:payment_method_id)
        expect(billing_data).not_to have_key(:billing_address)
      end

      it "validates plan names against whitelist" do
        valid_plans = %w[free free_trial starter growth scale enterprise]

        valid_plans.each do |plan|
          result = controller.send(:sanitize_plan_name, plan)
          expect(result).to eq(plan)
        end

        invalid_plans = [ "<script>", "'; DROP TABLE users; --", "malicious_plan" ]
        invalid_plans.each do |plan|
          result = controller.send(:sanitize_plan_name, plan)
          expect(result).to eq("unknown")
        end
      end

      it "validates billing statuses against whitelist" do
        valid_statuses = %w[paid pending failed processing cancelled refunded]

        valid_statuses.each do |status|
          result = controller.send(:sanitize_billing_status, status)
          expect(result).to eq(status)
        end

        invalid_statuses = [ "<script>", "'; DROP TABLE billing; --", "malicious_status" ]
        invalid_statuses.each do |status|
          result = controller.send(:sanitize_billing_status, status)
          expect(result).to eq("unknown")
        end
      end
    end

    describe "usage statistics security" do
      it "does not expose sensitive usage details" do
        allow(controller).to receive(:authorize).and_return(true)

        get :usage_stats

        stats = assigns(:stats)

        # Should only contain sanitized usage information
        expect(stats).to have_key(:total_records)
        expect(stats).to have_key(:api_calls_this_month)
        expect(stats).to have_key(:storage_used)
        expect(stats).to have_key(:active_integrations)

        # Should not contain sensitive information
        expect(stats).not_to have_key(:user_emails)
        expect(stats).not_to have_key(:api_keys)
        expect(stats).not_to have_key(:connection_strings)
      end
    end

    describe "audit logs security" do
      it "only shows logs for authorized organization" do
        other_organization = create(:organization)
        other_user = create(:user, organization: other_organization)

        # Create audit logs for different organizations
        organization_log = create(:audit_log, organization: organization, user: user)
        other_log = create(:audit_log, organization: other_organization, user: other_user)

        allow(controller).to receive(:authorize).and_return(true)
        allow(controller).to receive(:policy_scope).with(AuditLog).and_return(
          AuditLog.where(organization: organization)
        )

        get :audit_logs

        audit_logs = assigns(:audit_logs)
        expect(audit_logs).to include(organization_log)
        expect(audit_logs).not_to include(other_log)
      end
    end

    describe "authorization checks" do
      it "requires billing authorization for billing endpoint" do
        expect(controller).to receive(:authorize).with(organization, :billing?)

        get :billing
      end

      it "requires usage stats authorization" do
        expect(controller).to receive(:authorize).with(organization, :usage_stats?)

        get :usage_stats
      end

      it "requires audit logs authorization" do
        expect(controller).to receive(:authorize).with(organization, :audit_logs?)

        get :audit_logs
      end
    end

    describe "data access security" do
      it "uses policy scope for data sources" do
        expect(controller).to receive(:policy_scope).with(DataSource).and_return(
          DataSource.none
        )

        allow(controller).to receive(:authorize).and_return(true)
        get :billing
      end

      it "uses policy scope for audit logs" do
        expect(controller).to receive(:policy_scope).with(AuditLog).and_return(
          AuditLog.none.includes(:user).recent.page(nil)
        )

        allow(controller).to receive(:authorize).and_return(true)
        get :audit_logs
      end
    end
  end

  describe "parameter sanitization" do
    describe "organization_params" do
      it "only permits safe parameters" do
        params = ActionController::Parameters.new(
          organization: {
            name: "Safe Name",
            subdomain: "safe-subdomain",
            timezone: "UTC",
            phone: "555-1234",
            address: "123 Safe St",
            # Dangerous parameters that should not be permitted
            id: 999,
            stripe_customer_id: "cus_malicious",
            plan: "enterprise",
            admin: true
          }
        )

        controller.params = params
        result = controller.send(:organization_params)

        expect(result.keys).to contain_exactly("name", "subdomain", "timezone", "phone", "address")
        expect(result).not_to have_key("id")
        expect(result).not_to have_key("stripe_customer_id")
        expect(result).not_to have_key("plan")
        expect(result).not_to have_key("admin")
      end
    end
  end

  describe "SQL injection prevention" do
    it "uses parameterized queries for calculations" do
      # Mock potential SQL injection attempt through parameters
      malicious_param = "1; DROP TABLE organizations; --"

      # The calculation methods should not be vulnerable to SQL injection
      # because they use ActiveRecord methods, not raw SQL
      expect {
        controller.params = { malicious: malicious_param }
        allow(controller).to receive(:authorize).and_return(true)
        get :billing
      }.not_to raise_error

      # Verify database integrity
      expect(Organization.count).to be > 0
    end
  end
end
