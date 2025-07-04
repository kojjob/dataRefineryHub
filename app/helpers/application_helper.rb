module ApplicationHelper
  def nav_link_classes(section)
    base_classes = "group flex gap-x-3 rounded-md p-2 text-sm leading-6 font-semibold"

    if current_page_section == section
      "#{base_classes} bg-gray-50 text-indigo-600"
    else
      "#{base_classes} text-gray-700 hover:text-indigo-600 hover:bg-gray-50"
    end
  end

  def enhanced_nav_link_classes(section)
    base_classes = "group flex items-center gap-x-4 rounded-2xl p-4 text-sm leading-6 font-bold transition-all duration-300 hover:bg-white/80 hover:backdrop-blur-sm hover:shadow-xl border border-transparent hover:border-gray-200/50 hover:-translate-y-0.5"

    if current_page_section == section
      "#{base_classes} bg-white/90 backdrop-blur-sm shadow-xl border-gray-200/60 text-gray-900 scale-105"
    else
      "#{base_classes} text-gray-700 hover:text-gray-900"
    end
  end

  def current_page_section
    # Determine current section based on controller and action
    case controller_name
    when "dashboard"
      if params[:anchor] == "data-quality"
        "data_quality"
      else
        "dashboard"
      end
    when "data_sources"
      "data_sources"
    when "extraction_jobs", "transformation_jobs"
      "pipelines"
    when "manual_tasks"
      "manual_tasks"
    when "analytics", "dashboards"
      "analytics"
    when "customers", "processed_customers"
      "customers"
    when "orders"
      "orders"
    when "products"
      "products"
    when "inventory"
      "inventory"
    when "reports"
      "reports"
    when "integrations"
      "integrations"
    when "teams", "users"
      "team"
    when "organizations"
      "organization"
    when "billing_subscriptions"
      "billing"
    else
      # Handle platform-specific sections
      case params[:platform] || request.path
      when /shopify/
        "shopify"
      when /woocommerce/
        "woocommerce"
      when /amazon/
        "amazon"
      else
        controller_name
      end
    end
  end

  def page_title(title = nil)
    if title
      content_for :page_title, title
    else
      content_for?(:page_title) ? content_for(:page_title) : "Dashboard"
    end
  end

  def breadcrumb_item(title, path = nil)
    content_for :breadcrumb do
      concat content_tag(:li, class: "flex items-center") do
        concat content_tag(:svg, class: "flex-shrink-0 h-5 w-5 text-gray-300", viewBox: "0 0 20 20", fill: "currentColor", "aria-hidden": "true") do
          concat content_tag(:path, "", "fill-rule": "evenodd", d: "M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z", "clip-rule": "evenodd")
        end
        if path
          concat link_to(title, path, class: "ml-2 text-sm font-medium text-gray-500 hover:text-gray-700")
        else
          concat content_tag(:span, title, class: "ml-2 text-sm font-medium text-gray-900")
        end
      end
    end
  end

  def get_ui_styling(category)
    case category.to_s
    when 'ecommerce'
      {
        border_color: 'border-green-200',
        bg_color: 'bg-green-50',
        text_color: 'text-green-700',
        icon_color: 'text-green-600'
      }
    when 'payments'
      {
        border_color: 'border-indigo-200',
        bg_color: 'bg-indigo-50',
        text_color: 'text-indigo-700',
        icon_color: 'text-indigo-600'
      }
    when 'accounting'
      {
        border_color: 'border-blue-200',
        bg_color: 'bg-blue-50',
        text_color: 'text-blue-700',
        icon_color: 'text-blue-600'
      }
    when 'analytics'
      {
        border_color: 'border-orange-200',
        bg_color: 'bg-orange-50',
        text_color: 'text-orange-700',
        icon_color: 'text-orange-500'
      }
    when 'manual'
      {
        border_color: 'border-gray-200',
        bg_color: 'bg-gray-50',
        text_color: 'text-gray-700',
        icon_color: 'text-gray-600'
      }
    when 'marketplace'
      {
        border_color: 'border-orange-200',
        bg_color: 'bg-orange-50',
        text_color: 'text-orange-700',
        icon_color: 'text-orange-600'
      }
    else
      {
        border_color: 'border-gray-200',
        bg_color: 'bg-gray-50',
        text_color: 'text-gray-700',
        icon_color: 'text-gray-600'
      }
    end
  end
end
