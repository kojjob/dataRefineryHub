class Analytics::ProductsController < Analytics::BaseController
  before_action :set_date_range

  def index
    authorize :analytics, :index?

    @product_metrics = calculate_product_analytics
    @inventory_metrics = calculate_inventory_analytics
  end

  def performance
    authorize :analytics, :index?

    @product_performance = calculate_product_performance
    render json: @product_performance
  end

  def inventory
    authorize :analytics, :index?

    @inventory_analysis = calculate_inventory_analysis
    render json: @inventory_analysis
  end

  def recommendations
    authorize :analytics, :index?

    @product_recommendations = calculate_product_recommendations
    render json: @product_recommendations
  end

  private

  def set_date_range
    @date_range = params[:date_range] || "30_days"
    @start_date, @end_date = calculate_date_range(@date_range)
  end

  def calculate_product_analytics
    product_records = product_records_scope
    order_records = order_records_scope

    # Basic product metrics
    total_products = product_records.count
    published_products = product_records.where("raw_data->>'status' = ?", "active").count
    draft_products = product_records.where("raw_data->>'status' = ?", "draft").count

    # Product sales analysis from orders
    product_sales = {}
    total_product_revenue = 0

    order_records.find_each do |order|
      if order.raw_data["line_items"]
        order.raw_data["line_items"].each do |item|
          product_id = item.dig("product_id") || item.dig("variant", "product_id")
          next unless product_id

          quantity = item["quantity"].to_i
          price = item["price"].to_f
          revenue = quantity * price

          if product_sales[product_id]
            product_sales[product_id][:quantity] += quantity
            product_sales[product_id][:revenue] += revenue
            product_sales[product_id][:orders] += 1
          else
            product_sales[product_id] = {
              quantity: quantity,
              revenue: revenue,
              orders: 1,
              title: item.dig("title") || "Unknown Product"
            }
          end

          total_product_revenue += revenue
        end
      end
    end

    # Top performing products
    top_products_by_revenue = product_sales.sort_by { |_k, v| -v[:revenue] }.first(10).to_h
    top_products_by_quantity = product_sales.sort_by { |_k, v| -v[:quantity] }.first(10).to_h

    {
      total_products: total_products,
      published_products: published_products,
      draft_products: draft_products,
      products_sold: product_sales.length,
      total_quantity_sold: product_sales.values.sum { |p| p[:quantity] },
      total_product_revenue: total_product_revenue,
      avg_product_price: product_sales.values.any? ? (total_product_revenue / product_sales.values.sum { |p| p[:quantity] }).round(2) : 0,
      top_products_by_revenue: top_products_by_revenue,
      top_products_by_quantity: top_products_by_quantity
    }
  end

  def calculate_inventory_analytics
    product_records = product_records_scope

    # Inventory analysis
    total_inventory_value = 0
    low_stock_products = []
    out_of_stock_products = []
    inventory_levels = {}

    product_records.find_each do |product|
      if product.raw_data["variants"]
        product.raw_data["variants"].each do |variant|
          inventory_quantity = variant["inventory_quantity"].to_i
          price = variant["price"].to_f

          inventory_value = inventory_quantity * price
          total_inventory_value += inventory_value

          product_title = product.raw_data["title"]
          variant_title = variant["title"]
          full_title = variant_title.present? ? "#{product_title} - #{variant_title}" : product_title

          if inventory_quantity == 0
            out_of_stock_products << {
              title: full_title,
              sku: variant["sku"],
              price: price
            }
          elsif inventory_quantity <= 10 # Low stock threshold
            low_stock_products << {
              title: full_title,
              sku: variant["sku"],
              quantity: inventory_quantity,
              price: price
            }
          end

          # Group by inventory level ranges
          case inventory_quantity
          when 0
            inventory_levels["Out of Stock"] = (inventory_levels["Out of Stock"] || 0) + 1
          when 1..10
            inventory_levels["Low Stock (1-10)"] = (inventory_levels["Low Stock (1-10)"] || 0) + 1
          when 11..50
            inventory_levels["Medium Stock (11-50)"] = (inventory_levels["Medium Stock (11-50)"] || 0) + 1
          when 51..100
            inventory_levels["Good Stock (51-100)"] = (inventory_levels["Good Stock (51-100)"] || 0) + 1
          else
            inventory_levels["High Stock (100+)"] = (inventory_levels["High Stock (100+)"] || 0) + 1
          end
        end
      end
    end

    # Inventory turnover (would need historical data for accurate calculation)
    total_variants = product_records.joins("JOIN LATERAL jsonb_array_elements(raw_data->'variants') AS variant(data) ON true").count

    {
      total_inventory_value: total_inventory_value,
      total_variants: total_variants,
      out_of_stock_count: out_of_stock_products.length,
      low_stock_count: low_stock_products.length,
      out_of_stock_products: out_of_stock_products.first(20),
      low_stock_products: low_stock_products.first(20),
      inventory_distribution: inventory_levels,
      stock_health_score: calculate_stock_health_score(inventory_levels, total_variants)
    }
  end

  def calculate_product_performance
    order_records = order_records_scope

    # Detailed product performance analysis
    product_performance = {}

    order_records.find_each do |order|
      next unless order.raw_data["line_items"]

      order.raw_data["line_items"].each do |item|
        product_id = item.dig("product_id") || item.dig("variant", "product_id")
        next unless product_id

        quantity = item["quantity"].to_i
        price = item["price"].to_f
        revenue = quantity * price

        if product_performance[product_id]
          performance = product_performance[product_id]
          performance[:total_revenue] += revenue
          performance[:total_quantity] += quantity
          performance[:order_count] += 1
          performance[:prices] << price
        else
          product_performance[product_id] = {
            title: item["title"] || "Unknown Product",
            total_revenue: revenue,
            total_quantity: quantity,
            order_count: 1,
            prices: [ price ],
            category: item.dig("product", "product_type") || "Uncategorized",
            vendor: item.dig("product", "vendor") || "Unknown"
          }
        end
      end
    end

    # Calculate additional metrics for each product
    product_performance.each do |product_id, performance|
      avg_price = performance[:prices].sum / performance[:prices].length
      performance[:avg_price] = avg_price.round(2)
      performance[:avg_quantity_per_order] = (performance[:total_quantity].to_f / performance[:order_count]).round(1)
      performance[:revenue_per_order] = (performance[:total_revenue] / performance[:order_count]).round(2)

      # Remove prices array as it's no longer needed
      performance.delete(:prices)
    end

    # Performance categories
    performance_by_category = product_performance.values.group_by { |p| p[:category] }
      .transform_values { |products| products.sum { |p| p[:total_revenue] } }

    performance_by_vendor = product_performance.values.group_by { |p| p[:vendor] }
      .transform_values { |products| products.sum { |p| p[:total_revenue] } }

    {
      individual_performance: product_performance,
      performance_by_category: performance_by_category.sort_by { |_k, v| -v }.to_h,
      performance_by_vendor: performance_by_vendor.sort_by { |_k, v| -v }.first(10).to_h,
      top_performers: product_performance.sort_by { |_k, v| -v[:total_revenue] }.first(20).to_h,
      quantity_leaders: product_performance.sort_by { |_k, v| -v[:total_quantity] }.first(20).to_h
    }
  end

  def calculate_inventory_analysis
    product_records = product_records_scope

    # Advanced inventory analysis
    inventory_data = []
    category_inventory = {}
    vendor_inventory = {}

    product_records.find_each do |product|
      category = product.raw_data["product_type"] || "Uncategorized"
      vendor = product.raw_data["vendor"] || "Unknown"

      if product.raw_data["variants"]
        product.raw_data["variants"].each do |variant|
          inventory_quantity = variant["inventory_quantity"].to_i
          price = variant["price"].to_f
          inventory_value = inventory_quantity * price

          inventory_data << {
            product_title: product.raw_data["title"],
            variant_title: variant["title"],
            sku: variant["sku"],
            quantity: inventory_quantity,
            price: price,
            inventory_value: inventory_value,
            category: category,
            vendor: vendor,
            weight: variant["weight"].to_f
          }

          # Aggregate by category
          if category_inventory[category]
            category_inventory[category][:total_value] += inventory_value
            category_inventory[category][:total_quantity] += inventory_quantity
            category_inventory[category][:product_count] += 1
          else
            category_inventory[category] = {
              total_value: inventory_value,
              total_quantity: inventory_quantity,
              product_count: 1
            }
          end

          # Aggregate by vendor
          if vendor_inventory[vendor]
            vendor_inventory[vendor][:total_value] += inventory_value
            vendor_inventory[vendor][:total_quantity] += inventory_quantity
            vendor_inventory[vendor][:product_count] += 1
          else
            vendor_inventory[vendor] = {
              total_value: inventory_value,
              total_quantity: inventory_quantity,
              product_count: 1
            }
          end
        end
      end
    end

    # Calculate inventory insights
    total_inventory_value = inventory_data.sum { |item| item[:inventory_value] }
    dead_stock = inventory_data.select { |item| item[:quantity] > 100 && item[:inventory_value] > 1000 }

    {
      inventory_details: inventory_data.sort_by { |item| -item[:inventory_value] },
      category_breakdown: category_inventory.sort_by { |_k, v| -v[:total_value] }.to_h,
      vendor_breakdown: vendor_inventory.sort_by { |_k, v| -v[:total_value] }.to_h,
      total_inventory_value: total_inventory_value,
      dead_stock_candidates: dead_stock.first(20),
      avg_inventory_per_product: inventory_data.any? ? (inventory_data.sum { |item| item[:quantity] } / inventory_data.length).round(1) : 0
    }
  end

  def calculate_product_recommendations
    # This would integrate with sales data, inventory levels, and trends
    # to provide actionable recommendations

    product_performance = calculate_product_performance[:individual_performance]
    inventory_analysis = calculate_inventory_analytics

    recommendations = []

    # Identify products to restock
    inventory_analysis[:low_stock_products].each do |product|
      # Check if this product has good sales performance
      matching_performance = product_performance.values.find { |p| p[:title]&.include?(product[:title]) }

      if matching_performance && matching_performance[:total_revenue] > 100
        recommendations << {
          type: "restock",
          priority: "high",
          product: product[:title],
          reason: "Low stock on high-performing product",
          action: "Restock immediately",
          potential_lost_revenue: matching_performance[:revenue_per_order] * 10 # Estimate
        }
      end
    end

    # Identify products to discontinue
    product_performance.each do |product_id, performance|
      if performance[:total_revenue] < 50 && performance[:order_count] < 3
        recommendations << {
          type: "discontinue",
          priority: "medium",
          product: performance[:title],
          reason: "Poor sales performance",
          action: "Consider discontinuing or promoting",
          lost_investment: 0 # Would need cost data
        }
      end
    end

    # Identify trending products to promote
    top_performers = product_performance.sort_by { |_k, v| -v[:total_revenue] }.first(5)
    top_performers.each do |product_id, performance|
      if performance[:avg_quantity_per_order] > 2
        recommendations << {
          type: "promote",
          priority: "high",
          product: performance[:title],
          reason: "High conversion and quantity per order",
          action: "Increase marketing focus",
          potential_revenue: performance[:revenue_per_order] * 20 # Estimate
        }
      end
    end

    # Price optimization recommendations
    product_performance.each do |product_id, performance|
      if performance[:order_count] >= 5 && performance[:avg_quantity_per_order] > 1.5
        recommendations << {
          type: "price_optimization",
          priority: "medium",
          product: performance[:title],
          reason: "High demand suggests price elasticity",
          action: "Test price increase of 10-15%",
          potential_revenue: performance[:total_revenue] * 0.1 # Conservative estimate
        }
      end
    end

    {
      recommendations: recommendations.sort_by { |r| [ "high", "medium", "low" ].index(r[:priority]) },
      summary: {
        total_recommendations: recommendations.length,
        high_priority: recommendations.count { |r| r[:priority] == "high" },
        potential_revenue_impact: recommendations.sum { |r| r[:potential_revenue] || 0 }
      }
    }
  end

  def calculate_stock_health_score(inventory_levels, total_variants)
    return 0 if total_variants == 0

    # Weight different stock levels
    weights = {
      "Out of Stock" => -10,
      "Low Stock (1-10)" => -5,
      "Medium Stock (11-50)" => 5,
      "Good Stock (51-100)" => 10,
      "High Stock (100+)" => -2 # Too much stock can be problematic
    }

    total_score = inventory_levels.sum do |level, count|
      (weights[level] || 0) * count
    end

    # Normalize to 0-100 scale
    max_possible_score = total_variants * 10
    min_possible_score = total_variants * -10

    normalized_score = ((total_score - min_possible_score) / (max_possible_score - min_possible_score).to_f * 100).round(1)
    [ 0, [ 100, normalized_score ].min ].max
  end
end
