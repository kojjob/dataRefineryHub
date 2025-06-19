# Data Refinery Platform

A comprehensive data refinery platform built with Ruby on Rails 8 that transforms raw business data from multiple sources into actionable insights through automated ETL pipelines, advanced analytics, and beautiful dashboards.

## 🎯 Business Overview

**Target Market**: Small to medium businesses (10-100 employees, £1M-£20M revenue)

**Value Proposition**: Enterprise-level data analytics capabilities with small business simplicity and pricing, enabling rapid setup (24-48 hours) versus weeks for traditional solutions.

**Revenue Model**: 
- Subscription tiers: Starter (£99/month), Growth (£199/month), Scale (£499/month)
- Usage-based overage charges for data processing limits
- Professional services for custom integrations and consulting

## 🏗️ Technology Stack

- **Backend**: Ruby on Rails 8.0.2 with Ruby 3.4.3
- **Database**: PostgreSQL for operational data, Snowflake/BigQuery for analytics warehouse
- **Frontend**: Hotwire (Turbo + Stimulus) with TailwindCSS for responsive dashboards
- **Background Jobs**: Solid Queue (Rails 8 built-in) with multiple priority queues
- **Caching**: Solid Cache (Rails 8 built-in)
- **Real-time**: Solid Cable (Rails 8 built-in) for WebSocket connections
- **ETL Engine**: Custom-built using Rails jobs with sophisticated error handling
- **API Layer**: RESTful APIs with comprehensive rate limiting and authentication
- **Deployment**: Kamal 2 for containerized deployment
- **Authentication**: Devise with role-based access control (Pundit)
- **Testing**: RSpec with comprehensive test coverage

## 🔗 Key Business Integrations

### Priority 1 (MVP)
- Shopify (e-commerce data)
- QuickBooks Online (financial data)
- Google Analytics (website analytics)
- Stripe (payment processing)
- Mailchimp (email marketing)

### Priority 2 (Growth)
- Zendesk (customer support)
- HubSpot CRM
- Google Ads
- Facebook Ads
- WooCommerce

### Priority 3 (Scale)
- Salesforce
- Amazon Seller Central
- Multiple inventory management systems
- Custom API integrations

## 🚀 Getting Started

### Prerequisites
- Ruby 3.4.3
- Rails 8.0.2
- PostgreSQL 15+
- Node.js 22.14.0+ (for TailwindCSS)

### Development Setup

1. Clone the repository and install dependencies:
```bash
git clone <repository-url>
cd data_refinery_platform
bundle install
```

2. Set up the database:
```bash
rails db:create
rails db:migrate
rails db:seed
```

3. Start the development server:
```bash
bin/dev
```

This will start:
- Rails server on http://localhost:3000
- TailwindCSS watcher for CSS compilation
- Solid Queue for background jobs

### Testing

Run the test suite:
```bash
bundle exec rspec
```

Run code quality checks:
```bash
bundle exec rubocop
bundle exec brakeman
```

### Deployment

Deploy using Kamal 2:
```bash
kamal deploy
```

## 📊 Core Features

### Multi-tenant Architecture
- Organization-based data isolation
- Role-based access control (Owner, Admin, Member, Viewer)
- Comprehensive audit logging

### ETL Pipeline Engine
- Modular extraction system with common interface
- Sophisticated data transformation capabilities
- Dual-storage architecture (PostgreSQL + Analytics warehouse)
- Real-time data quality monitoring

### Analytics & Dashboards
- Flexible, modular dashboard system
- Real-time data visualization
- Advanced business intelligence features
- Customer segmentation and RFM analysis

### API & Integration Layer
- RESTful APIs with comprehensive documentation
- Real-time webhook system
- Rate limiting based on subscription tiers
- API versioning strategy

## 🔒 Security & Compliance

- Encryption at rest and in transit (Lockbox + Blind Index)
- SOC2/GDPR compliance preparation
- Multi-factor authentication support
- Comprehensive security audit logging

## 📈 Performance Targets

- API response times under 200ms
- Dashboard load times under 2 seconds
- ETL processing rates above 10,000 records/minute
- 99.9% uptime target

## 📚 Documentation

See `docs/` directory for:
- Architecture documentation
- API documentation
- User guides
- Development guidelines

## 🤝 Contributing

1. Create a feature branch from `main`
2. Make your changes with tests
3. Ensure all tests pass and code quality checks pass
4. Submit a pull request

## 📝 License

Proprietary - All rights reserved.

## 📞 Support

For technical support or questions, please contact the development team.
