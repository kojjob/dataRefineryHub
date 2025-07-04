module DataSourcesHelper
  # Get UI configuration for data source based on category and status
  def get_data_source_ui_config(category, status)
    base_config = {
      accent_color: get_accent_color_for_category(category),
      features: get_default_features_for_category(category)
    }
    
    # Add status-specific configurations
    case status
    when 'available'
      base_config.merge(
        status_class: 'border-green-200 bg-green-50',
        status_text_class: 'text-green-800'
      )
    when 'beta'
      base_config.merge(
        status_class: 'border-yellow-200 bg-yellow-50',
        status_text_class: 'text-yellow-800'
      )
    when 'coming_soon'
      base_config.merge(
        status_class: 'border-gray-200 bg-gray-50 opacity-60',
        status_text_class: 'text-gray-600'
      )
    else
      base_config
    end
  end

  # Get accent color based on category
  def get_accent_color_for_category(category)
    case category.to_s
    when 'ecommerce'
      'blue'
    when 'finance', 'accounting'
      'green'
    when 'marketing'
      'purple'
    when 'analytics'
      'orange'
    when 'file_upload'
      'gray'
    when 'crm'
      'indigo'
    when 'social'
      'pink'
    else
      'blue'
    end
  end

  # Get default features for category
  def get_default_features_for_category(category)
    case category.to_s
    when 'ecommerce'
      [
        'Orders & Customer Data',
        'Product & Inventory Sync',
        'Sales Analytics',
        'Real-time Updates'
      ]
    when 'finance', 'accounting'
      [
        'Financial Transactions',
        'Chart of Accounts',
        'Automated Reconciliation',
        'Tax-ready Reports'
      ]
    when 'marketing'
      [
        'Campaign Performance',
        'Audience Segmentation',
        'ROI Tracking',
        'Attribution Analysis'
      ]
    when 'analytics'
      [
        'Web Traffic Analysis',
        'Conversion Tracking',
        'User Behavior',
        'Goal Monitoring'
      ]
    when 'file_upload'
      [
        'Multiple File Formats',
        'Batch Processing',
        'Data Validation',
        'Automated Mapping'
      ]
    when 'crm'
      [
        'Contact Management',
        'Deal Pipeline',
        'Activity Tracking',
        'Lead Scoring'
      ]
    else
      [
        'Data Integration',
        'Automated Sync',
        'Quality Monitoring',
        'Secure Processing'
      ]
    end
  end

  # Render platform icon based on source type
  def render_platform_icon(source_type, css_classes = "w-6 h-6")
    case source_type.to_s
    when 'shopify'
      content_tag :svg, class: css_classes, fill: "currentColor", viewBox: "0 0 24 24" do
        content_tag :path, nil, d: "M15.8 2.1c-.8-.1-1.4.6-1.4 1.4v.1c0 .8-.7 1.5-1.5 1.5s-1.5-.7-1.5-1.5v-.1c0-.8-.6-1.5-1.4-1.4C8.6 2.2 7.5 3.4 7.5 4.8v14.4c0 1.4 1.1 2.6 2.5 2.8.8.1 1.4-.6 1.4-1.4v-.1c0-.8.7-1.5 1.5-1.5s1.5.7 1.5 1.5v.1c0 .8.6 1.5 1.4 1.4 1.4-.2 2.5-1.4 2.5-2.8V4.8c.1-1.4-1-2.6-2.3-2.7z"
      end
    when 'woocommerce'
      content_tag :svg, class: css_classes, fill: "currentColor", viewBox: "0 0 24 24" do
        content_tag :path, nil, d: "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"
      end
    when 'stripe'
      content_tag :svg, class: css_classes, fill: "currentColor", viewBox: "0 0 24 24" do
        content_tag :path, nil, d: "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.94-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"
      end
    when 'quickbooks'
      content_tag :svg, class: css_classes, fill: "currentColor", viewBox: "0 0 24 24" do
        content_tag :path, nil, d: "M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-5 14H7v-2h7v2zm3-4H7v-2h10v2zm0-4H7V7h10v2z"
      end
    when 'amazon_seller_central'
      content_tag :svg, class: css_classes, fill: "currentColor", viewBox: "0 0 24 24" do
        content_tag :path, nil, d: "M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"
      end
    when 'file_upload'
      content_tag :svg, class: css_classes, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" do
        content_tag :path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
      end
    when 'google_analytics'
      content_tag :svg, class: css_classes, fill: "currentColor", viewBox: "0 0 24 24" do
        content_tag :path, nil, d: "M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"
      end
    when 'mailchimp'
      content_tag :svg, class: css_classes, fill: "currentColor", viewBox: "0 0 24 24" do
        content_tag :path, nil, d: "M24 4.557c-.883.392-1.832.656-2.828.775 1.017-.609 1.798-1.574 2.165-2.724-.951.564-2.005.974-3.127 1.195-.897-.957-2.178-1.555-3.594-1.555-3.179 0-5.515 2.966-4.797 6.045-4.091-.205-7.719-2.165-10.148-5.144-1.29 2.213-.669 5.108 1.523 6.574-.806-.026-1.566-.247-2.229-.616-.054 2.281 1.581 4.415 3.949 4.89-.693.188-1.452.232-2.224.084.626 1.956 2.444 3.379 4.6 3.419-2.07 1.623-4.678 2.348-7.29 2.04 2.179 1.397 4.768 2.212 7.548 2.212 9.142 0 14.307-7.721 13.995-14.646.962-.695 1.797-1.562 2.457-2.549z"
      end
    when 'facebook'
      content_tag :svg, class: css_classes, fill: "currentColor", viewBox: "0 0 24 24" do
        content_tag :path, nil, d: "M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"
      end
    else
      content_tag :svg, class: css_classes, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" do
        content_tag :path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", "stroke-width": "2", d: "M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4"
      end
    end
  end

  # Format file size for display
  def format_file_size(bytes)
    return '0 B' if bytes.zero?
    
    units = ['B', 'KB', 'MB', 'GB', 'TB']
    exp = (Math.log(bytes) / Math.log(1024)).floor
    exp = [exp, units.length - 1].min
    
    "%.1f %s" % [bytes.to_f / 1024 ** exp, units[exp]]
  end

  # Get platform configuration template
  def get_platform_config_fields(source_type)
    case source_type.to_s
    when 'shopify'
      [
        {
          name: 'shop_domain',
          label: 'Shop Domain',
          type: 'text',
          placeholder: 'your-shop-name',
          suffix: '.myshopify.com',
          required: true,
          help: 'Your Shopify store domain (without .myshopify.com)'
        },
        {
          name: 'access_token',
          label: 'Access Token',
          type: 'password',
          placeholder: 'Enter your Shopify access token',
          required: true,
          help: 'Create a private app in your Shopify admin to get this token'
        }
      ]
    when 'stripe'
      [
        {
          name: 'secret_key',
          label: 'Secret Key',
          type: 'password',
          placeholder: 'sk_live_... or sk_test_...',
          required: true,
          help: 'Your Stripe secret API key from your dashboard'
        },
        {
          name: 'webhook_secret',
          label: 'Webhook Secret',
          type: 'password',
          placeholder: 'whsec_...',
          required: false,
          help: 'Optional: Webhook endpoint secret for real-time updates'
        }
      ]
    when 'quickbooks'
      [
        {
          name: 'client_id',
          label: 'Client ID',
          type: 'text',
          placeholder: 'Q0...',
          required: true,
          help: 'Your QuickBooks app Client ID'
        },
        {
          name: 'client_secret',
          label: 'Client Secret',
          type: 'password',
          placeholder: 'Enter client secret',
          required: true,
          help: 'Your QuickBooks app Client Secret'
        },
        {
          name: 'company_id',
          label: 'Company ID',
          type: 'text',
          placeholder: '123146096291789',
          required: true,
          help: 'Your QuickBooks Company ID (found in your app settings)'
        }
      ]
    when 'file_upload'
      []
    else
      []
    end
  end

  # Generate sample data for preview
  def generate_sample_data_for_platform(source_type)
    case source_type.to_s
    when 'shopify'
      {
        customers: [
          { id: '123', name: 'John Doe', email: 'john@example.com', total_spent: '$2,450.00' },
          { id: '124', name: 'Jane Smith', email: 'jane@example.com', total_spent: '$1,890.50' }
        ],
        orders: [
          { id: '#1001', date: '2024-06-20', customer: 'John Doe', total: '$125.99', status: 'fulfilled' },
          { id: '#1002', date: '2024-06-19', customer: 'Jane Smith', total: '$89.50', status: 'pending' }
        ]
      }
    when 'stripe'
      {
        payments: [
          { id: 'ch_123', amount: '$125.99', status: 'succeeded', customer: 'John Doe', date: '2024-06-20' },
          { id: 'ch_124', amount: '$89.50', status: 'succeeded', customer: 'Jane Smith', date: '2024-06-19' }
        ],
        customers: [
          { id: 'cus_123', name: 'John Doe', email: 'john@example.com', total_payments: '$2,450.00' }
        ]
      }
    when 'quickbooks'
      {
        invoices: [
          { id: '1', number: 'INV-001', customer: 'Acme Corp', amount: '$1,500.00', status: 'paid' },
          { id: '2', number: 'INV-002', customer: 'Beta LLC', amount: '$750.00', status: 'pending' }
        ],
        expenses: [
          { id: '1', vendor: 'Office Supplies Co', amount: '$245.50', category: 'Office Expenses' },
          { id: '2', vendor: 'Internet Provider', amount: '$99.99', category: 'Utilities' }
        ]
      }
    else
      {}
    end
  end
end
