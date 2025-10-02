require 'rails_helper'

RSpec.describe "DataSources", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization, password: 'password123', password_confirmation: 'password123', confirmed_at: Time.current) }

  before do
    # Use Warden to log in the user (works at Rack middleware level)
    login_as(user, scope: :user)
  end

  describe "GET /data_sources/new" do
    context "when user is authenticated" do
      it "returns http success" do
        get new_data_source_path
        expect(response).to have_http_status(:success)
      end

      it "assigns a new data source" do
        get new_data_source_path
        expect(assigns(:data_source)).to be_a_new(DataSource)
        expect(assigns(:data_source).organization).to eq(organization)
      end

      it "prepares wizard data via service" do
        get new_data_source_path
        expect(assigns(:wizard_data)).to be_present
        expect(assigns(:wizard_data)[:configurations]).to be_present
        expect(assigns(:wizard_data)[:sync_frequencies]).to be_present
      end

      it "pre-selects source type from params" do
        get new_data_source_path, params: { source_type: 'shopify' }
        expect(assigns(:data_source).source_type).to eq('shopify')
      end

      it "renders the new template" do
        get new_data_source_path
        expect(response).to render_template(:new)
      end
    end

    context "when user is not authenticated" do
      before do
        # Log out using Warden
        logout(:user)
      end

      it "redirects to sign in page" do
        get new_data_source_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /data_sources" do
    let(:valid_attributes) do
      {
        name: "Test Shopify Store",
        source_type: "shopify",
        sync_frequency: "daily"
      }
    end

    let(:invalid_attributes) do
      {
        name: "",
        source_type: "invalid_type"
      }
    end

    context "with valid parameters" do
      it "creates a new data source" do
        expect {
          post data_sources_path, params: { data_source: valid_attributes }
        }.to change(DataSource, :count).by(1)
      end

      it "associates data source with current organization" do
        post data_sources_path, params: { data_source: valid_attributes }
        expect(DataSource.last.organization).to eq(organization)
      end

      it "redirects to the created data source" do
        post data_sources_path, params: { data_source: valid_attributes }
        expect(response).to redirect_to(data_source_path(DataSource.last))
      end

      it "sets a success notice" do
        post data_sources_path, params: { data_source: valid_attributes }
        follow_redirect!
        expect(response.body).to include("successfully created")
      end

      it "tracks performance metrics" do
        expect(PerformanceMonitorService.instance).to receive(:track).with("data_source_creation").and_call_original
        post data_sources_path, params: { data_source: valid_attributes }
      end
    end

    context "with invalid parameters" do
      it "does not create a new data source" do
        expect {
          post data_sources_path, params: { data_source: invalid_attributes }
        }.to change(DataSource, :count).by(0)
      end

      it "renders the new template with unprocessable entity status" do
        post data_sources_path, params: { data_source: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
      end

      it "displays validation errors" do
        post data_sources_path, params: { data_source: invalid_attributes }
        expect(response.body).to include("can&#39;t be blank")
      end
    end

    context "with file upload source type" do
      let(:file_upload_attributes) do
        {
          name: "CSV Data Import",
          source_type: "file_upload",
          sync_frequency: "daily"
        }
      end

      let(:csv_file) do
        fixture_file_upload(Rails.root.join('spec/fixtures/files/sample_data.csv'), 'text/csv')
      end

      it "handles file upload creation via enhanced service" do
        post data_sources_path, params: {
          data_source: file_upload_attributes.merge(uploaded_files: [ csv_file ])
        }
        expect(response).to redirect_to(data_source_path(DataSource.last))
      end
    end

    context "authorization" do
      it "authorizes the user can create data sources" do
        expect_any_instance_of(DataSourcePolicy).to receive(:create?).and_call_original
        post data_sources_path, params: { data_source: valid_attributes }
      end
    end
  end

  describe "POST /data_sources/test_connection" do
    context "with Shopify connection" do
      let(:shopify_params) do
        {
          source_type: "shopify",
          shop_domain: "test-store",
          api_key: "test_api_key"
        }
      end

      it "returns success for valid Shopify credentials" do
        post test_connection_data_sources_path, params: shopify_params
        expect(response).to have_http_status(:success)

        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['message']).to be_present
      end

      it "validates shop domain format" do
        post test_connection_data_sources_path, params: shopify_params.merge(shop_domain: "invalid domain!")

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to include("Invalid")
      end

      it "requires api_key parameter" do
        post test_connection_data_sources_path, params: shopify_params.except(:api_key)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to include("API key is required")
      end
    end

    context "with WooCommerce connection" do
      let(:woocommerce_params) do
        {
          source_type: "woocommerce",
          consumer_key: "ck_test123",
          consumer_secret: "cs_test123"
        }
      end

      it "returns success for valid WooCommerce credentials" do
        post test_connection_data_sources_path, params: woocommerce_params
        expect(response).to have_http_status(:success)

        json = JSON.parse(response.body)
        expect(json['success']).to be true
      end

      it "requires consumer_key parameter" do
        post test_connection_data_sources_path, params: woocommerce_params.except(:consumer_key)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
      end
    end

    context "with file upload source" do
      it "returns success without connection test" do
        post test_connection_data_sources_path, params: { source_type: "file_upload" }

        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['message']).to include("File upload source is ready")
      end
    end

    context "with unsupported source type" do
      it "returns error for unsupported source" do
        post test_connection_data_sources_path, params: { source_type: "unknown_source" }

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to include("Unsupported")
      end
    end

    context "with connection errors" do
      before do
        allow_any_instance_of(DataSourcesController).to receive(:test_shopify_connection).and_raise(StandardError.new("Network timeout"))
      end

      it "handles exceptions gracefully" do
        post test_connection_data_sources_path, params: { source_type: "shopify", shop_domain: "test", api_key: "key" }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to include("Connection test failed")
      end
    end
  end

  describe "POST /data_sources/auto_save" do
    let(:draft_data) do
      {
        name: "Draft Data Source",
        source_type: "shopify",
        description: "Work in progress"
      }
    end

    it "saves draft to session" do
      post auto_save_data_sources_path, params: {
        data_source: draft_data,
        current_step: 2
      }

      expect(response).to have_http_status(:success)
      # Note: Request specs cannot directly access session
      # Session persistence is tested in integration specs
    end

    it "returns success JSON response" do
      post auto_save_data_sources_path, params: { data_source: draft_data }

      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['message']).to include("Draft saved successfully")
      expect(json['saved_at']).to be_present
    end

    it "updates timestamp on save" do
      post auto_save_data_sources_path, params: { data_source: draft_data }

      json = JSON.parse(response.body)
      expect(json['success']).to be true
      # Timestamp verified through JSON response
      expect(json['saved_at']).to be_present
    end

    it "handles save errors gracefully" do
      # Mock the session storage to fail only for the wizard draft key
      session_double = double("session")
      allow(session_double).to receive(:[]).and_return(nil)
      allow(session_double).to receive(:id).and_return("test_session_id")
      allow(session_double).to receive(:[]=) do |key, value|
        raise StandardError.new("Session error") if key == :data_source_wizard_draft
      end

      allow_any_instance_of(DataSourcesController).to receive(:session).and_return(session_double)

      post auto_save_data_sources_path, params: { data_source: draft_data }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
    end

    it "accepts valid draft data" do
      post auto_save_data_sources_path, params: { data_source: draft_data }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
    end
  end
end
