# Claude Code Instructions for Data Refinery Platform

## Project Overview
This is a Ruby on Rails 8 Data Refinery Platform - a comprehensive SaaS application that transforms raw business data into actionable insights for SMBs.

## Development Workflow
- **Always start tasks with a git branch**: Use feature branches for all development
- **Always write tests first**: Follow TDD approach with RSpec
- **Test and commit frequently**: Commit after each significant feature or bugfix
- **Follow Rails conventions**: Use Rails 8 features and standard patterns

## Technology Stack Guidelines
- **Rails 8.0.2** with Ruby 3.4.3
- **Use Rails 8 native gems**: Solid Queue, Solid Cache, Solid Cable (NO Redis/Sidekiq)
- **Frontend**: Hotwire (Turbo + Stimulus) with TailwindCSS
- **Database**: PostgreSQL for operational data
- **Authentication**: Devise with Pundit for authorization
- **Testing**: RSpec with Factory Bot and comprehensive coverage
- **Background Jobs**: Solid Queue with priority queues

## Code Quality Standards
- **Follow Rails conventions**: Use standard Rails patterns and naming
- **Write comprehensive tests**: Unit, integration, and system tests
- **Code documentation**: Document complex business logic and APIs
- **Security first**: Always consider data security and privacy
- **Performance optimization**: Target <200ms API responses, <2s dashboard loads

## Multi-tenant Architecture
- **Organization-based isolation**: All data must be scoped to organizations
- **Role-based access**: Owner, Admin, Member, Viewer roles
- **Audit logging**: Track all significant actions
- **Data encryption**: Use Lockbox for sensitive data

## ETL Pipeline Guidelines
- **Modular extractors**: Each data source implements common interface
- **Error handling**: Comprehensive retry logic and circuit breakers
- **Data validation**: Schema validation and quality checks
- **Incremental sync**: Support for incremental data updates
- **Job monitoring**: Real-time status and alerting

## API Development
- **RESTful design**: Follow REST conventions
- **Rate limiting**: Implement subscription-based limits
- **Versioning**: Support API versioning strategy
- **Authentication**: API key and JWT authentication
- **Documentation**: Comprehensive API docs with examples

## Frontend Development
- **Responsive design**: Mobile-first with TailwindCSS
- **Real-time updates**: Use Turbo Streams for live data
- **Component-based**: Use ViewComponent for reusable UI
- **Performance**: Optimize for fast dashboard loads
- **Accessibility**: Follow WCAG guidelines

## Testing Requirements
- **Test-driven development**: Write tests before implementation
- **High coverage**: Target >90% test coverage
- **Integration tests**: Test ETL pipelines end-to-end
- **API testing**: Comprehensive endpoint testing
- **Multi-tenancy**: Verify data isolation

## Security Requirements
- **Data encryption**: Encrypt sensitive data at rest and in transit
- **Access control**: Implement proper authorization
- **Audit logging**: Log all data access and modifications
- **Input validation**: Validate all user inputs
- **Security headers**: Implement proper security headers

## Performance Requirements
- **API responses**: <200ms for standard requests
- **Dashboard loads**: <2 seconds
- **ETL processing**: >10,000 records/minute
- **Database queries**: Optimize with proper indexing
- **Caching**: Use Solid Cache effectively

## Business Logic Priorities
1. **Customer Data**: Unified customer profiles across sources
2. **Order Analytics**: Comprehensive order lifecycle tracking
3. **Financial Metrics**: Revenue, profitability, cash flow
4. **Inventory Intelligence**: Stock levels, demand forecasting
5. **Marketing Analytics**: Campaign effectiveness, ROI

## Integration Priorities
1. **MVP Integrations**: Shopify, QuickBooks, GA, Stripe, Mailchimp
2. **Growth Integrations**: Zendesk, HubSpot, Google Ads, Facebook Ads
3. **Scale Integrations**: Salesforce, Amazon, Custom APIs

## Development Commands
- **Start development**: `bin/dev` (includes Rails server and TailwindCSS watcher)
- **Run tests**: `bundle exec rspec`
- **Code quality**: `bundle exec rubocop && bundle exec brakeman`
- **Database**: `rails db:create db:migrate db:seed`
- **Background jobs**: Already running with Solid Queue
- **Deploy**: `kamal deploy`

## Branch Strategy
- **main**: Production-ready code
- **feature/***: Feature development branches
- **hotfix/***: Emergency fixes
- **release/***: Release preparation

## Commit Message Format
```
Type: Brief description

Detailed explanation if needed

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## File Organization
- **Models**: Business logic and data validation
- **Controllers**: API endpoints and web interface
- **Services**: Business operations and ETL logic
- **Jobs**: Background processing with Solid Queue
- **Components**: ViewComponent UI components
- **Extractors**: Data source integration logic

## Environment Variables
- **Database**: DATABASE_URL for PostgreSQL
- **API Keys**: Store in Rails credentials
- **External APIs**: Use environment-specific configuration
- **Deployment**: Kamal 2 configuration in config/deploy.yml

## Rails Encryption Credentials
When working with encrypted data models, use these credentials in `rails credentials:edit`:

```yaml
active_record_encryption:
  primary_key: is1Z7xWcEJ8chpbiEvQSM8YUCtMUHtaf
  deterministic_key: N4ExZWyQvG3P9dTvlKLR96H6ncXLTAmD
  key_derivation_salt: 0fLCJKtKzZsh2VcFnz7Po34vc5DnpmV4
```

## Test Environment Setup
- **RSpec**: Configured with FactoryBot and Shoulda Matchers
- **Database Cleaner**: Ensures test isolation
- **Timecop**: For time-based testing (add to Gemfile if needed)
- **Encryption**: Tests use same credentials as development

## Documentation Requirements
- **README.md**: Keep updated with setup and usage
- **TODO.md**: Track development progress
- **API docs**: Document all endpoints
- **Architecture docs**: System design documentation

## Error Handling
- **Graceful degradation**: Handle API failures gracefully
- **User feedback**: Clear error messages for users
- **Logging**: Comprehensive error logging
- **Monitoring**: Set up error tracking and alerting
- **Recovery**: Implement retry mechanisms

## Deployment Guidelines
- **Kamal 2**: Use for containerized deployment
- **Environment separation**: staging, production
- **Zero-downtime**: Ensure smooth deployments
- **Monitoring**: Application and infrastructure monitoring
- **Backups**: Automated database backups

Remember: This is a production SaaS application serving paying customers. Every decision should prioritize reliability, security, and user experience.