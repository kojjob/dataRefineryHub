# DataFlow Pro Migration Guide

This guide helps you migrate existing components to the DataFlow Pro design system.

## Table of Contents

1. [Migration Strategy](#migration-strategy)
2. [Color Migration](#color-migration)
3. [Typography Migration](#typography-migration)
4. [Component Migration](#component-migration)
5. [Layout Migration](#layout-migration)
6. [Common Patterns](#common-patterns)
7. [Migration Checklist](#migration-checklist)

## Migration Strategy

### 1. Phased Approach

Migrate your application in phases to minimize disruption:

1. **Phase 1**: Set up design tokens and theme infrastructure
2. **Phase 2**: Migrate global styles (colors, typography, spacing)
3. **Phase 3**: Migrate shared components (buttons, forms, cards)
4. **Phase 4**: Migrate page layouts and specific features
5. **Phase 5**: Remove old styles and optimize

### 2. Parallel Styles

During migration, run old and new styles in parallel:

```css
/* Temporary during migration */
.legacy-button {
  /* Old styles */
}

.btn-primary {
  /* New design system styles */
}
```

## Color Migration

### 1. Color Mapping

Map old colors to new design tokens:

| Old Color | New Design Token | Usage |
|-----------|------------------|-------|
| `#007bff` | `var(--color-primary)` | Primary actions |
| `#6c757d` | `var(--color-text-secondary)` | Secondary text |
| `#f8f9fa` | `var(--color-background)` | Page background |
| `#ffffff` | `var(--color-surface)` | Card backgrounds |
| `#dc3545` | `var(--color-error)` | Error states |
| `#28a745` | `var(--color-success)` | Success states |

### 2. Find and Replace

Use these regex patterns to find old color values:

```bash
# Find hex colors
grep -r "#[0-9a-fA-F]{6}" app/assets/stylesheets/
grep -r "#[0-9a-fA-F]{3}" app/assets/stylesheets/

# Find rgb/rgba colors
grep -r "rgb\(.*\)" app/assets/stylesheets/
grep -r "rgba\(.*\)" app/assets/stylesheets/

# Find color names
grep -r "color:\s*\(blue\|gray\|red\|green\)" app/assets/stylesheets/
```

### 3. Migration Examples

#### Before:
```css
.alert-primary {
  background-color: #cfe2ff;
  border-color: #b6d4fe;
  color: #084298;
}
```

#### After:
```css
.alert-primary {
  background-color: rgba(var(--color-primary-rgb), 0.15);
  border-color: rgba(var(--color-primary-rgb), 0.3);
  color: var(--color-primary);
}
```

## Typography Migration

### 1. Font Stack Migration

#### Before:
```css
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  font-size: 16px;
  line-height: 1.5;
}
```

#### After:
```css
body {
  font-family: var(--font-family-base);
  font-size: var(--font-size-base);
  line-height: var(--line-height-normal);
}
```

### 2. Text Size Migration

| Old Class | New Class | Design Token |
|-----------|-----------|--------------|
| `.text-xs` | `.text-df-xs` | `var(--font-size-xs)` |
| `.text-sm` | `.text-df-sm` | `var(--font-size-sm)` |
| `.text-base` | `.text-df-base` | `var(--font-size-base)` |
| `.text-lg` | `.text-df-lg` | `var(--font-size-lg)` |
| `.text-xl` | `.text-df-xl` | `var(--font-size-xl)` |

## Component Migration

### 1. Button Migration

#### Before:
```erb
<button class="btn btn-primary">
  Click me
</button>

<style>
.btn {
  padding: 0.375rem 0.75rem;
  border-radius: 0.25rem;
  font-weight: 400;
}
.btn-primary {
  background-color: #0d6efd;
  color: white;
}
</style>
```

#### After:
```erb
<button class="inline-flex items-center px-4 py-2 bg-df-primary text-white 
               font-medium rounded-df-base hover:bg-df-primary-hover 
               transition-colors duration-df-normal">
  Click me
</button>
```

### 2. Card Migration

#### Before:
```erb
<div class="card">
  <div class="card-body">
    <h5 class="card-title">Card title</h5>
    <p class="card-text">Card content</p>
  </div>
</div>

<style>
.card {
  background: white;
  border: 1px solid rgba(0,0,0,.125);
  border-radius: 0.25rem;
}
.card-body {
  padding: 1.25rem;
}
</style>
```

#### After:
```erb
<div class="bg-df-surface border border-df-card-border rounded-df-lg p-6">
  <h3 class="text-lg font-semibold text-df-text mb-2">Card title</h3>
  <p class="text-df-text-secondary">Card content</p>
</div>
```

### 3. Form Migration

#### Before:
```erb
<div class="form-group">
  <label for="email">Email</label>
  <input type="email" class="form-control" id="email">
</div>

<style>
.form-control {
  padding: 0.375rem 0.75rem;
  border: 1px solid #ced4da;
  border-radius: 0.25rem;
}
</style>
```

#### After:
```erb
<div class="space-y-1">
  <label for="email" class="block text-sm font-medium text-df-text">
    Email
  </label>
  <input type="email" id="email"
         class="w-full px-3 py-2 bg-df-surface border border-df-border 
                rounded-df-base focus:outline-none focus:ring-2 
                focus:ring-df-primary focus:border-transparent">
</div>
```

## Layout Migration

### 1. Grid System

#### Before:
```erb
<div class="row">
  <div class="col-md-4">Column 1</div>
  <div class="col-md-4">Column 2</div>
  <div class="col-md-4">Column 3</div>
</div>
```

#### After:
```erb
<div class="grid grid-cols-1 md:grid-cols-3 gap-df-24">
  <div>Column 1</div>
  <div>Column 2</div>
  <div>Column 3</div>
</div>
```

### 2. Container Migration

#### Before:
```erb
<div class="container">
  <div class="content">
    <!-- Content -->
  </div>
</div>

<style>
.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 15px;
}
</style>
```

#### After:
```erb
<div class="max-w-7xl mx-auto px-df-16 sm:px-df-24">
  <!-- Content -->
</div>
```

## Common Patterns

### 1. Spacing Migration

```ruby
# Create a helper to map old spacing to new
def migrate_spacing(old_class)
  spacing_map = {
    "m-1" => "m-df-4",
    "m-2" => "m-df-8",
    "m-3" => "m-df-12",
    "m-4" => "m-df-16",
    "m-5" => "m-df-20",
    "p-1" => "p-df-4",
    "p-2" => "p-df-8",
    "p-3" => "p-df-12",
    "p-4" => "p-df-16",
    "p-5" => "p-df-20"
  }
  spacing_map[old_class] || old_class
end
```

### 2. Shadow Migration

| Old Shadow | New Shadow Class |
|------------|------------------|
| `box-shadow: 0 1px 3px rgba(0,0,0,0.12)` | `shadow-df-sm` |
| `box-shadow: 0 4px 6px rgba(0,0,0,0.1)` | `shadow-df-md` |
| `box-shadow: 0 10px 15px rgba(0,0,0,0.1)` | `shadow-df-lg` |

### 3. Border Radius Migration

| Old Radius | New Radius Class |
|------------|------------------|
| `border-radius: 0.25rem` | `rounded-df-sm` |
| `border-radius: 0.375rem` | `rounded-df-base` |
| `border-radius: 0.5rem` | `rounded-df-md` |
| `border-radius: 0.75rem` | `rounded-df-lg` |

## Migration Checklist

### Pre-Migration
- [ ] Audit existing styles and components
- [ ] Create migration plan and timeline
- [ ] Set up design system infrastructure
- [ ] Configure Tailwind with design tokens
- [ ] Create migration helper utilities

### During Migration
- [ ] Migrate global styles (reset, typography, colors)
- [ ] Update shared components one by one
- [ ] Test each component in both themes
- [ ] Update component documentation
- [ ] Migrate page layouts
- [ ] Update JavaScript that references old classes

### Post-Migration
- [ ] Remove old stylesheets
- [ ] Clean up unused CSS with PurgeCSS
- [ ] Update style guide documentation
- [ ] Train team on new design system
- [ ] Set up visual regression tests
- [ ] Monitor bundle size

### Component Migration Status

Track your migration progress:

```markdown
## Migration Status

### Global Styles
- [x] Colors and themes
- [x] Typography
- [x] Spacing and layout
- [ ] Animations and transitions

### Components
- [x] Buttons
- [x] Forms
- [ ] Navigation
- [ ] Cards
- [ ] Modals
- [ ] Tables
- [ ] Alerts

### Pages
- [ ] Dashboard
- [ ] Data Sources
- [ ] Settings
- [ ] Reports
```

## Troubleshooting

### Common Issues

1. **Specificity conflicts**: New styles not applying
   ```css
   /* Add !important temporarily during migration */
   .bg-df-primary {
     background-color: var(--color-primary) !important;
   }
   ```

2. **Missing variables**: Design tokens not defined
   ```javascript
   // Check if CSS is loaded
   console.log(getComputedStyle(document.documentElement)
     .getPropertyValue('--color-primary'))
   ```

3. **Theme switching issues**: 
   ```javascript
   // Force theme refresh
   document.documentElement.classList.add('theme-transition')
   setTimeout(() => {
     document.documentElement.classList.remove('theme-transition')
   }, 1000)
   ```

## Resources

- [Design System Documentation](./DESIGN_SYSTEM.md)
- [Component Guide](./components.md)
- [Implementation Guide](./implementation-guide.md)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [ViewComponent Documentation](https://viewcomponent.org/)