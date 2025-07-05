#!/bin/bash

echo "🚀 Setting up Rails Application Analyzer..."

# Install npm dependencies
echo "📦 Installing dependencies..."
npm install

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p screenshots
mkdir -p reports

# Make script executable
chmod +x analyzer.js

echo "✅ Setup complete!"
echo ""
echo "To use the analyzer:"
echo "1. Make sure your Rails server is running: rails server"
echo "2. Run the analyzer:"
echo "   - Analyze all pages: npm run analyze:all"
echo "   - Analyze dashboard: npm run analyze:dashboard"
echo "   - Analyze specific page: node analyzer.js --page etl_builder"
echo ""
echo "For more options, run: node analyzer.js --help"