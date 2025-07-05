# Rails Application Analyzer with Puppeteer

This Puppeteer-based analyzer provides comprehensive analysis of your Rails application, including performance metrics, accessibility checks, UX evaluation, security scanning, and Data Refinery-specific feature analysis.

## Features

- **Performance Analysis**: Load times, resource sizes, network requests
- **Accessibility Testing**: WCAG compliance, ARIA labels, heading hierarchy
- **UX Evaluation**: Navigation, forms, interactive elements, responsiveness
- **Security Scanning**: CSRF tokens, HTTPS links, exposed data
- **Mobile Responsiveness**: Multi-viewport testing
- **Screenshot Capture**: Full page and mobile views
- **Data Refinery Specific**: ETL builder, pipeline monitoring, data sources analysis

## Installation

1. Navigate to the analysis directory:
```bash
cd analysis
```

2. Install dependencies:
```bash
npm install
```

## Usage

Make sure your Rails server is running on port 3000 (or specify a different port):

```bash
# In your Rails app directory
rails server
```

Then run the analyzer:

### Analyze specific pages:
```bash
# Analyze dashboard
npm run analyze:dashboard

# Analyze ETL pipeline builder
npm run analyze:etl

# Analyze specific page
node analyzer.js --page data_sources
```

### Analyze all pages:
```bash
npm run analyze:all
```

### Options:
```bash
# Use different port
node analyzer.js --port 3001 --page dashboard

# Run with visible browser (non-headless)
node analyzer.js --no-headless --page dashboard

# Get help
node analyzer.js --help
```

## Available Pages to Analyze

- `dashboard` - Main dashboard
- `etl_builder` - ETL Pipeline Builder list
- `etl_new` - New ETL Pipeline form
- `pipeline_monitoring` - Pipeline execution monitoring
- `data_sources` - Data sources list
- `data_sources_new` - New data source form
- `landing` - Landing page
- `login` - Login page

## Output

The analyzer generates two types of reports:

1. **JSON Report** (`reports/analysis_[timestamp].json`):
   - Detailed metrics and raw data
   - All issues and recommendations
   - Performance metrics

2. **HTML Report** (`reports/analysis_[timestamp].html`):
   - Visual presentation of findings
   - Categorized issues and recommendations
   - Easy-to-read format

3. **Screenshots** (`screenshots/`):
   - Full page captures
   - Mobile viewport captures

## Analysis Categories

### 1. Performance
- Page load time
- Resource sizes (JS, CSS, images)
- Number of HTTP requests
- First Contentful Paint
- DOM Content Loaded time

### 2. Accessibility
- Alt text for images
- Form labels
- Heading hierarchy
- ARIA labels
- Color contrast (basic check)

### 3. User Experience
- Navigation presence
- Search functionality
- Interactive elements count
- Loading indicators
- Breadcrumb navigation
- Mobile viewport meta tag

### 4. Security
- CSRF token presence
- HTTPS links
- Exposed email addresses
- Password field security

### 5. Responsiveness
- Horizontal scroll detection
- Multi-viewport testing (mobile, tablet, desktop)
- Layout issues

### 6. Data Refinery Specific
- ETL pipeline builder functionality
- Pipeline monitoring features
- Data source management
- Dashboard widgets and metrics

## Interpreting Results

### Issue Severities:
- **Critical** (Red): Must fix immediately (e.g., missing CSRF tokens, page not loading)
- **Warning** (Yellow): Should fix soon (e.g., slow load times, missing alt text)
- **Info** (Blue): Nice to have (e.g., missing breadcrumbs, few interactive elements)

### Recommendations:
Each recommendation includes:
- **Category**: Performance, UX, Security, Functionality
- **Priority**: Critical, High, Medium, Low
- **Specific action**: What to do to fix the issue

## Example Output

```
🚀 Starting Rails Application Analyzer...

📄 Analyzing dashboard: /dashboard
  🏃 Analyzing performance...
  ♿ Analyzing accessibility...
  🎨 Analyzing UX...
  🔒 Analyzing security...
  📱 Analyzing responsiveness...
  🏭 Analyzing Data Refinery specific features...

📊 Generating analysis report...

✅ Reports generated:
   JSON: /analysis/reports/analysis_1234567890.json
   HTML: /analysis/reports/analysis_1234567890.html

📋 Summary:
   Pages analyzed: 1
   Critical issues: 0
   Warnings: 3
   Info: 2
   Total recommendations: 5
```

## Extending the Analyzer

To add new analysis features:

1. Add new analysis method in the appropriate section
2. Update the metrics collection
3. Add issue detection logic
4. Generate recommendations based on findings

Example:
```javascript
async analyzeCustomFeature(pageResults) {
  const customMetrics = await this.page.evaluate(() => {
    // Your custom analysis logic
    return {
      hasFeature: !!document.querySelector('.my-feature'),
      featureCount: document.querySelectorAll('.feature-item').length
    };
  });
  
  pageResults.metrics.custom = customMetrics;
  
  if (!customMetrics.hasFeature) {
    this.addIssue('custom', 'warning', 'Custom feature not found', pageResults);
  }
}
```

## Troubleshooting

1. **Connection refused**: Make sure Rails server is running
2. **Timeout errors**: Increase timeout in page.goto() options
3. **Permission errors**: Run with appropriate permissions for screenshot directory
4. **Memory issues**: Analyze fewer pages at once

## Future Enhancements

- [ ] Lighthouse integration for more detailed performance metrics
- [ ] Automated accessibility testing with axe-core
- [ ] Visual regression testing
- [ ] Performance trend tracking
- [ ] CI/CD integration
- [ ] Custom Data Refinery-specific metrics
- [ ] API endpoint testing
- [ ] Database query performance analysis