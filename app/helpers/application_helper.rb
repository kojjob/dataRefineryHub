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
    base_classes = "group flex items-center gap-x-3 rounded-xl p-3 text-sm leading-6 font-medium transition-all duration-200 hover:bg-white hover:shadow-md border border-transparent hover:border-gray-200"
    
    if current_page_section == section
      "#{base_classes} bg-white shadow-md border-gray-200 text-gray-900"
    else
      "#{base_classes} text-gray-700 hover:text-gray-900"
    end
  end

  def current_page_section
    # Determine current section based on controller and action
    case controller_name
    when 'dashboard'
      'dashboard'
    when 'data_sources'
      'data_sources'
    when 'extraction_jobs', 'transformation_jobs'
      'pipelines'
    when 'analytics', 'dashboards'
      'analytics'
    when 'customers', 'processed_customers'
      'customers'
    when 'orders'
      'orders'
    when 'products'
      'products'
    when 'inventory'
      'inventory'
    when 'reports'
      'reports'
    when 'integrations'
      'integrations'
    when 'teams', 'users'
      'team'
    when 'organizations'
      'organization'
    when 'billing_subscriptions'
      'billing'
    else
      # Handle platform-specific sections
      case params[:platform] || request.path
      when /shopify/
        'shopify'
      when /woocommerce/
        'woocommerce'
      when /amazon/
        'amazon'
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
end