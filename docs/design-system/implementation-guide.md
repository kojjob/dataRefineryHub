# DataFlow Pro Implementation Guide

This guide provides practical instructions for implementing the DataFlow Pro design system in your Rails application.

## Table of Contents

1. [Setup](#setup)
2. [Theme Configuration](#theme-configuration)
3. [Using Design Tokens](#using-design-tokens)
4. [Component Development](#component-development)
5. [Tailwind Integration](#tailwind-integration)
6. [Dark Mode Implementation](#dark-mode-implementation)
7. [Performance Optimization](#performance-optimization)
8. [Testing](#testing)

## Setup

### 1. CSS Architecture

The design system uses a layered CSS architecture:

```
app/assets/stylesheets/
├── application.tailwind.css    # Main Tailwind imports
├── dataflow_pro.css           # Design system tokens and components
├── dataflow_theme.css         # Alternative theme (if needed)
└── components/                # Component-specific styles
    ├── buttons.css
    ├── cards.css
    └── forms.css
```

### 2. Import Order

In `application.tailwind.css`:

```css
@import "tailwindcss/base";
@import "./dataflow_pro.css";     /* Design tokens */
@import "./components/index.css"; /* Component styles */
@import "tailwindcss/components";
@import "tailwindcss/utilities";
```

### 3. Configure Tailwind

Update `config/tailwind.config.js`:

```javascript
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js',
    './app/components/**/*'
  ],
  theme: {
    extend: {
      colors: {
        'df-primary': 'var(--color-primary)',
        'df-primary-hover': 'var(--color-primary-hover)',
        'df-background': 'var(--color-background)',
        'df-surface': 'var(--color-surface)',
        'df-text': 'var(--color-text)',
        'df-text-secondary': 'var(--color-text-secondary)',
        'df-border': 'var(--color-border)',
        // Add all other design tokens
      },
      spacing: {
        'df-1': 'var(--space-1)',
        'df-2': 'var(--space-2)',
        'df-4': 'var(--space-4)',
        // Add all spacing tokens
      },
      borderRadius: {
        'df-sm': 'var(--radius-sm)',
        'df-base': 'var(--radius-base)',
        'df-md': 'var(--radius-md)',
        'df-lg': 'var(--radius-lg)',
      },
      boxShadow: {
        'df-xs': 'var(--shadow-xs)',
        'df-sm': 'var(--shadow-sm)',
        'df-md': 'var(--shadow-md)',
        'df-lg': 'var(--shadow-lg)',
      },
      transitionDuration: {
        'df-fast': 'var(--duration-fast)',
        'df-normal': 'var(--duration-normal)',
      }
    }
  }
}
```

## Theme Configuration

### 1. HTML Setup

Add theme support to your layout:

```erb
<!-- app/views/layouts/application.html.erb -->
<!DOCTYPE html>
<html lang="en" data-color-scheme="light" class="theme-transition">
  <head>
    <!-- ... -->
  </head>
  <body class="bg-df-background text-df-text">
    <%= yield %>
  </body>
</html>
```

### 2. Theme Controller

Create a Stimulus controller for theme management:

```javascript
// app/javascript/controllers/theme_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle"]
  
  connect() {
    this.loadTheme()
    this.updateToggleState()
  }
  
  toggle() {
    const currentTheme = document.documentElement.getAttribute('data-color-scheme')
    const newTheme = currentTheme === 'light' ? 'dark' : 'light'
    this.setTheme(newTheme)
  }
  
  setTheme(theme) {
    document.documentElement.setAttribute('data-color-scheme', theme)
    localStorage.setItem('theme', theme)
    this.updateToggleState()
  }
  
  loadTheme() {
    const savedTheme = localStorage.getItem('theme')
    const systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
    const theme = savedTheme || systemTheme
    this.setTheme(theme)
  }
  
  updateToggleState() {
    const isDark = document.documentElement.getAttribute('data-color-scheme') === 'dark'
    if (this.hasToggleTarget) {
      this.toggleTarget.checked = isDark
    }
  }
}
```

## Using Design Tokens

### 1. In CSS

Always use CSS variables for consistency:

```css
/* Good */
.custom-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
}

/* Bad */
.custom-card {
  background: #FFFFFF;
  border: 1px solid rgba(94, 82, 64, 0.2);
  border-radius: 12px;
}
```

### 2. In Tailwind Classes

Use the extended Tailwind classes:

```erb
<!-- Good -->
<div class="bg-df-surface border border-df-border rounded-df-lg">

<!-- Bad -->
<div class="bg-white border border-gray-200 rounded-xl">
```

### 3. In JavaScript

Access design tokens programmatically:

```javascript
// Get computed styles
const styles = getComputedStyle(document.documentElement)
const primaryColor = styles.getPropertyValue('--color-primary')

// Update CSS variables dynamically
document.documentElement.style.setProperty('--color-primary', '#21808D')
```

## Component Development

### 1. ViewComponent Structure

Create reusable components using ViewComponent:

```ruby
# app/components/dataflow/button_component.rb
class Dataflow::ButtonComponent < ViewComponent::Base
  VARIANTS = {
    primary: "bg-df-primary text-white hover:bg-df-primary-hover",
    secondary: "bg-df-secondary text-df-text hover:bg-df-secondary-hover",
    outline: "border border-df-border text-df-text hover:bg-df-secondary"
  }.freeze
  
  SIZES = {
    sm: "px-3 py-1.5 text-sm",
    md: "px-4 py-2",
    lg: "px-5 py-2.5 text-lg"
  }.freeze
  
  def initialize(variant: :primary, size: :md, **options)
    @variant = variant
    @size = size
    @options = options
  end
  
  private
  
  def classes
    [
      base_classes,
      VARIANTS[@variant],
      SIZES[@size],
      @options[:class]
    ].compact.join(" ")
  end
  
  def base_classes
    "inline-flex items-center justify-center font-medium rounded-df-base 
     transition-colors duration-df-normal focus:outline-none focus:ring-2 
     focus:ring-df-primary focus:ring-offset-2"
  end
end
```

### 2. Component Usage

```erb
<%= render Dataflow::ButtonComponent.new(variant: :primary) do %>
  Get Started
<% end %>

<%= render Dataflow::ButtonComponent.new(variant: :outline, size: :sm) do %>
  Cancel
<% end %>
```

## Tailwind Integration

### 1. Custom Utilities

Add design system utilities to Tailwind:

```css
@layer utilities {
  .text-gradient {
    background: linear-gradient(135deg, var(--color-primary), var(--color-primary-hover));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }
  
  .card-hover {
    @apply transition-all duration-df-normal;
  }
  
  .card-hover:hover {
    @apply shadow-df-md -translate-y-0.5;
  }
}
```

### 2. Component Classes

Define reusable component classes:

```css
@layer components {
  .btn {
    @apply inline-flex items-center justify-center px-4 py-2 
           font-medium rounded-df-base transition-colors 
           duration-df-normal focus:outline-none focus:ring-2 
           focus:ring-df-primary;
  }
  
  .btn-primary {
    @apply btn bg-df-primary text-white hover:bg-df-primary-hover;
  }
  
  .card {
    @apply bg-df-surface border border-df-card-border 
           rounded-df-lg p-6 card-hover;
  }
}
```

## Dark Mode Implementation

### 1. CSS Variable Switching

The design system automatically switches variables based on `data-color-scheme`:

```css
:root[data-color-scheme="light"] {
  --color-primary: #21808D;
  --color-background: #FCFCF9;
  /* Light theme variables */
}

:root[data-color-scheme="dark"] {
  --color-primary: #32B8C6;
  --color-background: #1F2121;
  /* Dark theme variables */
}
```

### 2. Theme-Specific Styles

For styles that can't use CSS variables:

```css
/* Use data attribute selectors */
[data-color-scheme="dark"] .chart-grid {
  stroke: rgba(255, 255, 255, 0.1);
}

/* Or use Tailwind's dark variant with custom selector */
.dark\:custom-style {
  /* Dark mode specific styles */
}
```

### 3. Images and Icons

Handle theme-specific assets:

```erb
<%= image_tag theme_aware_image("logo"), alt: "Logo" %>

<%# Helper method %>
def theme_aware_image(name)
  theme = cookies[:theme] || "light"
  "#{name}-#{theme}.svg"
end
```

## Performance Optimization

### 1. CSS Loading Strategy

```erb
<!-- Preload critical CSS -->
<link rel="preload" href="<%= asset_path('dataflow_pro.css') %>" as="style">

<!-- Load non-critical CSS asynchronously -->
<link rel="preload" href="<%= asset_path('premium_effects.css') %>" as="style" 
      onload="this.onload=null;this.rel='stylesheet'">
```

### 2. Theme Transition Optimization

Prevent flash of unstyled content:

```javascript
// Add to <head> before CSS loads
(function() {
  const theme = localStorage.getItem('theme') || 'light';
  document.documentElement.setAttribute('data-color-scheme', theme);
})();
```

### 3. Component Lazy Loading

```javascript
// Lazy load heavy components
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async loadChart() {
    const { ChartComponent } = await import("./chart_component")
    new ChartComponent(this.element).render()
  }
}
```

## Testing

### 1. Component Tests

```ruby
# spec/components/dataflow/button_component_spec.rb
require "rails_helper"

RSpec.describe Dataflow::ButtonComponent, type: :component do
  it "renders primary button by default" do
    render_inline(described_class.new) { "Click me" }
    
    expect(page).to have_css(".bg-df-primary")
    expect(page).to have_text("Click me")
  end
  
  it "renders different variants" do
    render_inline(described_class.new(variant: :outline)) { "Cancel" }
    
    expect(page).to have_css(".border-df-border")
  end
end
```

### 2. Theme Testing

```ruby
# spec/system/theme_spec.rb
require "rails_helper"

RSpec.describe "Theme switching", type: :system, js: true do
  it "toggles between light and dark themes" do
    visit root_path
    
    expect(page).to have_css('[data-color-scheme="light"]')
    
    click_button "Toggle theme"
    
    expect(page).to have_css('[data-color-scheme="dark"]')
  end
end
```

### 3. Visual Regression Testing

```javascript
// cypress/e2e/visual.cy.js
describe('Visual Regression', () => {
  it('captures dashboard in light mode', () => {
    cy.visit('/dashboard')
    cy.screenshot('dashboard-light')
  })
  
  it('captures dashboard in dark mode', () => {
    cy.visit('/dashboard')
    cy.get('[data-theme-toggle]').click()
    cy.screenshot('dashboard-dark')
  })
})
```

## Best Practices

1. **Use semantic naming** - Component names should describe their purpose
2. **Keep specificity low** - Use single class selectors when possible
3. **Document variations** - Include examples of all component states
4. **Test accessibility** - Ensure proper contrast ratios and keyboard navigation
5. **Monitor bundle size** - Remove unused CSS with PurgeCSS in production