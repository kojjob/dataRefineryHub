# frozen_string_literal: true

module SeoHelper
  # Dynamic meta tag generation for SEO optimization
  def seo_meta_tags(page_data = {})
    defaults = {
      title: "DataReflow Platform - Transform Business Data into Actionable Insights",
      description: "Enterprise-grade data refinery platform. Transform raw business data into unified analytics for SMBs. ETL pipelines, real-time dashboards, and automated insights.",
      keywords: "data analytics, business intelligence, ETL pipeline, data transformation, dashboard analytics, data integration, business insights, data visualization",
      og_type: "website",
      og_image: "https://via.placeholder.com/1200x630/1f2937/ffffff?text=DataReflow+Platform",
      twitter_card: "summary_large_image",
      canonical_url: request.original_url,
      robots: "index, follow",
      author: "DataReflow Platform",
      viewport: "width=device-width, initial-scale=1.0"
    }

    seo_data = defaults.merge(page_data)
    
    content_for :seo_meta_tags do
      safe_join([
        # Primary SEO Tags
        tag.title(seo_data[:title]),
        tag.meta(name: "description", content: seo_data[:description]),
        tag.meta(name: "keywords", content: seo_data[:keywords]),
        tag.meta(name: "author", content: seo_data[:author]),
        tag.meta(name: "robots", content: seo_data[:robots]),
        tag.meta(name: "viewport", content: seo_data[:viewport]),
        
        # Canonical URL
        tag.link(rel: "canonical", href: seo_data[:canonical_url]),
        
        # Open Graph Tags (Facebook, LinkedIn)
        tag.meta(property: "og:title", content: seo_data[:title]),
        tag.meta(property: "og:description", content: seo_data[:description]),
        tag.meta(property: "og:type", content: seo_data[:og_type]),
        tag.meta(property: "og:url", content: seo_data[:canonical_url]),
        tag.meta(property: "og:image", content: seo_data[:og_image]),
        tag.meta(property: "og:site_name", content: "DataReflow Platform"),
        tag.meta(property: "og:locale", content: "en_US"),
        
        # Twitter Card Tags
        tag.meta(name: "twitter:card", content: seo_data[:twitter_card]),
        tag.meta(name: "twitter:title", content: seo_data[:title]),
        tag.meta(name: "twitter:description", content: seo_data[:description]),
        tag.meta(name: "twitter:image", content: seo_data[:og_image]),
        tag.meta(name: "twitter:creator", content: "@DataReflowApp"),
        
        # Additional SEO Enhancement
        tag.meta(name: "theme-color", content: "#1f2937"),
        tag.meta(name: "application-name", content: "DataReflow Platform"),
        tag.meta(name: "apple-mobile-web-app-title", content: "DataReflow"),
        tag.meta(name: "apple-mobile-web-app-capable", content: "yes"),
        tag.meta(name: "apple-mobile-web-app-status-bar-style", content: "default"),
        
        # Preload critical resources
        tag.link(rel: "preconnect", href: "https://fonts.googleapis.com"),
        tag.link(rel: "preconnect", href: "https://fonts.gstatic.com", crossorigin: true),
        tag.link(rel: "dns-prefetch", href: "//fonts.googleapis.com"),
        tag.link(rel: "dns-prefetch", href: "//fonts.gstatic.com")
      ])
    end
  end

  # Generate JSON-LD structured data
  def structured_data(type, data = {})
    case type.to_sym
    when :organization
      organization_schema(data)
    when :webapp
      webapp_schema(data)
    when :article
      article_schema(data)
    when :product
      product_schema(data)
    when :breadcrumbs
      breadcrumb_schema(data)
    when :faq
      faq_schema(data)
    end
  end

  private

  def organization_schema(data = {})
    schema = {
      "@context": "https://schema.org",
      "@type": "Organization",
      "name": "DataReflow Platform",
      "description": "Enterprise-grade data refinery platform transforming business data into actionable insights",
      "url": root_url,
      "logo": "https://via.placeholder.com/200x60/1f2937/ffffff?text=DataReflow",
      "contactPoint": {
        "@type": "ContactPoint",
        "telephone": "+1-555-DATA-FLOW",
        "contactType": "Customer Service",
        "availableLanguage": "English"
      },
      "sameAs": [
        "https://twitter.com/DataReflowApp",
        "https://linkedin.com/company/dataReflow",
        "https://github.com/dataReflow/platform"
      ],
      "address": {
        "@type": "PostalAddress",
        "streetAddress": "123 Tech Innovation Drive",
        "addressLocality": "San Francisco",
        "addressRegion": "CA",
        "postalCode": "94105",
        "addressCountry": "US"
      },
      "foundingDate": "2024",
      "numberOfEmployees": "11-50",
      "industry": "Data Analytics Software"
    }.merge(data)

    content_tag :script, type: "application/ld+json" do
      raw schema.to_json
    end
  end

  def webapp_schema(data = {})
    schema = {
      "@context": "https://schema.org",
      "@type": "WebApplication",
      "name": "DataReflow Platform",
      "description": "Transform business data into unified analytics with ETL pipelines, real-time dashboards, and automated insights",
      "url": root_url,
      "applicationCategory": "BusinessApplication",
      "operatingSystem": "Web Browser",
      "offers": {
        "@type": "Offer",
        "price": "99",
        "priceCurrency": "USD",
        "priceValidUntil": "2025-12-31"
      },
      "featureList": [
        "ETL Pipeline Builder",
        "Real-time Analytics Dashboard", 
        "Data Source Integration",
        "Automated Insights Generation",
        "Custom Report Builder",
        "API Access",
        "Multi-tenant Architecture"
      ],
      "screenshot": "https://via.placeholder.com/1200x800/1f2937/ffffff?text=DataReflow+Dashboard",
      "softwareVersion": "8.0.2",
      "datePublished": "2024-01-01",
      "dateModified": Date.current.iso8601,
      "author": {
        "@type": "Organization",
        "name": "DataReflow Platform"
      }
    }.merge(data)

    content_tag :script, type: "application/ld+json" do
      raw schema.to_json
    end
  end

  def article_schema(data = {})
    return unless data[:title] && data[:content]

    schema = {
      "@context": "https://schema.org",
      "@type": "Article",
      "headline": data[:title],
      "description": data[:description] || data[:title],
      "author": {
        "@type": "Organization",
        "name": "DataReflow Platform"
      },
      "publisher": {
        "@type": "Organization",
        "name": "DataReflow Platform",
        "logo": {
          "@type": "ImageObject",
          "url": "https://via.placeholder.com/200x60/1f2937/ffffff?text=DataReflow"
        }
      },
      "datePublished": data[:published_at]&.iso8601 || Date.current.iso8601,
      "dateModified": data[:updated_at]&.iso8601 || Date.current.iso8601,
      "articleBody": strip_tags(data[:content]).truncate(500),
      "wordCount": strip_tags(data[:content]).split.length,
      "articleSection": data[:category] || "Data Analytics",
      "keywords": data[:keywords] || "data analytics, business intelligence"
    }

    if data[:image]
      schema["image"] = {
        "@type": "ImageObject",
        "url": data[:image],
        "width": "1200",
        "height": "630"
      }
    end

    content_tag :script, type: "application/ld+json" do
      raw schema.to_json
    end
  end

  def product_schema(data = {})
    schema = {
      "@context": "https://schema.org",
      "@type": "SoftwareApplication",
      "name": data[:name] || "DataReflow Platform",
      "description": data[:description] || "Enterprise data analytics platform",
      "applicationCategory": "BusinessApplication",
      "operatingSystem": "Web Browser",
      "offers": {
        "@type": "Offer",
        "price": data[:price] || "99",
        "priceCurrency": "USD",
        "availability": "https://schema.org/InStock"
      },
      "aggregateRating": {
        "@type": "AggregateRating", 
        "ratingValue": data[:rating] || "4.8",
        "reviewCount": data[:review_count] || "150",
        "bestRating": "5",
        "worstRating": "1"
      }
    }

    content_tag :script, type: "application/ld+json" do
      raw schema.to_json
    end
  end

  def breadcrumb_schema(breadcrumbs = [])
    return if breadcrumbs.empty?

    items = breadcrumbs.map.with_index do |crumb, index|
      {
        "@type": "ListItem",
        "position": index + 1,
        "name": crumb[:name],
        "item": crumb[:url]
      }
    end

    schema = {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      "itemListElement": items
    }

    content_tag :script, type: "application/ld+json" do
      raw schema.to_json
    end
  end

  def faq_schema(faqs = [])
    return if faqs.empty?

    questions = faqs.map do |faq|
      {
        "@type": "Question",
        "name": faq[:question],
        "acceptedAnswer": {
          "@type": "Answer",
          "text": faq[:answer]
        }
      }
    end

    schema = {
      "@context": "https://schema.org",
      "@type": "FAQPage",
      "mainEntity": questions
    }

    content_tag :script, type: "application/ld+json" do
      raw schema.to_json
    end
  end

  # Generate sitemap data
  def generate_sitemap_urls
    urls = []
    
    # Static pages
    urls << { loc: root_url, priority: 1.0, changefreq: "daily" }
    urls << { loc: about_url, priority: 0.8, changefreq: "monthly" }
    urls << { loc: landing_url, priority: 0.9, changefreq: "weekly" }
    
    # Dynamic content would go here
    # Example: Blog posts, case studies, etc.
    
    urls
  end

  # Page speed optimization
  def preload_critical_resources
    content_for :head do
      safe_join([
        tag.link(rel: "preload", href: asset_path("application.css"), as: "style"),
        tag.link(rel: "preload", href: asset_path("application.js"), as: "script"),
        tag.link(rel: "prefetch", href: dashboard_path)
      ])
    end
  end

end