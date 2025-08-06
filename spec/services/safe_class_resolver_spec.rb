require 'rails_helper'

RSpec.describe SafeClassResolver do
  describe 'Security Tests' do
    it 'resolves whitelisted classes' do
      # Test with a class we know should be in the whitelist
      result = SafeClassResolver.resolve('User')
      expect(result).to eq(User)
    end
    
    it 'prevents unauthorized class resolution' do
      expect {
        SafeClassResolver.resolve!('File')
      }.to raise_error(SafeClassResolver::UnauthorizedClassError, /not authorized/)
    end
    
    it 'prevents system class access' do
      dangerous_classes = ['Kernel', 'Process', 'IO', 'File', 'Dir', 'System']
      
      dangerous_classes.each do |class_name|
        expect {
          SafeClassResolver.resolve!(class_name)
        }.to raise_error(SafeClassResolver::UnauthorizedClassError)
      end
    end
    
    it 'returns nil instead of raising when raise_on_error is false' do
      result = SafeClassResolver.resolve('DangerousClass', raise_on_error: false)
      expect(result).to be_nil
    end
    
    it 'checks authorization correctly' do
      expect(SafeClassResolver.authorized?('User')).to be_truthy
      expect(SafeClassResolver.authorized?('File')).to be_falsey
    end
    
    it 'handles namespace resolution safely' do
      # Test that even with namespace option, unauthorized classes are blocked
      expect {
        SafeClassResolver.resolve!('File', namespace: 'System')
      }.to raise_error(SafeClassResolver::UnauthorizedClassError)
    end
    
    it 'normalizes class names properly' do
      expect(SafeClassResolver.resolve('::User')).to eq(User)
    end
  end
end