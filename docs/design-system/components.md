# DataFlow Pro Components Guide

This guide provides detailed implementation examples for all DataFlow Pro design system components.

## Table of Contents

1. [Buttons](#buttons)
2. [Cards](#cards)
3. [Form Controls](#form-controls)
4. [Navigation](#navigation)
5. [Status Indicators](#status-indicators)
6. [Charts & Visualizations](#charts--visualizations)
7. [Modals & Overlays](#modals--overlays)
8. [Loading States](#loading-states)

## Buttons

### Primary Button

```erb
<%= link_to "Get Started", new_data_source_path, 
    class: "inline-flex items-center px-4 py-2 bg-df-primary text-white 
           font-medium rounded-lg hover:bg-df-primary-hover 
           transition-colors duration-250 ease-standard" %>
```

### Secondary Button

```erb
<button type="button" 
        class="px-4 py-2 bg-df-secondary text-df-text rounded-lg 
               hover:bg-df-secondary-hover transition-colors duration-250">
  Cancel
</button>
```

### Icon Button

```erb
<button type="button" 
        class="p-2 rounded-lg hover:bg-df-secondary transition-colors">
  <%= icon_helper("settings", class: "w-5 h-5 text-df-text-secondary") %>
</button>
```

### Button Group

```erb
<div class="inline-flex rounded-lg border border-df-border overflow-hidden">
  <button class="px-4 py-2 bg-df-primary text-white">Day</button>
  <button class="px-4 py-2 hover:bg-df-secondary">Week</button>
  <button class="px-4 py-2 hover:bg-df-secondary">Month</button>
</div>
```

## Cards

### Metric Card Component

```ruby
# app/components/dataflow/metric_card_component.rb
class Dataflow::MetricCardComponent < ViewComponent::Base
  def initialize(title:, value:, change: nil, icon: nil)
    @title = title
    @value = value
    @change = change
    @icon = icon
  end

  private

  def change_class
    return "" unless @change
    @change[:direction] == "up" ? "text-df-success" : "text-df-error"
  end

  def change_icon
    @change[:direction] == "up" ? "trending-up" : "trending-down"
  end
end
```

```erb
<!-- app/components/dataflow/metric_card_component.html.erb -->
<div class="bg-df-surface border border-df-card-border rounded-xl p-6 
            hover:shadow-df-md hover:-translate-y-0.5 transition-all duration-250">
  <div class="flex items-start justify-between">
    <div class="flex-1">
      <p class="text-df-text-secondary text-sm font-medium mb-1"><%= @title %></p>
      <p class="text-3xl font-semibold text-df-text"><%= @value %></p>
      
      <% if @change %>
        <div class="flex items-center gap-1 mt-2 <%= change_class %>">
          <%= icon_helper(change_icon, class: "w-4 h-4") %>
          <span class="text-sm font-medium"><%= @change[:value] %></span>
          <span class="text-xs text-df-text-secondary">vs last period</span>
        </div>
      <% end %>
    </div>
    
    <% if @icon %>
      <div class="p-3 bg-gradient-to-br from-df-primary to-df-primary-hover 
                  rounded-lg text-white">
        <%= icon_helper(@icon, class: "w-6 h-6") %>
      </div>
    <% end %>
  </div>
</div>
```

### Insight Card

```erb
<div class="bg-df-surface border border-df-card-border rounded-xl p-6 
            border-t-4 border-t-df-warning">
  <div class="flex items-start justify-between mb-4">
    <h3 class="font-semibold text-df-text">Revenue trending down</h3>
    <span class="px-2 py-1 bg-df-warning/15 text-df-warning rounded-md text-xs font-medium">
      High Priority
    </span>
  </div>
  
  <p class="text-df-text-secondary text-sm mb-4">
    Revenue has decreased by 15% compared to last month's average.
  </p>
  
  <div class="flex items-center justify-between">
    <span class="text-xs text-df-text-secondary">85% confidence</span>
    <button class="text-sm text-df-primary hover:text-df-primary-hover font-medium">
      View Details →
    </button>
  </div>
</div>
```

## Form Controls

### Input Field

```erb
<div class="space-y-1">
  <%= form.label :email, class: "block text-sm font-medium text-df-text" %>
  <%= form.email_field :email, 
      class: "w-full px-3 py-2 bg-df-surface border border-df-border 
              rounded-lg focus:outline-none focus:ring-2 focus:ring-df-primary 
              focus:border-transparent transition-all",
      placeholder: "you@example.com" %>
</div>
```

### Select Dropdown

```erb
<div class="space-y-1">
  <%= form.label :data_source, class: "block text-sm font-medium text-df-text" %>
  <div class="relative">
    <%= form.select :data_source, 
        options_for_select([["Shopify", "shopify"], ["QuickBooks", "quickbooks"]]),
        { prompt: "Select a data source" },
        class: "w-full px-3 py-2 bg-df-surface border border-df-border 
                rounded-lg appearance-none focus:outline-none focus:ring-2 
                focus:ring-df-primary pr-10" %>
    <div class="absolute inset-y-0 right-0 flex items-center px-2 pointer-events-none">
      <%= icon_helper("chevron-down", class: "w-5 h-5 text-df-text-secondary") %>
    </div>
  </div>
</div>
```

### Checkbox

```erb
<label class="flex items-center space-x-3 cursor-pointer">
  <%= form.check_box :remember_me, 
      class: "w-4 h-4 text-df-primary bg-df-surface border-df-border 
              rounded focus:ring-df-primary focus:ring-2" %>
  <span class="text-sm text-df-text">Remember me</span>
</label>
```

### Toggle Switch

```erb
<label class="relative inline-flex items-center cursor-pointer">
  <input type="checkbox" class="sr-only peer" />
  <div class="w-11 h-6 bg-df-secondary rounded-full peer 
              peer-checked:bg-df-primary transition-colors
              after:content-[''] after:absolute after:top-[2px] after:left-[2px] 
              after:bg-white after:rounded-full after:h-5 after:w-5 
              after:transition-all peer-checked:after:translate-x-full">
  </div>
</label>
```

## Navigation

### Sidebar Navigation

```erb
<nav class="w-[280px] h-full bg-df-surface border-r border-df-border">
  <div class="p-6">
    <h1 class="text-xl font-semibold text-df-text">DataFlow Pro</h1>
  </div>
  
  <ul class="px-3 space-y-1">
    <li>
      <%= link_to dashboard_path,
          class: "flex items-center gap-3 px-3 py-2 rounded-lg
                  hover:bg-df-secondary transition-colors
                  #{'bg-df-secondary border-l-4 border-df-primary -ml-[5px] pl-[13px]' if current_page?(dashboard_path)}" do %>
        <%= icon_helper("dashboard", class: "w-5 h-5 text-df-text-secondary") %>
        <span class="text-sm font-medium text-df-text">Dashboard</span>
      <% end %>
    </li>
  </ul>
</nav>
```

### Breadcrumbs

```erb
<nav class="flex items-center space-x-2 text-sm">
  <%= link_to "Home", root_path, class: "text-df-text-secondary hover:text-df-text" %>
  <span class="text-df-text-secondary">/</span>
  <%= link_to "Data Sources", data_sources_path, class: "text-df-text-secondary hover:text-df-text" %>
  <span class="text-df-text-secondary">/</span>
  <span class="text-df-text font-medium">Shopify</span>
</nav>
```

## Status Indicators

### Status Badge

```erb
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium
             <%= status_class(status) %>">
  <%= status.humanize %>
</span>

<%# Helper method %>
<% def status_class(status)
  case status
  when "active"
    "bg-df-success/15 text-df-success"
  when "error"
    "bg-df-error/15 text-df-error"
  when "pending"
    "bg-df-warning/15 text-df-warning"
  else
    "bg-df-info/15 text-df-info"
  end
end %>
```

### Progress Bar

```erb
<div class="w-full bg-df-secondary rounded-full h-2">
  <div class="bg-df-primary h-2 rounded-full transition-all duration-500"
       style="width: <%= progress %>%">
  </div>
</div>
```

## Charts & Visualizations

### Chart Container

```erb
<div class="bg-df-surface border border-df-card-border rounded-xl">
  <div class="flex items-center justify-between p-6 border-b border-df-border">
    <h3 class="font-semibold text-df-text">Revenue Overview</h3>
    <div class="flex items-center gap-2">
      <button class="px-3 py-1 text-sm rounded-lg hover:bg-df-secondary">Day</button>
      <button class="px-3 py-1 text-sm rounded-lg bg-df-primary text-white">Week</button>
      <button class="px-3 py-1 text-sm rounded-lg hover:bg-df-secondary">Month</button>
    </div>
  </div>
  <div class="p-6">
    <div class="h-[300px]" data-chart-container>
      <!-- Chart content -->
    </div>
  </div>
</div>
```

## Modals & Overlays

### Modal

```erb
<div class="fixed inset-0 z-50 overflow-y-auto" data-modal>
  <!-- Backdrop -->
  <div class="fixed inset-0 bg-black/50 transition-opacity"></div>
  
  <!-- Modal -->
  <div class="flex min-h-full items-center justify-center p-4">
    <div class="relative bg-df-surface rounded-xl shadow-df-lg max-w-md w-full p-6">
      <h2 class="text-lg font-semibold text-df-text mb-4">Modal Title</h2>
      <p class="text-df-text-secondary mb-6">Modal content goes here.</p>
      
      <div class="flex gap-3 justify-end">
        <button class="px-4 py-2 text-df-text hover:bg-df-secondary rounded-lg">
          Cancel
        </button>
        <button class="px-4 py-2 bg-df-primary text-white rounded-lg hover:bg-df-primary-hover">
          Confirm
        </button>
      </div>
    </div>
  </div>
</div>
```

## Loading States

### Skeleton Loader

```erb
<div class="animate-pulse">
  <div class="h-4 bg-df-secondary rounded w-3/4 mb-2"></div>
  <div class="h-4 bg-df-secondary rounded w-1/2"></div>
</div>
```

### Spinner

```erb
<div class="inline-flex items-center justify-center">
  <div class="animate-spin rounded-full h-8 w-8 border-2 border-df-primary border-t-transparent"></div>
</div>
```

### Loading Card

```erb
<div class="bg-df-surface border border-df-card-border rounded-xl p-6">
  <div class="animate-pulse space-y-3">
    <div class="h-4 bg-df-secondary rounded w-1/3"></div>
    <div class="h-8 bg-df-secondary rounded w-2/3"></div>
    <div class="h-4 bg-df-secondary rounded w-1/2"></div>
  </div>
</div>
```

## Best Practices

1. **Always use design tokens** - Reference CSS variables instead of hardcoding values
2. **Maintain consistency** - Use the same patterns across similar components
3. **Consider accessibility** - Include proper ARIA labels and keyboard navigation
4. **Test responsiveness** - Ensure components work on all screen sizes
5. **Optimize performance** - Use Stimulus controllers for interactivity when needed