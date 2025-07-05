namespace :sample_data do
  desc "Generate sample data sources and ETL pipelines for testing"
  task generate: :environment do
    puts "🚀 Generating sample data sources and pipelines..."

    # Find or create a demo organization
    org = Organization.find_or_create_by!(name: "Demo Organization") do |o|
      o.plan = "growth"
      o.status = "active"
      o.timezone = "UTC"
    end

    # Create a demo user if needed
    user = User.find_or_create_by!(email: "demo@datarefinery.com") do |u|
      u.password = "demopassword123"
      u.first_name = "Demo"
      u.last_name = "User"
      u.organization = org
      u.role = "admin"
    end

    # Generate sample data
    generator = SampleDataGeneratorService.new(org)

    puts "\n📊 Creating sample data sources..."
    data_sources = generator.create_sample_data_sources
    data_sources.each do |ds|
      puts "  ✅ Created: #{ds.name} (#{ds.source_type})"
    end

    puts "\n🔄 Creating sample ETL pipelines..."
    pipelines = generator.create_sample_pipelines
    pipelines.each do |pipeline|
      puts "  ✅ Created: #{pipeline.name} (#{pipeline.pipeline_type})"

      # Create sample execution history
      generator.send(:create_sample_executions, pipeline)
      puts "     Added 10 sample executions"
    end

    puts "\n✨ Sample data generation complete!"
    puts "\nSummary:"
    puts "  - Organization: #{org.name}"
    puts "  - Data Sources: #{data_sources.count}"
    puts "  - Pipelines: #{pipelines.count}"
    puts "  - Total Executions: #{PipelineExecution.where(organization: org).count}"

    puts "\n🎯 You can now:"
    puts "  1. Visit the ETL Pipeline Builder at /etl_pipeline_builders"
    puts "  2. Monitor pipeline executions at /pipeline_monitoring"
    puts "  3. View data sources at /data_sources"
    puts "  4. Check the main dashboard at /dashboard"
  end

  desc "Generate sample CSV files for testing"
  task generate_csv_files: :environment do
    puts "📁 Generating sample CSV files..."

    sample_dir = Rails.root.join("tmp", "sample_data")
    FileUtils.mkdir_p(sample_dir)

    # 1. Sales transactions CSV
    sales_file = sample_dir.join("sales_transactions.csv")
    CSV.open(sales_file, "w") do |csv|
      csv << [ "transaction_id", "date", "customer_id", "product_id", "quantity", "unit_price", "total_amount", "payment_method", "status" ]

      5000.times do |i|
        csv << [
          "TXN-#{i + 1}",
          (Date.today - rand(0..365)).to_s,
          "CUST-#{rand(1..500)}",
          "PROD-#{rand(1..100)}",
          rand(1..10),
          (rand(10.0..500.0).round(2)),
          (rand(10.0..5000.0).round(2)),
          [ "credit_card", "debit_card", "paypal", "cash" ].sample,
          [ "completed", "pending", "refunded" ].sample
        ]
      end
    end
    puts "  ✅ Created: #{sales_file} (5,000 records)"

    # 2. Customer data CSV
    customers_file = sample_dir.join("customers.csv")
    CSV.open(customers_file, "w") do |csv|
      csv << [ "customer_id", "email", "first_name", "last_name", "phone", "city", "state", "country", "signup_date", "lifetime_value" ]

      1000.times do |i|
        csv << [
          "CUST-#{i + 1}",
          "customer#{i + 1}@example.com",
          Faker::Name.first_name,
          Faker::Name.last_name,
          Faker::PhoneNumber.phone_number,
          Faker::Address.city,
          Faker::Address.state_abbr,
          "USA",
          (Date.today - rand(0..730)).to_s,
          (rand(0.0..10000.0).round(2))
        ]
      end
    end
    puts "  ✅ Created: #{customers_file} (1,000 records)"

    # 3. Product catalog CSV
    products_file = sample_dir.join("products.csv")
    CSV.open(products_file, "w") do |csv|
      csv << [ "product_id", "sku", "name", "category", "subcategory", "price", "cost", "stock_quantity", "reorder_point", "supplier" ]

      200.times do |i|
        category = [ "Electronics", "Clothing", "Home & Garden", "Sports", "Books" ].sample
        csv << [
          "PROD-#{i + 1}",
          "SKU-#{i + 1}",
          Faker::Commerce.product_name,
          category,
          Faker::Commerce.department(max: 1),
          (rand(10.0..500.0).round(2)),
          (rand(5.0..250.0).round(2)),
          rand(0..1000),
          rand(10..100),
          Faker::Company.name
        ]
      end
    end
    puts "  ✅ Created: #{products_file} (200 records)"

    # 4. Marketing campaigns CSV
    campaigns_file = sample_dir.join("marketing_campaigns.csv")
    CSV.open(campaigns_file, "w") do |csv|
      csv << [ "campaign_id", "name", "channel", "start_date", "end_date", "budget", "spent", "impressions", "clicks", "conversions", "revenue" ]

      50.times do |i|
        start_date = Date.today - rand(30..365)
        csv << [
          "CAMP-#{i + 1}",
          "#{[ 'Summer', 'Winter', 'Spring', 'Fall' ].sample} #{[ 'Sale', 'Promotion', 'Launch', 'Clearance' ].sample} #{i + 1}",
          [ "email", "social_media", "search", "display", "affiliate" ].sample,
          start_date.to_s,
          (start_date + rand(7..60)).to_s,
          (rand(1000.0..50000.0).round(2)),
          (rand(800.0..45000.0).round(2)),
          rand(10000..1000000),
          rand(100..50000),
          rand(10..5000),
          (rand(1000.0..100000.0).round(2))
        ]
      end
    end
    puts "  ✅ Created: #{campaigns_file} (50 records)"

    puts "\n📊 Sample CSV files generated in: #{sample_dir}"
  end

  desc "Clean up all sample data"
  task cleanup: :environment do
    puts "🧹 Cleaning up sample data..."

    org = Organization.find_by(name: "Demo Organization")

    if org
      # Delete in correct order to respect foreign keys
      PipelineExecution.where(organization: org).destroy_all
      puts "  ✅ Deleted pipeline executions"

      PipelineConfiguration.where(organization: org).destroy_all
      puts "  ✅ Deleted pipeline configurations"

      DataSource.where(organization: org).destroy_all
      puts "  ✅ Deleted data sources"

      User.where(email: "demo@datarefinery.com").destroy_all
      puts "  ✅ Deleted demo user"

      org.destroy
      puts "  ✅ Deleted demo organization"
    else
      puts "  ℹ️  No demo organization found"
    end

    # Clean up sample files
    sample_dir = Rails.root.join("tmp", "sample_data")
    if Dir.exist?(sample_dir)
      FileUtils.rm_rf(sample_dir)
      puts "  ✅ Deleted sample CSV files"
    end

    puts "\n✨ Cleanup complete!"
  end

  desc "Generate and seed test data for all models"
  task seed_all: :environment do
    Rake::Task["sample_data:generate_csv_files"].invoke
    Rake::Task["sample_data:generate"].invoke

    puts "\n🎉 All sample data has been generated!"
  end
end
