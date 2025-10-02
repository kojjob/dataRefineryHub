# frozen_string_literal: true

module NavigationHelper
  # SEO-optimized main navigation with structured internal linking
  def main_navigation_links
    [
      {
        text: "Solutions",
        url: "#",
        dropdown: [
          {
            text: "Business Intelligence Platform",
            url: business_intelligence_platform_path,
            description: "Complete BI solution for data-driven decisions"
          },
          {
            text: "ETL Pipeline Tool", 
            url: etl_pipeline_tool_path,
            description: "No-code data integration and transformation"
          },
          {
            text: "Analytics Dashboard",
            url: data_analytics_dashboard_path,
            description: "Real-time dashboards and visualizations"
          },
          {
            text: "Small Business Analytics",
            url: small_business_analytics_path,
            description: "Affordable analytics for growing SMBs"
          },
          {
            text: "Data Integration",
            url: data_integration_platform_path,
            description: "Connect all your business tools"
          }
        ]
      },
      {
        text: "Resources",
        url: "#",
        dropdown: [
          {
            text: "Blog",
            url: blog_index_path,
            description: "Expert insights on business intelligence"
          },
          {
            text: "Case Studies",
            url: blog_category_path("case-studies"),
            description: "Real customer success stories"
          },
          {
            text: "Best Practices",
            url: blog_category_path("best-practices"),
            description: "Industry best practices and guides"
          },
          {
            text: "Documentation",
            url: "#docs",
            description: "Complete platform documentation"
          }
        ]
      },
      {
        text: "Company",
        url: "#",
        dropdown: [
          {
            text: "About Us",
            url: about_path,
            description: "Our mission to democratize data analytics"
          },
          {
            text: "Contact",
            url: "#contact",
            description: "Get in touch with our team"
          }
        ]
      }
    ]
  end

  # SEO footer navigation with topic clusters
  def footer_navigation_links
    {
      "Solutions" => [
        { text: "Business Intelligence Platform", url: business_intelligence_platform_path },
        { text: "ETL Pipeline Tool", url: etl_pipeline_tool_path },
        { text: "Data Analytics Dashboard", url: data_analytics_dashboard_path },
        { text: "Small Business Analytics", url: small_business_analytics_path },
        { text: "Data Integration Platform", url: data_integration_platform_path }
      ],
      "Industries" => [
        { text: "E-commerce Analytics", url: blog_post_path("shopify-analytics-guide") },
        { text: "SaaS Analytics", url: "#saas-analytics" },
        { text: "Retail Analytics", url: "#retail-analytics" },
        { text: "Marketing Analytics", url: "#marketing-analytics" }
      ],
      "Resources" => [
        { text: "Blog", url: blog_index_path },
        { text: "Business Intelligence", url: blog_category_path("business-intelligence") },
        { text: "ETL Best Practices", url: blog_category_path("etl") },
        { text: "Data Visualization", url: blog_category_path("data-visualization") },
        { text: "Case Studies", url: blog_category_path("case-studies") }
      ],
      "Company" => [
        { text: "About", url: about_path },
        { text: "Contact", url: "#contact" },
        { text: "Privacy Policy", url: "#privacy" },
        { text: "Terms of Service", url: "#terms" }
      ]
    }
  end

  # Generate breadcrumb navigation for SEO
  def breadcrumb_navigation(breadcrumbs)
    content_tag :nav, class: "breadcrumb-nav", "aria-label" => "Breadcrumb" do
      content_tag :ol, class: "breadcrumb-list" do
        breadcrumbs.map.with_index do |crumb, index|
          content_tag :li, class: "breadcrumb-item" do
            if index == breadcrumbs.length - 1
              content_tag :span, crumb[:name], class: "breadcrumb-current"
            else
              safe_join([
                link_to(crumb[:name], crumb[:url], class: "breadcrumb-link"),
                content_tag(:span, "/", class: "breadcrumb-separator")
              ])
            end
          end
        end.join.html_safe
      end
    end
  end

  # Internal linking suggestions for content
  def contextual_internal_links(current_page_category = nil)
    links = case current_page_category
    when "business-intelligence"
      [
        { 
          text: "ETL Pipeline Best Practices for BI",
          url: blog_post_path("etl-pipeline-best-practices-2025"),
          anchor: "Learn how to build reliable data pipelines"
        },
        {
          text: "Dashboard Design Principles",
          url: blog_post_path("dashboard-design-principles"),
          anchor: "Create dashboards that drive action"
        }
      ]
    when "etl"
      [
        {
          text: "Business Intelligence Platform Guide",
          url: blog_post_path("complete-guide-business-intelligence-smbs"),
          anchor: "Complete BI implementation guide"
        },
        {
          text: "Data Quality Framework",
          url: blog_post_path("data-quality-framework"),
          anchor: "Ensure high-quality data in your pipelines"
        }
      ]
    else
      popular_internal_links
    end

    content_tag :div, class: "contextual-links" do
      content_tag :h3, "Related Articles", class: "contextual-links-title" do
        safe_join(
          links.map do |link|
            content_tag :div, class: "contextual-link-item" do
              safe_join([
                link_to(link[:text], link[:url], class: "contextual-link-title"),
                content_tag(:p, link[:anchor], class: "contextual-link-description")
              ])
            end
          end
        )
      end
    end
  end

  # Popular pages for internal linking
  def popular_internal_links
    [
      {
        text: "Business Intelligence Platform",
        url: business_intelligence_platform_path,
        anchor: "Complete BI solution for growing businesses"
      },
      {
        text: "ETL Pipeline Tool",
        url: etl_pipeline_tool_path,
        anchor: "Build data pipelines without code"
      },
      {
        text: "Small Business Analytics Guide", 
        url: small_business_analytics_path,
        anchor: "Analytics software designed for SMBs"
      }
    ]
  end

  # Topic cluster navigation
  def topic_cluster_nav(main_topic)
    clusters = {
      "business_intelligence" => {
        pillar: {
          text: "Business Intelligence Platform",
          url: business_intelligence_platform_path
        },
        supporting: [
          { text: "BI for Small Businesses", url: small_business_analytics_path },
          { text: "Dashboard Analytics", url: data_analytics_dashboard_path },
          { text: "BI Best Practices", url: blog_category_path("business-intelligence") }
        ]
      },
      "etl" => {
        pillar: {
          text: "ETL Pipeline Tool", 
          url: etl_pipeline_tool_path
        },
        supporting: [
          { text: "Data Integration Platform", url: data_integration_platform_path },
          { text: "ETL Best Practices", url: blog_post_path("etl-pipeline-best-practices-2025") },
          { text: "Data Quality Guide", url: blog_post_path("data-quality-framework") }
        ]
      }
    }

    cluster = clusters[main_topic.to_s]
    return unless cluster

    content_tag :div, class: "topic-cluster-nav" do
      safe_join([
        content_tag(:div, class: "pillar-page") do
          link_to cluster[:pillar][:text], cluster[:pillar][:url], class: "pillar-link"
        end,
        content_tag(:div, class: "supporting-pages") do
          cluster[:supporting].map do |page|
            link_to page[:text], page[:url], class: "supporting-link"
          end.join(" • ").html_safe
        end
      ])
    end
  end

  # Structured navigation for mobile SEO
  def mobile_navigation_menu
    content_tag :div, class: "mobile-nav", id: "mobile-navigation" do
      safe_join([
        content_tag(:div, class: "mobile-nav-header") do
          safe_join([
            content_tag(:h3, "Navigation", class: "mobile-nav-title"),
            content_tag(:button, "×", class: "mobile-nav-close", data: { action: "click->mobile-nav#close" })
          ])
        end,
        content_tag(:div, class: "mobile-nav-content") do
          main_navigation_links.map do |section|
            content_tag :div, class: "mobile-nav-section" do
              safe_join([
                content_tag(:h4, section[:text], class: "mobile-nav-section-title"),
                if section[:dropdown]
                  content_tag(:ul, class: "mobile-nav-links") do
                    section[:dropdown].map do |link|
                      content_tag :li do
                        safe_join([
                          link_to(link[:text], link[:url], class: "mobile-nav-link"),
                          content_tag(:span, link[:description], class: "mobile-nav-description")
                        ])
                      end
                    end.join.html_safe
                  end
                else
                  link_to(section[:text], section[:url], class: "mobile-nav-main-link")
                end
              ])
            end
          end.join.html_safe
        end
      ])
    end
  end
end