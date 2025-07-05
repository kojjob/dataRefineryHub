import puppeteer from 'puppeteer';
import chalk from 'chalk';
import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Parse command line arguments
const argv = yargs(hideBin(process.argv))
  .option('page', {
    alias: 'p',
    description: 'Specific page to analyze',
    type: 'string',
  })
  .option('all', {
    alias: 'a',
    description: 'Analyze all pages',
    type: 'boolean',
  })
  .option('port', {
    description: 'Rails server port',
    type: 'number',
    default: 3000
  })
  .option('headless', {
    description: 'Run in headless mode',
    type: 'boolean',
    default: true
  })
  .help()
  .alias('help', 'h')
  .argv;

// Configuration
const BASE_URL = `http://localhost:${argv.port}`;
const PAGES_TO_ANALYZE = {
  dashboard: '/dashboard',
  etl_builder: '/etl_pipeline_builders',
  etl_new: '/etl_pipeline_builders/new',
  pipeline_monitoring: '/pipeline_monitoring',
  data_sources: '/data_sources',
  data_sources_new: '/data_sources/new',
  landing: '/',
  login: '/users/sign_in'
};

class RailsAppAnalyzer {
  constructor() {
    this.browser = null;
    this.page = null;
    this.results = {
      timestamp: new Date().toISOString(),
      pages: {},
      summary: {
        totalPages: 0,
        issues: {
          critical: 0,
          warning: 0,
          info: 0
        },
        recommendations: []
      }
    };
  }

  async initialize() {
    console.log(chalk.blue('🚀 Starting Rails Application Analyzer...'));
    
    this.browser = await puppeteer.launch({
      headless: argv.headless,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
      defaultViewport: {
        width: 1920,
        height: 1080
      }
    });
    
    this.page = await this.browser.newPage();
    
    // Enable various metrics collection
    await this.page.setViewport({ width: 1920, height: 1080 });
    await this.page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    
    // Set up console message listener
    this.page.on('console', msg => {
      if (msg.type() === 'error') {
        this.addIssue('console_error', 'warning', `Console error: ${msg.text()}`);
      }
    });
    
    // Set up request monitoring
    await this.page.setRequestInterception(true);
    this.page.on('request', request => {
      // Track requests for analysis
      request.continue();
    });
  }

  async analyzePage(pageName, url) {
    console.log(chalk.yellow(`\n📄 Analyzing ${pageName}: ${url}`));
    
    const pageResults = {
      url: url,
      loadTime: 0,
      metrics: {},
      issues: [],
      recommendations: [],
      screenshots: {}
    };

    try {
      // Navigate to page and measure load time
      const startTime = Date.now();
      const response = await this.page.goto(BASE_URL + url, {
        waitUntil: 'networkidle2',
        timeout: 30000
      });
      const loadTime = Date.now() - startTime;
      pageResults.loadTime = loadTime;

      // Check response status
      if (!response || !response.ok()) {
        this.addIssue('http_error', 'critical', 
          `Page returned status ${response?.status() || 'unknown'}`, 
          pageResults);
      }

      // Take screenshots
      await this.takeScreenshots(pageName, pageResults);

      // Perform various analyses
      await this.analyzePerformance(pageResults);
      await this.analyzeAccessibility(pageResults);
      await this.analyzeUX(pageResults);
      await this.analyzeSecurity(pageResults);
      await this.analyzeResponsiveness(pageResults);
      await this.analyzeDataRefinery(pageName, pageResults);

      // Generate recommendations
      this.generateRecommendations(pageName, pageResults);

    } catch (error) {
      this.addIssue('navigation_error', 'critical', 
        `Failed to analyze page: ${error.message}`, 
        pageResults);
    }

    this.results.pages[pageName] = pageResults;
    this.results.summary.totalPages++;
  }

  async takeScreenshots(pageName, pageResults) {
    try {
      // Full page screenshot
      const screenshotPath = path.join(__dirname, 'screenshots', `${pageName}_full.png`);
      await fs.mkdir(path.dirname(screenshotPath), { recursive: true });
      await this.page.screenshot({
        path: screenshotPath,
        fullPage: true
      });
      pageResults.screenshots.full = screenshotPath;

      // Mobile viewport
      await this.page.setViewport({ width: 375, height: 667 });
      const mobileScreenshotPath = path.join(__dirname, 'screenshots', `${pageName}_mobile.png`);
      await this.page.screenshot({
        path: mobileScreenshotPath
      });
      pageResults.screenshots.mobile = mobileScreenshotPath;

      // Reset viewport
      await this.page.setViewport({ width: 1920, height: 1080 });
    } catch (error) {
      console.error(chalk.red(`Screenshot failed: ${error.message}`));
    }
  }

  async analyzePerformance(pageResults) {
    console.log(chalk.gray('  🏃 Analyzing performance...'));
    
    const metrics = await this.page.evaluate(() => {
      const perfData = performance.getEntriesByType('navigation')[0];
      return {
        domContentLoaded: perfData.domContentLoadedEventEnd - perfData.domContentLoadedEventStart,
        loadComplete: perfData.loadEventEnd - perfData.loadEventStart,
        firstPaint: performance.getEntriesByName('first-paint')[0]?.startTime || 0,
        firstContentfulPaint: performance.getEntriesByName('first-contentful-paint')[0]?.startTime || 0
      };
    });

    pageResults.metrics.performance = metrics;

    // Check for performance issues
    if (pageResults.loadTime > 3000) {
      this.addIssue('slow_load', 'warning', 
        `Page load time is ${pageResults.loadTime}ms (should be < 3000ms)`, 
        pageResults);
    }

    // Check resource sizes
    const resourceSizes = await this.page.evaluate(() => {
      const resources = performance.getEntriesByType('resource');
      let totalSize = 0;
      let jsSize = 0;
      let cssSize = 0;
      let imageSize = 0;

      resources.forEach(resource => {
        totalSize += resource.transferSize || 0;
        if (resource.name.includes('.js')) jsSize += resource.transferSize || 0;
        if (resource.name.includes('.css')) cssSize += resource.transferSize || 0;
        if (resource.name.match(/\.(jpg|jpeg|png|gif|webp)/)) imageSize += resource.transferSize || 0;
      });

      return { totalSize, jsSize, cssSize, imageSize, resourceCount: resources.length };
    });

    pageResults.metrics.resources = resourceSizes;

    if (resourceSizes.totalSize > 5000000) { // 5MB
      this.addIssue('large_page_size', 'warning', 
        `Total page size is ${(resourceSizes.totalSize / 1024 / 1024).toFixed(2)}MB`, 
        pageResults);
    }
  }

  async analyzeAccessibility(pageResults) {
    console.log(chalk.gray('  ♿ Analyzing accessibility...'));
    
    try {
      // Check for basic accessibility issues
      const accessibilityIssues = await this.page.evaluate(() => {
        const issues = [];
        
        // Check for images without alt text
        const imagesWithoutAlt = document.querySelectorAll('img:not([alt])');
        if (imagesWithoutAlt.length > 0) {
          issues.push({
            type: 'missing_alt_text',
            count: imagesWithoutAlt.length,
            elements: Array.from(imagesWithoutAlt).slice(0, 5).map(img => img.src)
          });
        }

        // Check for form labels
        const inputsWithoutLabels = document.querySelectorAll('input:not([type="hidden"]):not([type="submit"]):not([aria-label])');
        let unlabeledInputs = 0;
        inputsWithoutLabels.forEach(input => {
          if (!input.id || !document.querySelector(`label[for="${input.id}"]`)) {
            unlabeledInputs++;
          }
        });
        if (unlabeledInputs > 0) {
          issues.push({
            type: 'missing_form_labels',
            count: unlabeledInputs
          });
        }

        // Check heading hierarchy
        const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
        let lastLevel = 0;
        let hierarchyBroken = false;
        headings.forEach(heading => {
          const level = parseInt(heading.tagName[1]);
          if (level > lastLevel + 1 && lastLevel !== 0) {
            hierarchyBroken = true;
          }
          lastLevel = level;
        });
        if (hierarchyBroken) {
          issues.push({ type: 'broken_heading_hierarchy' });
        }

        // Check color contrast (simplified)
        const lowContrastElements = [];
        const elements = document.querySelectorAll('*');
        elements.forEach(el => {
          const style = window.getComputedStyle(el);
          const bg = style.backgroundColor;
          const fg = style.color;
          // This is a simplified check - real contrast calculation is more complex
          if (bg !== 'rgba(0, 0, 0, 0)' && fg && bg.includes('rgb') && fg.includes('rgb')) {
            // Add to check list
          }
        });

        return issues;
      });

      pageResults.metrics.accessibility = accessibilityIssues;

      accessibilityIssues.forEach(issue => {
        if (issue.type === 'missing_alt_text') {
          this.addIssue('accessibility', 'warning', 
            `${issue.count} images missing alt text`, 
            pageResults);
        }
        if (issue.type === 'missing_form_labels') {
          this.addIssue('accessibility', 'warning', 
            `${issue.count} form inputs missing labels`, 
            pageResults);
        }
      });

    } catch (error) {
      console.error(chalk.red(`Accessibility analysis failed: ${error.message}`));
    }
  }

  async analyzeUX(pageResults) {
    console.log(chalk.gray('  🎨 Analyzing UX...'));
    
    const uxMetrics = await this.page.evaluate(() => {
      const metrics = {
        hasNavigation: !!document.querySelector('nav, [role="navigation"]'),
        hasSearch: !!document.querySelector('input[type="search"], input[placeholder*="search" i]'),
        formCount: document.querySelectorAll('form').length,
        linkCount: document.querySelectorAll('a').length,
        buttonCount: document.querySelectorAll('button, input[type="submit"]').length,
        hasFooter: !!document.querySelector('footer'),
        hasBreadcrumbs: !!document.querySelector('[aria-label="breadcrumb"], .breadcrumb')
      };

      // Check for interactive elements
      metrics.interactiveElements = document.querySelectorAll('button, a, input, select, textarea').length;
      
      // Check viewport meta tag
      metrics.hasViewportMeta = !!document.querySelector('meta[name="viewport"]');
      
      // Check for loading indicators
      metrics.hasLoadingIndicators = !!document.querySelector('[class*="loading"], [class*="spinner"], [class*="loader"]');

      return metrics;
    });

    pageResults.metrics.ux = uxMetrics;

    // Generate UX recommendations
    if (!uxMetrics.hasViewportMeta) {
      this.addIssue('ux', 'critical', 
        'Missing viewport meta tag for responsive design', 
        pageResults);
    }

    if (uxMetrics.interactiveElements < 5) {
      this.addIssue('ux', 'info', 
        'Page has very few interactive elements', 
        pageResults);
    }
  }

  async analyzeSecurity(pageResults) {
    console.log(chalk.gray('  🔒 Analyzing security...'));
    
    const securityChecks = await this.page.evaluate(() => {
      const checks = {
        hasCSRFToken: !!document.querySelector('meta[name="csrf-token"]'),
        hasSecureLinks: true,
        exposedEmails: [],
        hasPasswordFields: !!document.querySelector('input[type="password"]')
      };

      // Check for non-HTTPS links
      document.querySelectorAll('a[href^="http://"]').forEach(link => {
        if (!link.href.includes('localhost')) {
          checks.hasSecureLinks = false;
        }
      });

      // Check for exposed emails
      const emailRegex = /([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z0-9_-]+)/gi;
      const pageText = document.body.innerText;
      const emails = pageText.match(emailRegex) || [];
      checks.exposedEmails = [...new Set(emails)];

      return checks;
    });

    pageResults.metrics.security = securityChecks;

    if (!securityChecks.hasCSRFToken) {
      this.addIssue('security', 'critical', 
        'Missing CSRF token meta tag', 
        pageResults);
    }

    if (!securityChecks.hasSecureLinks) {
      this.addIssue('security', 'warning', 
        'Found non-HTTPS links on the page', 
        pageResults);
    }

    if (securityChecks.exposedEmails.length > 0) {
      this.addIssue('security', 'info', 
        `Found ${securityChecks.exposedEmails.length} exposed email addresses`, 
        pageResults);
    }
  }

  async analyzeResponsiveness(pageResults) {
    console.log(chalk.gray('  📱 Analyzing responsiveness...'));
    
    const viewports = [
      { name: 'mobile', width: 375, height: 667 },
      { name: 'tablet', width: 768, height: 1024 },
      { name: 'desktop', width: 1920, height: 1080 }
    ];

    const responsiveIssues = [];

    for (const viewport of viewports) {
      await this.page.setViewport(viewport);
      
      const issues = await this.page.evaluate((viewportName) => {
        const issues = [];
        
        // Check for horizontal scroll
        if (document.documentElement.scrollWidth > window.innerWidth) {
          issues.push({
            type: 'horizontal_scroll',
            viewport: viewportName
          });
        }

        // Check for overlapping elements
        const elements = document.querySelectorAll('div, section, article, nav, header, footer');
        // Simplified overlap detection
        
        return issues;
      }, viewport.name);

      responsiveIssues.push(...issues);
    }

    pageResults.metrics.responsiveness = responsiveIssues;

    responsiveIssues.forEach(issue => {
      if (issue.type === 'horizontal_scroll') {
        this.addIssue('responsive', 'warning', 
          `Horizontal scroll detected on ${issue.viewport} viewport`, 
          pageResults);
      }
    });

    // Reset to desktop viewport
    await this.page.setViewport({ width: 1920, height: 1080 });
  }

  async analyzeDataRefinery(pageName, pageResults) {
    console.log(chalk.gray('  🏭 Analyzing Data Refinery specific features...'));
    
    // Page-specific analysis
    switch (pageName) {
      case 'etl_builder':
      case 'etl_new':
        await this.analyzeETLBuilder(pageResults);
        break;
      case 'pipeline_monitoring':
        await this.analyzePipelineMonitoring(pageResults);
        break;
      case 'data_sources':
      case 'data_sources_new':
        await this.analyzeDataSources(pageResults);
        break;
      case 'dashboard':
        await this.analyzeDashboard(pageResults);
        break;
    }
  }

  async analyzeETLBuilder(pageResults) {
    const etlMetrics = await this.page.evaluate(() => {
      return {
        hasPipelineForm: !!document.querySelector('form[data-controller*="pipeline"]'),
        hasStepNavigation: !!document.querySelector('[data-pipeline-builder-target]'),
        hasTransformationRules: !!document.querySelector('[class*="transformation"]'),
        hasScheduleConfig: !!document.querySelector('[class*="schedule"]'),
        formFieldCount: document.querySelectorAll('input, select, textarea').length
      };
    });

    pageResults.metrics.etl = etlMetrics;

    if (!etlMetrics.hasPipelineForm) {
      this.addIssue('functionality', 'critical', 
        'ETL pipeline form not found', 
        pageResults);
    }

    if (etlMetrics.formFieldCount < 5) {
      this.addIssue('functionality', 'warning', 
        'ETL form seems to have very few fields', 
        pageResults);
    }
  }

  async analyzePipelineMonitoring(pageResults) {
    const monitoringMetrics = await this.page.evaluate(() => {
      return {
        hasExecutionList: !!document.querySelector('[class*="execution"]'),
        hasStatusIndicators: document.querySelectorAll('[class*="status"], [class*="badge"]').length,
        hasCharts: !!document.querySelector('canvas, svg[class*="chart"]'),
        hasRealTimeElements: !!document.querySelector('[data-controller*="live"], [data-controller*="real-time"]')
      };
    });

    pageResults.metrics.monitoring = monitoringMetrics;

    if (!monitoringMetrics.hasExecutionList) {
      this.addIssue('functionality', 'warning', 
        'Pipeline execution list not found', 
        pageResults);
    }

    if (!monitoringMetrics.hasRealTimeElements) {
      this.addIssue('functionality', 'info', 
        'No real-time update elements detected', 
        pageResults);
    }
  }

  async analyzeDataSources(pageResults) {
    const dataSourceMetrics = await this.page.evaluate(() => {
      return {
        hasSourceList: !!document.querySelector('[class*="data-source"]'),
        sourceTypes: Array.from(document.querySelectorAll('[class*="source-type"]')).map(el => el.textContent),
        hasAddButton: !!document.querySelector('a[href*="data_sources/new"], button[class*="add"]'),
        hasFilters: !!document.querySelector('[class*="filter"], [class*="search"]')
      };
    });

    pageResults.metrics.dataSources = dataSourceMetrics;

    if (!dataSourceMetrics.hasSourceList) {
      this.addIssue('functionality', 'warning', 
        'Data source list not found', 
        pageResults);
    }
  }

  async analyzeDashboard(pageResults) {
    const dashboardMetrics = await this.page.evaluate(() => {
      return {
        widgetCount: document.querySelectorAll('[class*="widget"], [class*="card"]').length,
        hasCharts: !!document.querySelector('canvas, svg[class*="chart"]'),
        hasMetrics: document.querySelectorAll('[class*="metric"], [class*="stat"]').length,
        hasNavigation: !!document.querySelector('nav, [class*="sidebar"]')
      };
    });

    pageResults.metrics.dashboard = dashboardMetrics;

    if (dashboardMetrics.widgetCount < 3) {
      this.addIssue('functionality', 'info', 
        'Dashboard has very few widgets', 
        pageResults);
    }
  }

  generateRecommendations(pageName, pageResults) {
    const recommendations = [];

    // Performance recommendations
    if (pageResults.loadTime > 2000) {
      recommendations.push({
        category: 'Performance',
        priority: 'High',
        recommendation: 'Optimize page load time by implementing caching, lazy loading, and minimizing assets'
      });
    }

    if (pageResults.metrics.resources?.resourceCount > 50) {
      recommendations.push({
        category: 'Performance',
        priority: 'Medium',
        recommendation: 'Reduce the number of HTTP requests by bundling assets and using sprites'
      });
    }

    // UX recommendations
    if (!pageResults.metrics.ux?.hasSearch && ['dashboard', 'data_sources', 'etl_builder'].includes(pageName)) {
      recommendations.push({
        category: 'UX',
        priority: 'Medium',
        recommendation: 'Add search functionality to help users find content quickly'
      });
    }

    if (!pageResults.metrics.ux?.hasBreadcrumbs && pageName !== 'landing') {
      recommendations.push({
        category: 'UX',
        priority: 'Low',
        recommendation: 'Add breadcrumb navigation to improve user orientation'
      });
    }

    // Security recommendations
    if (!pageResults.metrics.security?.hasCSRFToken) {
      recommendations.push({
        category: 'Security',
        priority: 'Critical',
        recommendation: 'Implement CSRF protection tokens on all forms'
      });
    }

    // ETL-specific recommendations
    if (pageName === 'etl_builder' && !pageResults.metrics.etl?.hasTransformationRules) {
      recommendations.push({
        category: 'Functionality',
        priority: 'High',
        recommendation: 'Add visual transformation rule builder to simplify ETL pipeline creation'
      });
    }

    if (pageName === 'pipeline_monitoring' && !pageResults.metrics.monitoring?.hasCharts) {
      recommendations.push({
        category: 'Functionality',
        priority: 'Medium',
        recommendation: 'Add performance charts and metrics visualization to the monitoring dashboard'
      });
    }

    pageResults.recommendations = recommendations;
    this.results.summary.recommendations.push(...recommendations.map(r => ({
      ...r,
      page: pageName
    })));
  }

  addIssue(type, severity, message, pageResults = null) {
    const issue = { type, severity, message };
    
    if (pageResults) {
      pageResults.issues.push(issue);
    }
    
    this.results.summary.issues[severity]++;
  }

  async generateReport() {
    console.log(chalk.blue('\n📊 Generating analysis report...'));
    
    const reportPath = path.join(__dirname, 'reports', `analysis_${Date.now()}.json`);
    await fs.mkdir(path.dirname(reportPath), { recursive: true });
    await fs.writeFile(reportPath, JSON.stringify(this.results, null, 2));
    
    // Generate HTML report
    const htmlReport = this.generateHTMLReport();
    const htmlPath = path.join(__dirname, 'reports', `analysis_${Date.now()}.html`);
    await fs.writeFile(htmlPath, htmlReport);
    
    console.log(chalk.green(`\n✅ Reports generated:`));
    console.log(chalk.gray(`   JSON: ${reportPath}`));
    console.log(chalk.gray(`   HTML: ${htmlPath}`));
    
    // Print summary
    console.log(chalk.yellow('\n📋 Summary:'));
    console.log(`   Pages analyzed: ${this.results.summary.totalPages}`);
    console.log(`   Critical issues: ${chalk.red(this.results.summary.issues.critical)}`);
    console.log(`   Warnings: ${chalk.yellow(this.results.summary.issues.warning)}`);
    console.log(`   Info: ${chalk.blue(this.results.summary.issues.info)}`);
    console.log(`   Total recommendations: ${this.results.summary.recommendations.length}`);
  }

  generateHTMLReport() {
    return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rails App Analysis Report - ${new Date().toLocaleDateString()}</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 1200px; margin: 0 auto; padding: 20px; }
        h1, h2, h3 { color: #2c3e50; }
        .summary { background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 30px; }
        .page-section { background: white; border: 1px solid #e9ecef; border-radius: 8px; padding: 20px; margin-bottom: 20px; }
        .issue { padding: 10px; margin: 5px 0; border-radius: 4px; }
        .issue.critical { background: #f8d7da; color: #721c24; }
        .issue.warning { background: #fff3cd; color: #856404; }
        .issue.info { background: #d1ecf1; color: #0c5460; }
        .recommendation { background: #d4edda; color: #155724; padding: 10px; margin: 5px 0; border-radius: 4px; }
        .metric { display: inline-block; background: #e9ecef; padding: 5px 10px; margin: 2px; border-radius: 4px; }
        .screenshot { max-width: 100%; margin: 10px 0; border: 1px solid #dee2e6; }
    </style>
</head>
<body>
    <h1>Rails Application Analysis Report</h1>
    <p>Generated: ${new Date().toLocaleString()}</p>
    
    <div class="summary">
        <h2>Summary</h2>
        <p>Pages Analyzed: ${this.results.summary.totalPages}</p>
        <p>Critical Issues: ${this.results.summary.issues.critical}</p>
        <p>Warnings: ${this.results.summary.issues.warning}</p>
        <p>Info: ${this.results.summary.issues.info}</p>
        <p>Total Recommendations: ${this.results.summary.recommendations.length}</p>
    </div>
    
    ${Object.entries(this.results.pages).map(([pageName, pageData]) => `
        <div class="page-section">
            <h2>${pageName}</h2>
            <p>URL: ${pageData.url}</p>
            <p>Load Time: ${pageData.loadTime}ms</p>
            
            <h3>Issues</h3>
            ${pageData.issues.length > 0 ? pageData.issues.map(issue => `
                <div class="issue ${issue.severity}">${issue.message}</div>
            `).join('') : '<p>No issues found</p>'}
            
            <h3>Recommendations</h3>
            ${pageData.recommendations.length > 0 ? pageData.recommendations.map(rec => `
                <div class="recommendation">[${rec.category}] ${rec.recommendation}</div>
            `).join('') : '<p>No specific recommendations</p>'}
            
            <h3>Metrics</h3>
            ${Object.entries(pageData.metrics).map(([category, data]) => `
                <div>
                    <h4>${category}</h4>
                    <pre>${JSON.stringify(data, null, 2)}</pre>
                </div>
            `).join('')}
        </div>
    `).join('')}
    
    <div class="summary">
        <h2>Overall Recommendations</h2>
        ${this.results.summary.recommendations.map(rec => `
            <div class="recommendation">
                <strong>${rec.page}</strong> - [${rec.priority}] ${rec.recommendation}
            </div>
        `).join('')}
    </div>
</body>
</html>
    `;
  }

  async cleanup() {
    if (this.browser) {
      await this.browser.close();
    }
  }

  async run() {
    try {
      await this.initialize();
      
      if (argv.all) {
        // Analyze all pages
        for (const [pageName, url] of Object.entries(PAGES_TO_ANALYZE)) {
          await this.analyzePage(pageName, url);
        }
      } else if (argv.page) {
        // Analyze specific page
        const url = PAGES_TO_ANALYZE[argv.page];
        if (url) {
          await this.analyzePage(argv.page, url);
        } else {
          console.error(chalk.red(`Unknown page: ${argv.page}`));
          console.log('Available pages:', Object.keys(PAGES_TO_ANALYZE).join(', '));
        }
      } else {
        // Default: analyze dashboard
        await this.analyzePage('dashboard', PAGES_TO_ANALYZE.dashboard);
      }
      
      await this.generateReport();
      
    } catch (error) {
      console.error(chalk.red('Analysis failed:'), error);
    } finally {
      await this.cleanup();
    }
  }
}

// Run the analyzer
const analyzer = new RailsAppAnalyzer();
analyzer.run();