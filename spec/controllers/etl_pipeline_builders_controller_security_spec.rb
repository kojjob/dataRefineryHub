require 'rails_helper'

RSpec.describe EtlPipelineBuildersController, type: :request do
  let(:user) { create(:user, role: :admin) }
  let(:organization) { user.organization }
  let(:pipeline) { create(:pipeline, organization: organization, created_by: user) }
  
  before do
    sign_in user
  end
  
  describe "Security Tests" do
    describe "XXE Protection" do
      it "prevents XXE attacks in XML file uploads" do
        # Create malicious XML with external entity
        malicious_xml = <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE foo [
            <!ENTITY xxe SYSTEM "file:///etc/passwd">
          ]>
          <pipeline>
            <name>&xxe;</name>
            <pipeline_type>etl</pipeline_type>
          </pipeline>
        XML
        
        file = fixture_file_upload(
          StringIO.new(malicious_xml),
          'text/xml'
        )
        
        post :import_pipeline, params: { file: file }
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be_falsey
        expect(response).to have_http_status(:unprocessable_entity)
        
        # Ensure no pipeline was created with external entity content
        expect(Pipeline.where("name LIKE ?", "%root%")).to be_empty
        expect(Pipeline.where("name LIKE ?", "%passwd%")).to be_empty
      end
      
      it "safely parses valid XML files" do
        valid_xml = <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <pipeline>
            <name>Safe Pipeline</name>
            <pipeline_type>etl</pipeline_type>
          </pipeline>
        XML
        
        file = fixture_file_upload(
          StringIO.new(valid_xml),
          'text/xml'
        )
        
        expect {
          post :import_pipeline, params: { file: file }
        }.to change(Pipeline, :count).by(1)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be_truthy
      end
    end
    
    describe "File Upload Security" do
      it "rejects files larger than 10MB" do
        # Create a mock file that reports size > 10MB
        large_file = double("file")
        allow(large_file).to receive(:size).and_return(11.megabytes)
        allow(large_file).to receive(:present?).and_return(true)
        allow(large_file).to receive(:content_type).and_return("application/json")
        
        post :import_pipeline, params: { file: large_file }
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be_falsey
        expect(json_response['error']).to include("too large")
        expect(response).to have_http_status(:bad_request)
      end
      
      it "rejects unsupported file types" do
        file = fixture_file_upload(
          StringIO.new("malicious content"),
          'application/x-executable'
        )
        
        post :import_pipeline, params: { file: file }
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be_falsey
        expect(json_response['error']).to include("Invalid file type")
        expect(response).to have_http_status(:bad_request)
      end
      
      it "handles missing file gracefully" do
        post :import_pipeline, params: {}
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be_falsey
        expect(json_response['error']).to include("No file provided")
        expect(response).to have_http_status(:bad_request)
      end
    end
    
    describe "Input Validation" do
      describe "#available_extractors" do
        it "validates source_type parameter" do
          get :available_extractors, params: { source_type: "malicious_type" }
          
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq("Invalid source type")
          expect(response).to have_http_status(:bad_request)
        end
        
        it "accepts valid source types" do
          %w[database api cloud_storage streaming file_upload].each do |valid_type|
            get :available_extractors, params: { source_type: valid_type }
            expect(response).to have_http_status(:ok)
          end
        end
      end
      
      describe "#transformation_preview" do
        it "rejects invalid transformation types" do
          post :transformation_preview, params: {
            rule: {
              type: "malicious_code_injection",
              name: "Evil Transform"
            },
            sample_data: []
          }
          
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq("Invalid transformation type")
          expect(response).to have_http_status(:bad_request)
        end
        
        it "limits sample data size" do
          large_sample = Array.new(1001) { { id: 1 } }
          
          post :transformation_preview, params: {
            rule: {
              type: "field_mapping",
              name: "Test"
            },
            sample_data: large_sample
          }
          
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to include("too large")
          expect(response).to have_http_status(:bad_request)
        end
        
        it "accepts valid transformation rules" do
          allow_any_instance_of(TransformationRulesEngine).to receive(:apply_transformations)
            .and_return({ data: [], row_count: 0 })
          
          post :transformation_preview, params: {
            rule: {
              type: "field_mapping",
              name: "Valid Transform",
              config: { from: "old_field", to: "new_field" }
            },
            sample_data: [{ old_field: "value" }]
          }
          
          expect(response).to have_http_status(:ok)
        end
      end
    end
    
    describe "Mass Assignment Protection" do
      it "rejects unauthorized parameters in pipeline_params" do
        post :create, params: {
          pipeline: {
            name: "Test Pipeline",
            pipeline_type: "etl",
            source_config: {
              type: "database",
              connection_string: "valid",
              # These should be allowed
              database_name: "mydb",
              # This should be rejected
              malicious_param: "evil_value",
              admin_override: true
            },
            destination_config: {
              type: "warehouse",
              warehouse_id: "123",
              # This should be rejected
              bypass_security: true
            },
            # Try to inject unauthorized fields
            organization_id: 999,
            created_by_id: 999,
            status: "active"
          }
        }
        
        if Pipeline.last
          created_pipeline = Pipeline.last
          # Ensure malicious params were not saved
          expect(created_pipeline.source_config['malicious_param']).to be_nil
          expect(created_pipeline.source_config['admin_override']).to be_nil
          expect(created_pipeline.destination_config['bypass_security']).to be_nil
          # Ensure organization wasn't overridden
          expect(created_pipeline.organization_id).to eq(organization.id)
          expect(created_pipeline.created_by_id).to eq(user.id)
          # Status should be draft by default, not active
          expect(created_pipeline.status).to eq("draft")
        end
      end
    end
    
    describe "Error Message Sanitization" do
      it "sanitizes sensitive information from logs" do
        # Mock a database error with connection string
        allow_any_instance_of(Pipeline).to receive(:save).and_raise(
          StandardError.new("Connection failed: postgresql://user:secret123@localhost/db")
        )
        
        # Capture logs
        expect(Rails.logger).to receive(:error) do |message|
          expect(message).not_to include("secret123")
          expect(message).to include("[REDACTED]")
        end
        
        post :create, params: {
          pipeline: {
            name: "Test Pipeline",
            pipeline_type: "etl"
          }
        }
      end
      
      it "does not expose internal errors to users" do
        allow_any_instance_of(TransformationRulesEngine).to receive(:apply_transformations)
          .and_raise(StandardError.new("Internal database connection failed with credentials"))
        
        post :transformation_preview, params: {
          rule: { type: "field_mapping", name: "Test" },
          sample_data: []
        }
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).not_to include("database")
        expect(json_response['error']).not_to include("credentials")
        expect(json_response['error']).to eq("Transformation preview failed")
      end
    end
    
    describe "Security Headers" do
      it "sets security headers on responses" do
        get :index
        
        expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
        expect(response.headers['X-Frame-Options']).to eq('SAMEORIGIN')
        expect(response.headers['X-XSS-Protection']).to eq('1; mode=block')
        expect(response.headers['Referrer-Policy']).to eq('strict-origin-when-cross-origin')
        expect(response.headers['Permissions-Policy']).to include('geolocation=()')
        expect(response.headers['Content-Security-Policy']).to include("default-src 'self'")
      end
      
      it "sets HSTS header in production" do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
        
        get :index
        
        expect(response.headers['Strict-Transport-Security']).to include('max-age=31536000')
      end
    end
    
    describe "Authorization" do
      context "when user is not authenticated" do
        before { sign_out user }
        
        it "redirects to login for protected actions" do
          get :index
          expect(response).to redirect_to(new_user_session_path)
        end
        
        it "prevents access to sensitive actions" do
          post :execute, params: { id: pipeline.id }
          expect(response).to redirect_to(new_user_session_path)
        end
      end
      
      context "when user lacks permissions" do
        let(:viewer_user) { create(:user, organization: organization, role: :viewer) }
        
        before do
          sign_out user
          sign_in viewer_user
        end
        
        it "prevents unauthorized pipeline creation" do
          post :create, params: {
            pipeline: {
              name: "Unauthorized Pipeline",
              pipeline_type: "etl"
            }
          }
          
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to include("not authorized")
        end
        
        it "prevents unauthorized pipeline deletion" do
          delete :destroy, params: { id: pipeline.id }
          
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to include("not authorized")
        end
      end
    end
    
    describe "CSRF Protection" do
      it "is enabled for state-changing operations" do
        # CSRF protection is tested by Rails by default
        # This test verifies our controller inherits from ApplicationController
        # which has protect_from_forgery enabled
        expect(described_class.ancestors).to include(ApplicationController)
        expect(ApplicationController._process_action_callbacks.map(&:filter))
          .to include(:verify_authenticity_token)
      end
    end
  end
end