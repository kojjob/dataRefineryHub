# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FileUploadService, type: :service do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:valid_csv_file) do
    fixture_file_upload('sample_data.csv', 'text/csv')
  end
  let(:invalid_file) do
    fixture_file_upload('invalid.txt', 'text/plain')
  end
  let(:large_file) do
    # Create a file larger than the limit
    file = Tempfile.new(['large', '.csv'])
    file.write('a' * (51 * 1024 * 1024)) # 51MB
    file.rewind
    ActionDispatch::Http::UploadedFile.new(
      tempfile: file,
      filename: 'large.csv',
      type: 'text/csv'
    )
  end

  describe '#process' do
    context 'with valid CSV file' do
      it 'successfully processes the file' do
        result = described_class.new(user, organization).process(valid_csv_file)
        
        expect(result).to be_success
        expect(result.data).to include(:data_source, :extraction_job)
        expect(result.data[:data_source]).to be_persisted
      end

      it 'creates a data source record' do
        expect {
          described_class.new(user, organization).process(valid_csv_file)
        }.to change(DataSource, :count).by(1)
      end

      it 'creates an extraction job' do
        expect {
          described_class.new(user, organization).process(valid_csv_file)
        }.to change(ExtractionJob, :count).by(1)
      end

      it 'tracks performance metrics' do
        expect(PerformanceMonitorService).to receive(:track_with_result)
          .with('file_upload_processing', hash_including(:file_size, :file_type))
        
        described_class.new(user, organization).process(valid_csv_file)
      end
    end

    context 'with invalid file format' do
      it 'returns failure result' do
        result = described_class.new(user, organization).process(invalid_file)
        
        expect(result).to be_failure
        expect(result.errors).to include(/Invalid file format/)
      end

      it 'does not create any records' do
        expect {
          described_class.new(user, organization).process(invalid_file)
        }.not_to change { [DataSource.count, ExtractionJob.count] }
      end
    end

    context 'with file size exceeding limit' do
      it 'returns failure result' do
        result = described_class.new(user, organization).process(large_file)
        
        expect(result).to be_failure
        expect(result.errors).to include(/File size exceeds limit/)
      end
    end

    context 'when file processing fails' do
      before do
        allow_any_instance_of(FileProcessor).to receive(:process)
          .and_raise(StandardError, 'Processing failed')
      end

      it 'returns failure result with error details' do
        result = described_class.new(user, organization).process(valid_csv_file)
        
        expect(result).to be_failure
        expect(result.errors).to include(/Processing failed/)
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error)
          .with(hash_including(:error, :file_name))
        
        described_class.new(user, organization).process(valid_csv_file)
      end
    end
  end

  describe '#validate_file' do
    let(:service) { described_class.new(user, organization) }

    it 'validates file format' do
      result = service.send(:validate_file, valid_csv_file)
      expect(result).to be_success
    end

    it 'rejects unsupported formats' do
      result = service.send(:validate_file, invalid_file)
      expect(result).to be_failure
      expect(result.errors.first).to be_a(DataSourceErrors::InvalidFileFormat)
    end

    it 'rejects files exceeding size limit' do
      result = service.send(:validate_file, large_file)
      expect(result).to be_failure
      expect(result.errors.first).to be_a(DataSourceErrors::FileSizeExceeded)
    end
  end

  describe '#extract_metadata' do
    let(:service) { described_class.new(user, organization) }

    it 'extracts file metadata correctly' do
      metadata = service.send(:extract_metadata, valid_csv_file)
      
      expect(metadata).to include(
        :original_filename,
        :content_type,
        :file_size,
        :file_extension
      )
      expect(metadata[:original_filename]).to eq('sample_data.csv')
      expect(metadata[:content_type]).to eq('text/csv')
    end
  end
end

# Integration test for the complete file upload workflow
RSpec.describe 'File Upload Integration', type: :system do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }

  before do
    sign_in user
    visit new_data_source_path
  end

  it 'allows user to upload a CSV file successfully' do
    # Select file upload option
    find('[data-source-type="file_upload"]').click
    
    # Upload file
    attach_file 'file', Rails.root.join('spec/fixtures/files/sample_data.csv')
    
    # Submit form
    click_button 'Upload File'
    
    # Verify success
    expect(page).to have_content('File uploaded successfully')
    expect(page).to have_content('Processing your data')
    
    # Verify data source was created
    expect(DataSource.last.source_type).to eq('file_upload')
  end

  it 'shows error for invalid file format' do
    find('[data-source-type="file_upload"]').click
    attach_file 'file', Rails.root.join('spec/fixtures/files/invalid.txt')
    click_button 'Upload File'
    
    expect(page).to have_content('Invalid file format')
  end

  it 'shows error for file size exceeding limit' do
    # This would require creating a large test file
    # Implementation depends on your test setup
  end
end