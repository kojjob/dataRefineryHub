require 'rails_helper'

RSpec.describe DataSourcesController, type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization: organization) }
  let(:data_source) { create(:data_source, organization: organization) }

  before do
    sign_in user
    allow(PerformanceMonitorService.instance).to receive(:track).and_yield
  end

  describe 'GET /data_sources' do
    it 'returns a successful response' do
      get '/data_sources'
      expect(response).to be_successful
    end

    it 'assigns data sources by status' do
      connected_source = create(:data_source, organization: organization, status: 'connected')
      syncing_source = create(:data_source, organization: organization, status: 'syncing')
      
      get '/data_sources'
      expect(response).to be_successful
    end
  end

  describe 'GET /data_sources/new' do
    it 'returns a successful response' do
      get '/data_sources/new'
      expect(response).to be_successful
    end
  end

  describe 'POST /data_sources' do
    let(:valid_attributes) do
      {
        name: 'Test Data Source',
        source_type: 'shopify',
        description: 'Test description',
        sync_frequency: 'daily'
      }
    end

    context 'with valid parameters' do
      it 'creates a new data source' do
        expect {
          post '/data_sources', params: { data_source: valid_attributes }
        }.to change(DataSource, :count).by(1)
      end

      it 'tracks performance for data source creation' do
        expect(PerformanceMonitorService.instance).to receive(:track).with('data_source_creation')
        post '/data_sources', params: { data_source: valid_attributes }
      end

      it 'redirects to the created data source' do
        post '/data_sources', params: { data_source: valid_attributes }
        expect(response).to redirect_to(DataSource.last)
      end
    end

    context 'with file upload' do
      let(:file_upload_attributes) do
        valid_attributes.merge(
          source_type: 'file_upload',
          uploaded_files: [fixture_file_upload('test_data.csv', 'text/csv')]
        )
      end

      before do
        allow(EnhancedFileUploadService).to receive(:new).and_return(
          double('service', process: Result.success(message: 'Files processed successfully'))
        )
      end

      it 'uses EnhancedFileUploadService for file processing' do
        expect(EnhancedFileUploadService).to receive(:new)
        post '/data_sources', params: { data_source: file_upload_attributes }
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) { { name: '' } }

      it 'does not create a new data source' do
        expect {
          post '/data_sources', params: { data_source: invalid_attributes }
        }.not_to change(DataSource, :count)
      end

      it 'renders the new template with unprocessable entity status' do
        post '/data_sources', params: { data_source: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'POST /data_sources/:id/process_files' do
    let(:uploaded_file) { fixture_file_upload('test_data.csv', 'text/csv') }

    context 'when file processing succeeds' do
      before do
        allow(EnhancedFileUploadService).to receive(:new).and_return(
          double('service', process: Result.success(message: 'Files processed successfully'))
        )
      end

      it 'processes files successfully' do
        post "/data_sources/#{data_source.id}/process_files", params: { files: [uploaded_file] }
        expect(response).to redirect_to(data_source_path(data_source))
        expect(flash[:notice]).to eq('Files processed successfully')
      end

      it 'tracks performance for file processing' do
        expect(PerformanceMonitorService.instance).to receive(:track).with('file_processing')
        post "/data_sources/#{data_source.id}/process_files", params: { files: [uploaded_file] }
      end
    end

    context 'when file processing fails' do
      before do
        allow(EnhancedFileUploadService).to receive(:new).and_return(
          double('service', process: Result.failure(error: 'Processing failed'))
        )
      end

      it 'handles processing failure' do
        post "/data_sources/#{data_source.id}/process_files", params: { files: [uploaded_file] }
        expect(response).to redirect_to(data_source_path(data_source))
        expect(flash[:alert]).to eq('Processing failed')
      end
    end

    context 'when no files are provided' do
      it 'returns error for missing files' do
        post "/data_sources/#{data_source.id}/process_files", params: { files: [] }
        expect(response).to redirect_to(data_source_path(data_source))
        expect(flash[:alert]).to eq('No files provided for processing')
      end
    end
  end

  describe 'POST /data_sources/test_connection' do
    context 'with valid shopify parameters' do
      let(:valid_params) do
        {
          source_type: 'shopify',
          api_key: 'test_api_key',
          shop_domain: 'test-shop.myshopify.com'
        }
      end

      it 'returns successful response for valid shopify connection' do
        post '/data_sources/test_connection', params: valid_params
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Connection test successful')
      end

      it 'filters out authenticity_token from parameters' do
        params_with_token = valid_params.merge(authenticity_token: 'fake_token')
        
        post '/data_sources/test_connection', params: params_with_token
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
      end
    end

    context 'with valid woocommerce parameters' do
      let(:valid_params) do
        {
          source_type: 'woocommerce',
          consumer_key: 'test_consumer_key',
          consumer_secret: 'test_consumer_secret'
        }
      end

      it 'returns successful response for valid woocommerce connection' do
        post '/data_sources/test_connection', params: valid_params
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Connection test successful')
      end
    end

    context 'with file_upload source type' do
      let(:valid_params) { { source_type: 'file_upload' } }

      it 'returns success for file upload source type' do
        post '/data_sources/test_connection', params: valid_params
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('File upload source is ready')
      end
    end

    context 'with unsupported source type' do
      let(:invalid_params) { { source_type: 'unsupported_type' } }

      it 'returns error for unsupported source type' do
        post '/data_sources/test_connection', params: invalid_params
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('Unsupported source type')
      end
    end

    context 'when connection test raises an exception' do
      let(:invalid_params) do
        {
          source_type: 'shopify',
          api_key: '',  # Empty API key should cause validation error
          shop_domain: 'test-shop.myshopify.com'
        }
      end

      it 'returns error response for invalid parameters' do
        post '/data_sources/test_connection', params: invalid_params
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['message']).to include('API key is required')
      end
    end

    context 'parameter filtering' do
      let(:params_with_extra_fields) do
        {
          source_type: 'shopify',
          api_key: 'test_api_key',
          shop_domain: 'test-shop.myshopify.com',
          authenticity_token: 'fake_token',
          controller: 'data_sources',
          action: 'test_connection',
          extra_param: 'should_be_filtered'
        }
      end

      it 'filters out Rails internal parameters and unpermitted parameters' do
        post '/data_sources/test_connection', params: params_with_extra_fields
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Connection test successful')
      end
    end
  end
end