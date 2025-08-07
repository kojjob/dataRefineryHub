#!/usr/bin/env ruby

# Simple test script to verify the IndustryTemplatesController fix
require_relative 'config/environment'

# Test the fixed generate_chart_data method
class TestIndustryTemplatesFix
  def self.run
    puts "Testing IndustryTemplatesController fix..."

    controller = IndustryTemplatesController.new

    # Get a sample template
    template = IndustryTemplate.find_template('retail_ecommerce')

    if template.nil?
      puts "❌ Template not found"
      return false
    end

    puts "✅ Template found: #{template[:name]}"

    begin
      # This should not raise a NoMethodError anymore
      chart_data = controller.send(:generate_chart_data, template)

      puts "✅ Chart data generated successfully"
      puts "📊 Generated #{chart_data.keys.size} charts:"

      chart_data.each do |chart_id, data|
        puts "  - #{chart_id}: #{data[:datasets]&.size || 0} datasets"
      end

      puts "\n🎉 Fix verified successfully! No NoMethodError occurred."
      true
    rescue => e
      puts "❌ Error occurred: #{e.class}: #{e.message}"
      puts e.backtrace.first(5)
      false
    end
  end
end

if __FILE__ == $0
  TestIndustryTemplatesFix.run
end
