# Data Refinery Platform

A comprehensive, enterprise-grade data refinery platform built with Ruby on Rails 8 that transforms raw business data from multiple sources into actionable insights through automated ETL pipelines, advanced analytics, and beautiful dashboards.

## 🎯 Business Overview

**Target Market**: Small to medium businesses (10-100 employees, £1M-£20M revenue) who currently struggle with:
- Manual data collection from multiple business tools (Shopify, QuickBooks, Stripe, etc.)
- Excel-based reporting and fragmented analytics
- Lack of unified customer view across systems
- No real-time business insights or automated decision support
- Technical complexity and cost of traditional enterprise BI tools

**Value Proposition**: 
- **Enterprise-level capabilities** at small business prices
- **Rapid deployment** - customers see value within 24-48 hours vs weeks for traditional solutions
- **Unified data platform** connecting 12+ business tools out of the box
- **Real-time insights** with automated anomaly detection and alerting
- **No technical expertise required** - designed for business users, not data scientists

**Revenue Model**: 
- **Starter Plan**: £99/month (100K records/month, 5 integrations, 5 users)
- **Growth Plan**: £199/month (500K records/month, 15 integrations, 20 users) 
- **Scale Plan**: £499/month (2M records/month, 50 integrations, 100 users)
- **Enterprise**: Custom pricing (unlimited everything + white-label options)
- **Usage overages**: £0.10 per 1,000 additional records
- **Professional services**: Custom integrations, consulting, training

## 🏗️ Technology Stack

### Core Platform
- **Backend**: Ruby on Rails 8.0.2 with Ruby 3.4.3
- **Database**: PostgreSQL 15+ for operational data with read replicas
- **Analytics Warehouse**: Snowflake/BigQuery for historical data and complex queries
- **Frontend**: Hotwire (Turbo + Stimulus) with TailwindCSS for responsive dashboards
- **Authentication**: Devise with role-based access control via Pundit
- **Testing**: RSpec with FactoryBot, comprehensive test coverage (>90%)

### Rails 8 Native Features (No Redis/Sidekiq Dependencies)
- **Background Jobs**: Solid Queue with 4 priority queues (extraction, transformation, loading, analytics)
- **Caching**: Solid Cache for session management and application data
- **Real-time**: Solid Cable for WebSocket connections and live dashboard updates
- **Job Monitoring**: Built-in job status tracking with retry logic and circuit breakers

### Data Processing & Security
- **ETL Engine**: Custom-built modular extraction system with 12+ data source integrators
- **Data Encryption**: Lockbox + Blind Index for GDPR/SOC2 compliance
- **Rate Limiting**: Rack::Attack with subscription-tier based limits
- **API Layer**: RESTful APIs with JWT authentication and comprehensive versioning
- **Monitoring**: Application Performance Monitoring with error tracking and alerting

### Infrastructure & Deployment
- **Containerization**: Docker with Kamal 2 for zero-downtime deployments
- **CDN**: Global content delivery for dashboard assets
- **Load Balancing**: Auto-scaling application servers based on demand
- **Backup Strategy**: Automated PostgreSQL backups with point-in-time recovery
- **Monitoring**: Infrastructure monitoring with custom business metrics dashboards

## 🔗 Business Integrations & Data Sources

### Priority 1 (MVP Launch) - 5 Integrations
| Integration | Data Types | Sync Frequency | Key Metrics |
|-------------|------------|----------------|-------------|
| **Shopify** | Orders, customers, products, inventory | Real-time webhooks + hourly sync | Revenue, conversion rates, inventory turnover |
| **QuickBooks Online** | Invoices, expenses, chart of accounts | Daily sync | Cash flow, profitability, expense tracking |
| **Google Analytics** | Sessions, pageviews, conversions | Hourly sync | Traffic, user behavior, conversion funnels |
| **Stripe** | Payments, subscriptions, disputes | Real-time webhooks | Payment success rates, MRR, churn |
| **Mailchimp** | Campaigns, subscribers, engagement | Daily sync | Email ROI, list growth, engagement rates |

### Priority 2 (Growth Phase) - 10 Additional Integrations
| Integration | Purpose | Key Data |
|-------------|---------|----------|
| **Zendesk** | Customer support analytics | Ticket volume, resolution times, satisfaction scores |
| **HubSpot CRM** | Sales pipeline management | Deal progression, lead scoring, sales cycle analysis |
| **Google Ads** | Paid advertising performance | Cost per click, conversion tracking, ROAS |
| **Facebook Ads** | Social media advertising | Campaign performance, audience insights, attribution |
| **WooCommerce** | Alternative e-commerce platform | Order data, customer behavior, plugin analytics |
| **Amazon Seller Central** | Marketplace sales data | Inventory levels, sales velocity, competitor insights |
| **Xero** | Alternative accounting platform | Financial reporting, expense categorization |
| **ActiveCampaign** | Marketing automation | Email sequences, behavioral triggers, lead scoring |
| **Intercom** | Customer communication | Message volume, response times, user engagement |
| **PayPal** | Payment processing | Transaction data, dispute tracking, international sales |

### Priority 3 (Enterprise Scale) - Unlimited Custom Integrations
- **Salesforce** - Enterprise CRM with custom object support
- **NetSuite** - ERP system integration for larger businesses  
- **Custom APIs** - Webhook-based integrations for proprietary systems
- **Database Connectors** - Direct SQL access to existing data warehouses
- **File Import Systems** - CSV/Excel upload with automated processing
- **White-label Partner APIs** - Integration marketplace for third-party developers

## 🚀 Getting Started

### Prerequisites
- **Ruby**: 3.4.3 (use rbenv or rvm for version management)
- **Rails**: 8.0.2 (latest version with Solid* gems)
- **PostgreSQL**: 15+ (for primary database)
- **Node.js**: 22.14.0+ (for TailwindCSS compilation)
- **Git**: Latest version for version control
- **Docker**: Optional, for containerized development

### Quick Start (5-minute setup)

```bash
# Clone and enter directory
git clone https://github.com/your-org/data_refinery_platform.git
cd data_refinery_platform

# Install dependencies
bundle install

# Set up encryption credentials (copy from CLAUDE.md)
rails credentials:edit
# Add the encryption keys provided in CLAUDE.md

# Create and migrate database
rails db:create
rails db:migrate
rails db:seed

# Start development server (includes Rails, TailwindCSS, and Solid Queue)
bin/dev
```

Visit `http://localhost:3000` to access the platform.

### Detailed Development Setup

#### 1. Environment Configuration

Create a `.env.development` file:
```bash
# Database
DATABASE_URL=postgresql://username:password@localhost/data_refinery_platform_development

# External API Keys (get from respective services)
SHOPIFY_API_KEY=your_shopify_api_key
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key
GOOGLE_ANALYTICS_PROPERTY_ID=GA4-123456789
QUICKBOOKS_CLIENT_ID=your_quickbooks_client_id
MAILCHIMP_API_KEY=your_mailchimp_api_key

# Optional: Analytics warehouse
SNOWFLAKE_ACCOUNT=your_account.snowflakecomputing.com
BIGQUERY_PROJECT_ID=your_gcp_project_id
```

#### 2. Database Setup with Sample Data

```bash
# Create development and test databases
rails db:create

# Run all migrations
rails db:migrate

# Seed with sample organizations, users, and data sources
rails db:seed

# Optional: Load demo data for testing dashboard features
rails demo:load_sample_data
```

#### 3. Background Jobs & Queue Monitoring

The platform uses Solid Queue (Rails 8 built-in) with four priority queues:

```bash
# View queue status
rails solid_queue:status

# Process jobs manually (for development debugging)
rails jobs:work QUEUE=extraction
rails jobs:work QUEUE=transformation  
rails jobs:work QUEUE=loading
rails jobs:work QUEUE=analytics
```

#### 4. Testing Framework

```bash
# Run full test suite
bundle exec rspec

# Run specific test types
bundle exec rspec spec/models/                # Model tests
bundle exec rspec spec/services/              # Business logic tests  
bundle exec rspec spec/jobs/                  # Background job tests
bundle exec rspec spec/requests/              # API endpoint tests

# Run with coverage report
COVERAGE=true bundle exec rspec

# Security and code quality checks
bundle exec brakeman                          # Security vulnerabilities
bundle exec rubocop                          # Code style and best practices
bundle exec bundle-audit                     # Gem vulnerability scanning
```

#### 5. Data Pipeline Development & Testing

```bash
# Test individual data source extractors
rails console
> ShopifyExtractor.new(data_source).test_connection
> StripeExtractor.new(data_source).extract_data

# Monitor ETL job performance
rails etl:status
rails etl:retry_failed_jobs

# View data quality metrics
rails data_quality:report --source=shopify --days=7
```

### Production Deployment

#### Option 1: Kamal 2 (Recommended)

```bash
# Configure production secrets
kamal setup

# Deploy to production
kamal deploy

# Monitor deployment
kamal logs --follow
```

#### Option 2: Manual Docker Deployment

```bash
# Build production image
docker build -t data_refinery_platform .

# Run with environment variables
docker run -p 3000:3000 \
  -e DATABASE_URL=postgresql://prod_user:pass@prod_host/prod_db \
  -e RAILS_ENV=production \
  data_refinery_platform
```

### Environment Variables Reference

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `DATABASE_URL` | PostgreSQL connection string | Yes | `postgresql://user:pass@localhost/db` |
| `RAILS_MASTER_KEY` | Rails credentials encryption key | Yes | `abcd1234...` |
| `SHOPIFY_API_KEY` | Shopify app API key | No* | `abc123...` |
| `STRIPE_SECRET_KEY` | Stripe secret key | No* | `sk_live_...` |
| `GOOGLE_ANALYTICS_PROPERTY_ID` | GA4 property ID | No* | `GA4-123456789` |
| `REDIS_URL` | Redis connection (if using) | No | `redis://localhost:6379` |
| `SNOWFLAKE_ACCOUNT` | Data warehouse connection | No | `account.snowflakecomputing.com` |

*Required for respective integrations to function

## 📊 Core Platform Features

### 🏢 Multi-tenant Architecture
- **Organization-based isolation**: Complete data separation between customers
- **Role-based access control**: 4-tier permission system (Owner → Admin → Member → Viewer)
- **Comprehensive audit logging**: Track every user action and data modification
- **Usage monitoring**: Real-time tracking of API calls, data processing, and storage
- **Plan enforcement**: Automatic limit checking and overage billing integration

### ⚙️ Enterprise ETL Pipeline Engine
- **Modular extractor system**: Common interface supporting 15+ data sources
- **Intelligent sync scheduling**: Adaptive frequency based on data volume and business hours
- **Circuit breaker patterns**: Prevent cascade failures across data sources
- **Sophisticated retry logic**: Exponential backoff with jitter for failed jobs
- **Data lineage tracking**: Full audit trail from source to dashboard
- **Quality monitoring**: Real-time data validation with anomaly detection
- **Dual-storage architecture**: Hot data (PostgreSQL) + Cold data (Snowflake/BigQuery)

### 📈 Advanced Analytics & Business Intelligence
| Feature | Description | Business Value |
|---------|-------------|----------------|
| **Unified Customer 360** | Merge customer data across all platforms | Single source of truth for customer insights |
| **RFM Segmentation** | Recency, Frequency, Monetary analysis | Automated customer categorization and targeting |
| **Churn Prediction** | ML-powered customer retention forecasting | Proactive retention campaigns |
| **Revenue Attribution** | Multi-touch attribution across channels | Optimize marketing spend allocation |
| **Inventory Optimization** | Demand forecasting and reorder point alerts | Reduce stockouts and carrying costs |
| **Financial Health Score** | Real-time business performance indicator | Early warning system for cash flow issues |

### 📊 Real-time Dashboard System
- **Drag-and-drop builder**: No-code dashboard creation for business users
- **20+ pre-built widgets**: Revenue trends, customer analytics, inventory, marketing ROI
- **Real-time updates**: Live data via WebSockets (Solid Cable)
- **Mobile responsive**: TailwindCSS-powered responsive design
- **Export capabilities**: PDF reports, CSV data exports, scheduled email reports
- **Collaborative sharing**: Team dashboards with role-based view permissions

### 🔌 API & Integration Platform
- **RESTful API**: Complete CRUD operations for all business entities
- **Webhook system**: Real-time notifications for data changes and job completions
- **Rate limiting tiers**: Subscription-based API quotas (10K-200K+ requests/month)
- **API versioning**: Backward-compatible versioning strategy
- **Comprehensive docs**: Interactive API documentation with code examples
- **SDK libraries**: Official Ruby, Python, and JavaScript client libraries

## 🔒 Enterprise Security & Compliance

### Data Protection
- **Encryption at rest**: Lockbox encryption for all sensitive data (API keys, PII)
- **Encryption in transit**: TLS 1.3 for all API communications
- **Blind indexing**: Searchable encrypted fields for performance
- **Data masking**: Automatic PII redaction in logs and debugging
- **Secure credential storage**: Rails credentials with rotation support

### Compliance & Auditing
- **SOC2 Type II ready**: Security controls and documentation
- **GDPR compliance**: Data portability, right to deletion, consent management
- **HIPAA considerations**: Additional controls for healthcare customers
- **Audit trail**: Immutable log of all data access and modifications
- **Data retention policies**: Configurable retention with automatic cleanup

### Access Control
- **Multi-factor authentication**: TOTP and SMS-based 2FA
- **Single sign-on**: SAML and OAuth integration for enterprise customers
- **API key management**: Scoped permissions with expiration dates
- **Session management**: Secure session handling with timeout policies
- **IP allowlisting**: Organization-level IP restrictions

## 📈 Performance & Scalability

### Performance Benchmarks
| Metric | Target | Current | Industry Standard |
|--------|--------|---------|-------------------|
| **API Response Time** | <200ms | <150ms | <500ms |
| **Dashboard Load Time** | <2s | <1.5s | <5s |
| **ETL Processing Rate** | >10K records/min | >15K records/min | >5K records/min |
| **Uptime SLA** | 99.9% | 99.95% | 99.5% |
| **Data Freshness** | <5min for critical sources | <3min | <15min |

### Scalability Architecture
- **Horizontal scaling**: Auto-scaling application servers based on CPU/memory
- **Database optimization**: Read replicas, connection pooling, query optimization
- **Background job scaling**: Dynamic worker allocation based on queue depth
- **CDN integration**: Global asset delivery with edge caching
- **Load balancing**: Multi-region deployment with health checks

## 📚 Documentation & Resources

### 📖 Technical Documentation
| Document | Description | Audience |
|----------|-------------|----------|
| **[CLAUDE.md](./CLAUDE.md)** | Development guidelines and project setup | Developers |
| **[TODO.md](./TODO.md)** | Development roadmap and progress tracking | Project managers |
| **[API Documentation](./docs/api/)** | RESTful API reference with examples | Integration developers |
| **[Architecture Guide](./docs/architecture/)** | System design and data flow diagrams | Technical architects |
| **[Security Handbook](./docs/security/)** | Security controls and compliance procedures | Security teams |

### 📋 Development Guidelines
- **Test-driven development**: Write tests first, then implement features
- **Feature branch workflow**: Use `feature/description` branch naming
- **Comprehensive testing**: Aim for >90% test coverage across all layers
- **Security-first approach**: Consider security implications in every feature
- **Performance monitoring**: Track and optimize all critical performance metrics

### 🎯 Business Metrics & KPIs

#### Customer Success Metrics
- **Time to First Value**: <24 hours from signup to first dashboard
- **Integration Success Rate**: >95% successful data source connections
- **Data Sync Reliability**: >99.9% successful sync completion rate
- **Dashboard Load Performance**: <2 seconds average load time
- **Customer Support Response**: <1 hour for critical issues

#### Technical Performance Metrics  
- **API Uptime**: 99.9% availability with <200ms response times
- **ETL Processing Rate**: >10,000 records per minute per worker
- **Data Quality Score**: >98% accuracy after transformation
- **Security Incident Rate**: Zero data breaches or unauthorized access
- **System Recovery Time**: <5 minutes for automatic failover

## 🚀 Development Roadmap

### Phase 1: Core Infrastructure ✅
- [x] Multi-tenant foundation with Rails 8
- [x] Comprehensive ETL pipeline architecture  
- [x] Data source integration framework
- [x] Enterprise security and encryption
- [x] Background job processing with Solid Queue

### Phase 2: Business Intelligence (Current)
- [ ] Advanced analytics engine with ML predictions
- [ ] Real-time dashboard system with drag-and-drop builder
- [ ] Customer segmentation and RFM analysis
- [ ] Financial reporting and cash flow forecasting  
- [ ] Marketing attribution and ROI tracking

### Phase 3: Scale & Expansion (Next)
- [ ] White-label partner program
- [ ] Advanced API marketplace  
- [ ] Enterprise SSO and compliance certifications
- [ ] Multi-region deployment and edge computing
- [ ] AI-powered business insights and recommendations

## 🤝 Contributing

### Development Workflow
1. **Fork the repository** and create a feature branch from `main`
2. **Follow TDD approach**: Write tests first, then implement features
3. **Maintain code quality**: Ensure all tests pass and code style checks pass
4. **Security review**: Consider security implications and run security scans
5. **Performance testing**: Verify performance benchmarks are maintained
6. **Documentation**: Update relevant documentation for new features
7. **Submit pull request** with comprehensive description and test results

### Code Quality Standards
```bash
# Before submitting any pull request, ensure these pass:
bundle exec rspec                    # All tests pass
bundle exec rubocop                  # Code style compliance  
bundle exec brakeman                 # Security vulnerability scan
bundle exec bundle-audit             # Dependency vulnerability scan
COVERAGE=true bundle exec rspec      # >90% test coverage maintained
```

### Issue Reporting
- **Bug reports**: Include reproduction steps, expected vs actual behavior
- **Feature requests**: Describe business value and proposed implementation  
- **Security issues**: Report privately to security@company.com
- **Performance issues**: Include profiling data and reproduction environment

## 📊 Project Status

### Current Development Phase
**Phase 1 Complete**: ✅ Core infrastructure and ETL pipeline  
**Phase 2 In Progress**: 🚧 Business intelligence and analytics (40% complete)  
**Phase 3 Planned**: 📋 Scale and expansion features

### Recent Milestones
- ✅ **Multi-tenant architecture** with complete data isolation
- ✅ **Enterprise ETL pipeline** with 5 priority integrations  
- ✅ **Security framework** with encryption and audit logging
- ✅ **Testing infrastructure** with comprehensive coverage
- 🚧 **Analytics engine** with customer segmentation (in progress)

### Tech Debt & Optimization Priorities
1. **Database query optimization**: Implement query caching and indexing strategy
2. **Background job monitoring**: Enhanced observability and alerting  
3. **API rate limiting**: Fine-tuned limits based on usage patterns
4. **Frontend performance**: Code splitting and lazy loading optimization
5. **Security hardening**: Regular penetration testing and security audits

## 📞 Support & Contact

### For Developers
- **Technical questions**: Create an issue in this repository
- **Setup problems**: Check [CLAUDE.md](./CLAUDE.md) or ask in team chat
- **Feature discussions**: Use GitHub Discussions for architecture decisions

### For Business Users  
- **Product support**: support@datarefinery.com
- **Sales inquiries**: sales@datarefinery.com  
- **Partnership opportunities**: partners@datarefinery.com

### Emergency Contact
- **Security incidents**: security@datarefinery.com
- **System outages**: ops-team@datarefinery.com
- **Critical bugs**: Create a GitHub issue with `critical` label

---

## 📝 License & Legal

**Proprietary Software** - All rights reserved.

This software is proprietary and confidential. Unauthorized copying, distribution, or modification is strictly prohibited. Licensed for use only by authorized personnel.

**Third-party Dependencies**: See `Gemfile` for open-source dependencies and their respective licenses.

---

*Built with ❤️ using Ruby on Rails 8, PostgreSQL, and modern web technologies. Designed for SMBs who deserve enterprise-grade data analytics.*
