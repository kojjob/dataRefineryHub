# frozen_string_literal: true

class BlogController < ApplicationController
  before_action :set_blog_post, only: [:show]

  # Blog index page - SEO optimized
  def index
    @seo_data = {
      title: "DataReflow Blog - Business Intelligence & Analytics Insights",
      description: "Expert insights on business intelligence, data analytics, ETL pipelines, and data-driven decision making. Learn from industry experts and real case studies.",
      keywords: "business intelligence blog, data analytics insights, ETL best practices, data-driven decisions, analytics tutorials",
      canonical_url: blog_index_url,
      og_type: "website",
      og_image: "https://via.placeholder.com/1200x630/1f2937/ffffff?text=DataReflow+Blog"
    }

    @featured_posts = featured_blog_posts
    @recent_posts = recent_blog_posts
    @categories = blog_categories
    @popular_posts = popular_blog_posts
    
    @breadcrumbs = [
      { name: "Home", url: root_url },
      { name: "Blog", url: blog_index_url }
    ]
  end

  # Individual blog post - SEO optimized
  def show
    @seo_data = {
      title: "#{@blog_post[:title]} | DataReflow Blog",
      description: @blog_post[:excerpt],
      keywords: @blog_post[:keywords],
      canonical_url: blog_post_url(@blog_post[:slug]),
      og_type: "article",
      og_image: @blog_post[:featured_image] || "https://via.placeholder.com/1200x630/1f2937/ffffff?text=DataReflow+Blog"
    }

    @related_posts = related_blog_posts(@blog_post[:category])
    @author = @blog_post[:author]
    
    @breadcrumbs = [
      { name: "Home", url: root_url },
      { name: "Blog", url: blog_index_url },
      { name: @blog_post[:category], url: blog_category_url(@blog_post[:category].downcase) },
      { name: @blog_post[:title], url: blog_post_url(@blog_post[:slug]) }
    ]
  end

  # Blog category pages - SEO optimized
  def category
    @category = params[:category].humanize
    @seo_data = {
      title: "#{@category} Articles | DataReflow Blog",
      description: "Expert articles and insights about #{@category.downcase}. Learn from industry professionals and real-world case studies.",
      keywords: "#{@category.downcase} articles, #{@category.downcase} insights, #{@category.downcase} best practices",
      canonical_url: blog_category_url(@category.downcase),
      og_type: "website"
    }

    @posts = blog_posts_by_category(@category.downcase)
    @featured_post = @posts.first
    
    @breadcrumbs = [
      { name: "Home", url: root_url },
      { name: "Blog", url: blog_index_url },
      { name: @category, url: blog_category_url(@category.downcase) }
    ]
  end

  private

  def set_blog_post
    @blog_post = find_blog_post(params[:slug])
    redirect_to blog_index_path unless @blog_post
  end

  # Mock data for blog posts - replace with actual model/CMS integration
  def featured_blog_posts
    [
      {
        slug: "complete-guide-business-intelligence-smbs",
        title: "The Complete Guide to Business Intelligence for SMBs in 2025",
        excerpt: "Discover how small and medium businesses can leverage business intelligence tools to compete with enterprise companies. Step-by-step implementation guide included.",
        content: blog_post_content_1,
        featured_image: "https://via.placeholder.com/800x400/1f2937/ffffff?text=Business+Intelligence+Guide",
        author: {
          name: "Sarah Johnson",
          title: "Senior Data Analyst",
          avatar: "https://via.placeholder.com/100x100/4F46E5/ffffff?text=SJ",
          bio: "Sarah has 8+ years of experience helping SMBs implement data analytics solutions."
        },
        published_at: 1.week.ago,
        updated_at: 3.days.ago,
        read_time: "12 min read",
        category: "Business Intelligence",
        keywords: "business intelligence SMB, small business BI, data analytics for small business",
        tags: ["Business Intelligence", "SMB", "Data Analytics", "Dashboard", "KPIs"]
      },
      {
        slug: "etl-pipeline-best-practices-2025",
        title: "ETL Pipeline Best Practices: A Complete Guide for 2025",
        excerpt: "Learn industry-proven ETL pipeline strategies that ensure reliable, scalable data processing. Includes common pitfalls to avoid and performance optimization tips.",
        content: blog_post_content_2,
        featured_image: "https://via.placeholder.com/800x400/059669/ffffff?text=ETL+Best+Practices",
        author: {
          name: "Michael Chen",
          title: "Data Engineering Lead", 
          avatar: "https://via.placeholder.com/100x100/059669/ffffff?text=MC",
          bio: "Michael leads data engineering initiatives at Fortune 500 companies."
        },
        published_at: 2.weeks.ago,
        updated_at: 1.week.ago,
        read_time: "15 min read",
        category: "ETL",
        keywords: "ETL best practices, data pipeline optimization, ETL performance tuning",
        tags: ["ETL", "Data Pipeline", "Data Engineering", "Best Practices", "Performance"]
      }
    ]
  end

  def recent_blog_posts
    [
      {
        slug: "dashboard-design-principles",
        title: "5 Dashboard Design Principles That Actually Work",
        excerpt: "Transform your data visualizations with these proven design principles. Learn what makes dashboards effective and actionable.",
        featured_image: "https://via.placeholder.com/800x400/7C3AED/ffffff?text=Dashboard+Design",
        published_at: 3.days.ago,
        read_time: "8 min read",
        category: "Data Visualization",
        author: { name: "Emma Rodriguez", title: "UX Designer" }
      },
      {
        slug: "data-quality-framework",
        title: "Building a Data Quality Framework That Scales",
        excerpt: "Implement systematic data quality checks that grow with your business. Prevent bad data from corrupting your insights.",
        featured_image: "https://via.placeholder.com/800x400/DC2626/ffffff?text=Data+Quality",
        published_at: 5.days.ago,
        read_time: "10 min read",
        category: "Data Quality",
        author: { name: "David Park", title: "Data Architect" }
      },
      {
        slug: "roi-analytics-investment",
        title: "How to Calculate ROI on Your Analytics Investment",
        excerpt: "Quantify the business value of your data analytics initiatives. Framework for measuring and communicating analytics ROI to stakeholders.",
        featured_image: "https://via.placeholder.com/800x400/0891B2/ffffff?text=Analytics+ROI",
        published_at: 1.week.ago,
        read_time: "12 min read",
        category: "Business Intelligence",
        author: { name: "Lisa Thompson", title: "Business Analyst" }
      }
    ]
  end

  def popular_blog_posts
    [
      {
        slug: "shopify-analytics-guide",
        title: "Ultimate Shopify Analytics Guide for E-commerce Growth",
        excerpt: "Master Shopify analytics to boost your e-commerce performance. Track the metrics that matter for sustainable growth.",
        read_time: "14 min read",
        views: "15.2k views"
      },
      {
        slug: "google-analytics-4-setup",
        title: "Google Analytics 4 Setup Guide for Business Intelligence",
        excerpt: "Complete GA4 implementation guide for business intelligence workflows. Connect GA4 to your BI platform seamlessly.",
        read_time: "11 min read", 
        views: "12.8k views"
      }
    ]
  end

  def blog_categories
    [
      { name: "Business Intelligence", count: 24, slug: "business-intelligence" },
      { name: "ETL", count: 18, slug: "etl" },
      { name: "Data Visualization", count: 15, slug: "data-visualization" },
      { name: "Data Quality", count: 12, slug: "data-quality" },
      { name: "Case Studies", count: 9, slug: "case-studies" }
    ]
  end

  def find_blog_post(slug)
    all_blog_posts.find { |post| post[:slug] == slug }
  end

  def blog_posts_by_category(category)
    all_blog_posts.select { |post| post[:category].downcase == category }
  end

  def related_blog_posts(category)
    all_blog_posts
      .select { |post| post[:category] == category }
      .reject { |post| post[:slug] == @blog_post[:slug] }
      .first(3)
  end

  def all_blog_posts
    featured_blog_posts + recent_blog_posts + [
      {
        slug: "shopify-analytics-guide",
        title: "Ultimate Shopify Analytics Guide for E-commerce Growth",
        excerpt: "Master Shopify analytics to boost your e-commerce performance. Track the metrics that matter for sustainable growth.",
        content: "Detailed content about Shopify analytics...",
        featured_image: "https://via.placeholder.com/800x400/EA580C/ffffff?text=Shopify+Analytics",
        author: {
          name: "Jennifer Kim",
          title: "E-commerce Analyst",
          avatar: "https://via.placeholder.com/100x100/EA580C/ffffff?text=JK",
          bio: "Jennifer specializes in e-commerce analytics and growth optimization."
        },
        published_at: 2.weeks.ago,
        updated_at: 1.week.ago,
        read_time: "14 min read",
        category: "E-commerce",
        keywords: "shopify analytics, ecommerce analytics, shopify dashboard, online store metrics",
        tags: ["Shopify", "E-commerce", "Analytics", "Growth", "Metrics"]
      }
    ]
  end

  def blog_post_content_1
    <<~CONTENT
      <h2>Introduction to Business Intelligence for SMBs</h2>
      <p>Business intelligence (BI) is no longer just for large enterprises. Small and medium businesses (SMBs) can now leverage powerful BI tools to compete effectively and make data-driven decisions.</p>
      
      <h2>Why SMBs Need Business Intelligence</h2>
      <p>In today's competitive landscape, SMBs that harness their data effectively gain significant advantages:</p>
      <ul>
        <li>Faster decision-making with real-time insights</li>
        <li>Improved operational efficiency</li>
        <li>Better customer understanding</li>
        <li>Increased profitability through data-driven optimization</li>
      </ul>

      <h2>Getting Started with BI: A Step-by-Step Approach</h2>
      <p>Implementing BI doesn't have to be overwhelming. Here's a practical approach:</p>
      
      <h3>Step 1: Define Your Key Questions</h3>
      <p>Start by identifying the key business questions you need to answer. Common examples include:</p>
      <ul>
        <li>What are our most profitable products or services?</li>
        <li>Which marketing channels drive the best ROI?</li>
        <li>What factors influence customer retention?</li>
      </ul>

      <h3>Step 2: Identify Your Data Sources</h3>
      <p>Map out all the systems where your business data lives. This typically includes:</p>
      <ul>
        <li>CRM systems (Salesforce, HubSpot)</li>
        <li>E-commerce platforms (Shopify, WooCommerce)</li>
        <li>Financial systems (QuickBooks, Xero)</li>
        <li>Marketing tools (Google Analytics, Facebook Ads)</li>
      </ul>
      
      <!-- More content continues... -->
    CONTENT
  end

  def blog_post_content_2
    <<~CONTENT
      <h2>The Foundation of Reliable Data Processing</h2>
      <p>ETL (Extract, Transform, Load) pipelines are the backbone of any robust data analytics system. Getting them right from the start saves countless hours of debugging and ensures data integrity.</p>
      
      <h2>Core ETL Best Practices</h2>
      
      <h3>1. Design for Failure</h3>
      <p>Your ETL pipelines will fail - it's not a matter of if, but when. Design your pipelines to handle failures gracefully:</p>
      <ul>
        <li>Implement comprehensive error handling and retry logic</li>
        <li>Log all pipeline activities for debugging</li>
        <li>Set up monitoring and alerting for critical failures</li>
        <li>Design rollback mechanisms for data corruption scenarios</li>
      </ul>

      <h3>2. Validate Data at Every Step</h3>
      <p>Data quality issues compound quickly in ETL processes. Implement validation at multiple points:</p>
      <ul>
        <li>Source validation: Check data formats and completeness at extraction</li>
        <li>Transformation validation: Verify business rules and calculations</li>
        <li>Load validation: Confirm successful data insertion and integrity</li>
      </ul>
      
      <!-- More content continues... -->
    CONTENT
  end
end