require 'rails_helper'

RSpec.describe SafeExpressionEvaluator do
  describe 'Security Tests' do
    it 'safely evaluates arithmetic expressions' do
      result = SafeExpressionEvaluator.evaluate('2 + 3 * 4')
      expect(result).to eq(14)
    end

    it 'evaluates expressions with variables' do
      context = { 'price' => 100, 'tax_rate' => 0.1 }
      result = SafeExpressionEvaluator.evaluate('{price} * (1 + {tax_rate})', context)
      expect(result).to eq(110.0)
    end

    it 'prevents code injection through eval()' do
      malicious_code = 'system("rm -rf /")'

      expect {
        SafeExpressionEvaluator.evaluate(malicious_code)
      }.to raise_error(SafeExpressionEvaluator::ExpressionError)
    end

    it 'prevents code injection through function calls' do
      malicious_code = 'File.delete("/etc/passwd")'

      expect {
        SafeExpressionEvaluator.evaluate(malicious_code)
      }.to raise_error(SafeExpressionEvaluator::ExpressionError)
    end

    it 'only allows whitelisted functions' do
      expect(SafeExpressionEvaluator.evaluate('abs(-5)')).to eq(5)
      expect(SafeExpressionEvaluator.evaluate('round(3.14159, 2)')).to eq(3.14)

      expect {
        SafeExpressionEvaluator.evaluate('eval("malicious code")')
      }.to raise_error(SafeExpressionEvaluator::ExpressionError)
    end

    it 'handles division by zero safely' do
      expect {
        SafeExpressionEvaluator.evaluate('5 / 0')
      }.to raise_error(SafeExpressionEvaluator::ExpressionError, /Division by zero/)
    end

    it 'validates input characters' do
      expect {
        SafeExpressionEvaluator.evaluate('2 + 3; system("whoami")')
      }.to raise_error(SafeExpressionEvaluator::ExpressionError)
    end
  end
end
