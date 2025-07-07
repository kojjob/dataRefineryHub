Below is the updated CLAUDE.md refined for clarity and completeness. I’ve also included key contextual details about Rails 8 based on its official release and features. Let me know if you’d like this as a .claude.md file in your repo!

⸻

🧠 CLAUDE.md — Data Refinery Platform for Rails 8

🎯 Project Purpose

A production-grade, multi-tenant SaaS built with Ruby on Rails 8 (Ruby 3.4), transforming raw business data into unified, actionable insights for SMBs. Claude agents assist developers with code generation, guidance, and task automation.

⚡ Rails 8 (released Nov 7, 2024) empowers apps to run without Redis/Sidekiq by default—using Solid Queue, Cache, and Cable—simplifying infrastructure and reducing costs  ￼.

⸻

🔁 Development Workflow
 1. Branch per task: Always start with feature/...
 2. TDD-first: Write failing RSpec tests before code
 3. Frequent commits: Commit after each meaningful change
 4. PR process: Descriptive title, checklist, passing CI
 5. Autonomous execution: Claude agents follow spec without asking
 6. Merge after CI approval

⸻

⚙️ Tech Stack & Architecture

Layer Technology
Framework Ruby on Rails 8.0.2 (Ruby 3.4.3) ()
Background Jobs Solid Queue (DB-backed queue) ()
Caching Solid Cache (DB-backed caching) ()
WebSockets Solid Cable (DB‑backed Action Cable) ()
Asset Pipeline Propshaft (default replacement for Sprockets) ()
Deployment Kamal 2 (gen’d by default) ()
Auth & AuthZ Devise + Pundit
Frontend Hotwire (Turbo + Stimulus) + TailwindCSS
DB PostgreSQL
Encryption Lockbox + Rails encrypted attributes
Testing RSpec, FactoryBot, Shoulda, Timecop, DatabaseCleaner


⸻

🧪 Code Quality & Testing
 • Adhere strictly to Rails conventions & patterns
 • Use rubocop, brakeman, and CI checks
 • Achieve > 90% test coverage
 • Conduct thorough unit, integration & system tests
 • ETL and API workflows must be end‑to‑end tested
 • Test isolation via Timecop and DBCleaner

⸻

🛡️ Security & Multi-Tenancy
 • Tenant isolation via acts_as_tenant/pundit policy scope
 • RBAC roles: Owner, Admin, Member, Viewer
 • Audit logs for all CRUD actions
 • Full encryption: in flight, at rest, plus Lockbox for sensitive data
 • Enforced CSP, strong parameters, and secure headers

⸻

🔄 ETL Pipeline
 • Extractors with common interface per source integration
 • Schema validation and record-level checks
 • Incremental syncs using timestamps
 • Robust retry logic with backoff + alerting
 • Monitor pipelines with real-time dashboards and Turbo Streams

⸻

📡 API Design
 • Use REST principles with versioned endpoints (/api/v1/)
 • JWT/API key auth + subscription-based rate limiting
 • Extensive input validation & strong parameters
 • Auto-generated docs (Swagger/OpenAPI preferred)

⸻

🖥️ Frontend & UX
 • Mobile-first design via TailwindCSS
 • Live updates using Turbo Streams
 • Reusable, testable UI using ViewComponent
 • WCAG 2.1 AA accessibility standards
 • Dashboard performance < 2 s via lazy loading & caching

⸻

⏱️ Performance Metrics

Metric Target
API response < 200 ms typical
Dashboard render < 2 s on <100k records
ETL throughput > 10 k records/minute
DB efficiency No N+1s; proper indexing


⸻

💼 Business Logic Priorities
 1. Unified customer profiles
 2. Inventory & order analytics
 3. Financial KPIs (MRR, CAC, CLTV, Cash flow)
 4. Marketing attribution & campaign analytics
 5. Channel/product performance insights

⸻

🔌 Integration Plan
 • MVP: Shopify, QuickBooks, Stripe, Mailchimp, Google Analytics
 • Growth: HubSpot, Zendesk, Google/Meta Ads
 • Scale: Salesforce, Amazon, Custom APIs

⸻

💻 Developer Commands

bin/dev                      # run server + Tailwind watcher
bundle exec rspec           # run tests
bundle exec rubocop         # lint code
bundle exec brakeman        # static security analysis
rails db:setup              # create, migrate, seed
kamal deploy                # deploy to staging/production


⸻

🌿 Git Branching
 • main – production-ready, protected
 • feature/* – ongoing development
 • release/* – pre-production QA
 • hotfix/* – emergency patches

⸻

✍️ Commit Message Style

<type>: <short imperative summary>

Longer explanation and context...

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>


⸻

🌐 Environments & Secrets
 • Credentials stored using config/credentials.yml.enc
 • Use dotenv or Rails env vars for local development
 • Kamal-managed secrets for containerized production

⸻

🧪 Testing Environment Setup
 • Use shared credentials between dev/test
 • FactoryBot + Shoulda
 • Time‑based tests via Timecop
 • DB cleanup via DatabaseCleaner

⸻

📚 Documentation
 • README.md: setup + overview
 • docs/architecture.md: system & domain design
 • docs/api.md: API endpoints (Swagger/OpenAPI)
 • TODO.md: backlog and progress

⸻

⚠️ Error Handling & Monitoring
 • Graceful fallback behavior for external failures
 • Application-wide error feedback via Turbo Streams
 • Monitor errors via Sentry/Rollbar/Bugsnag
 • Retry strategies in ETL/pipelines
 • System health dashboards & alerting

⸻

🚀 Deployment Strategy
 • Docker-based deployment via Kamal 2
 • Staging and prod separations
 • Zero-downtime rollouts
 • Scheduled database backups & restore testing
 • Infrastructure metrics via Grafana/Healthchecks

⸻

🤖 Claude Agent Protocol
 • Adhere exactly to this spec
 • Don’t digress—avoid unnecessary questions
 • Generate idiomatic Rails 8 + Hotwire + Tailwind code
 • Use RSpec; avoid undocumented gems
 • Prefer native Rails features over new dependencies

⸻

✅ Rails 8 Highlights
 • Defaults to Solid adapters (Queue, Cache, Cable) enabling Redis-free stacks  ￼ ￼ ￼ ￼ ￼
 • Introduces Propshaft as the new asset pipeline  ￼
 • Built-in authentication generator for baseline session management and password reset  ￼
 • Ships with Kamal 2 for streamlined container-based deployments  ￼

⸻

Would you like me to commit this file directly into your repo under docs/CLAUDE.md or publish it as a standalone .claude.md?

Remember: This is a production SaaS application serving paying customers. Every decision should prioritize reliability, security, and user experience.