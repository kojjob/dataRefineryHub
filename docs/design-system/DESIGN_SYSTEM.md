# DataFlow Pro Design System

## 🎨 Design Philosophy

DataFlow Pro embodies a modern, professional aesthetic with:
- Clean, minimalist design with subtle depth through shadows and borders
- Dual theme support (light/dark) with seamless transitions
- Premium gradient effects for visual hierarchy
- Consistent spacing and typography for optimal readability
- Smooth animations that enhance user experience

## 🎯 Design Tokens

### Color Palette

#### Light Theme

```css
/* Primary Colors */
--color-primary: #21808D (33, 128, 141)
--color-primary-hover: #1D7480 (29, 116, 128)
--color-primary-active: #1A6873 (26, 104, 115)

/* Background & Surface */
--color-background: #FCFCF9 (252, 252, 249)
--color-surface: #FFFFFD (255, 255, 253)

/* Text Colors */
--color-text: #13343B (19, 52, 59)
--color-text-secondary: #626C71 (98, 108, 113)

/* Secondary Colors */
--color-secondary: rgba(94, 82, 64, 0.12)
--color-secondary-hover: rgba(94, 82, 64, 0.2)
--color-secondary-active: rgba(94, 82, 64, 0.25)

/* Semantic Colors */
--color-error: #C0152F (192, 21, 47)
--color-success: #21808D (33, 128, 141)
--color-warning: #A84B2F (168, 75, 47)
--color-info: #626C71 (98, 108, 113)

/* Borders */
--color-border: rgba(94, 82, 64, 0.2)
--color-card-border: rgba(94, 82, 64, 0.12)
```

#### Dark Theme

```css
/* Primary Colors */
--color-primary: #32B8C6 (50, 184, 198)
--color-primary-hover: #2DA6B2 (45, 166, 178)
--color-primary-active: #2996A1 (41, 150, 161)

/* Background & Surface */
--color-background: #1F2121 (31, 33, 33)
--color-surface: #262828 (38, 40, 40)

/* Text Colors */
--color-text: #F5F5F5 (245, 245, 245)
--color-text-secondary: rgba(167, 169, 169, 0.7)

/* Secondary Colors */
--color-secondary: rgba(119, 124, 124, 0.15)
--color-secondary-hover: rgba(119, 124, 124, 0.25)
--color-secondary-active: rgba(119, 124, 124, 0.3)

/* Semantic Colors */
--color-error: #FF5459 (255, 84, 89)
--color-success: #32B8C6 (50, 184, 198)
--color-warning: #E68161 (230, 129, 97)
--color-info: #A7A9A9 (167, 169, 169)

/* Borders */
--color-border: rgba(119, 124, 124, 0.3)
--color-card-border: rgba(119, 124, 124, 0.2)
```

### Typography

```css
/* Font Families */
--font-family-base: "FKGroteskNeue", "Geist", "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif
--font-family-mono: "Berkeley Mono", ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace

/* Font Sizes */
--font-size-xs: 11px
--font-size-sm: 12px
--font-size-base: 14px
--font-size-md: 14px
--font-size-lg: 16px
--font-size-xl: 18px
--font-size-2xl: 20px
--font-size-3xl: 24px
--font-size-4xl: 30px

/* Font Weights */
--font-weight-normal: 400
--font-weight-medium: 500
--font-weight-semibold: 550
--font-weight-bold: 600

/* Line Heights */
--line-height-tight: 1.2
--line-height-normal: 1.5

/* Letter Spacing */
--letter-spacing-tight: -0.01em
```

### Spacing System

```css
--space-0: 0
--space-1: 1px
--space-2: 2px
--space-4: 4px
--space-6: 6px
--space-8: 8px
--space-10: 10px
--space-12: 12px
--space-16: 16px
--space-20: 20px
--space-24: 24px
--space-32: 32px
```

### Border Radius

```css
--radius-sm: 6px
--radius-base: 8px
--radius-md: 10px
--radius-lg: 12px
--radius-full: 9999px
```

### Shadows

```css
--shadow-xs: 0 1px 2px rgba(0, 0, 0, 0.02)
--shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.04), 0 1px 2px rgba(0, 0, 0, 0.02)
--shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.04), 0 2px 4px -1px rgba(0, 0, 0, 0.02)
--shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.04), 0 4px 6px -2px rgba(0, 0, 0, 0.02)
```

### Animation

```css
--duration-fast: 150ms
--duration-normal: 250ms
--ease-standard: cubic-bezier(0.16, 1, 0.3, 1)
```

## 🧩 Components

### 1. Buttons

#### Primary Button

```css
.btn--primary {
  background: var(--color-primary);
  color: var(--color-btn-primary-text);
  padding: var(--space-8) var(--space-16);
  border-radius: var(--radius-base);
  font-weight: 500;
  transition: all var(--duration-normal) var(--ease-standard);
}
```

#### Secondary Button

```css
.btn--secondary {
  background: var(--color-secondary);
  color: var(--color-text);
}
```

#### Outline Button

```css
.btn--outline {
  background: transparent;
  border: 1px solid var(--color-border);
  color: var(--color-text);
}
```

#### Button Sizes

- Small: `padding: var(--space-4) var(--space-12)`
- Default: `padding: var(--space-8) var(--space-16)`
- Large: `padding: var(--space-10) var(--space-20)`

### 2. Cards

#### Metric Card

- Background: `var(--color-surface)`
- Border: `1px solid var(--color-card-border)`
- Border radius: `var(--radius-lg)`
- Padding: `var(--space-24)`
- Hover effect: Lift with shadow and transform

#### Insight Card

- Categories: Critical (red), High (warning), Medium (primary)
- Top border indicator for priority
- Confidence score badge

### 3. Form Controls

#### Input Fields

```css
.form-control {
  padding: var(--space-8) var(--space-12);
  background-color: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-base);
  font-size: var(--font-size-md);
}
```

#### Select Dropdowns

- Custom caret icon that adapts to theme
- Native styling removed for consistency

### 4. Navigation

#### Sidebar

- Width: 280px
- Fixed position with scroll
- Active state: Left border accent + background

#### Navigation Items

- Icon + Text layout
- Hover state: Background color change
- Active state: Primary color left border

### 5. Status Indicators

#### Status Badges

```css
.status--success { background: rgba(success-rgb, 0.15); color: success; }
.status--error { background: rgba(error-rgb, 0.15); color: error; }
.status--warning { background: rgba(warning-rgb, 0.15); color: warning; }
.status--info { background: rgba(info-rgb, 0.15); color: info; }
```

### 6. Charts & Visualizations

#### Chart Containers

- White background with border
- Header with title and controls
- Fixed height: 300px

#### Trend Lines

- Gradient backgrounds indicating direction
- Up: Success gradient
- Down: Error gradient
- Stable: Primary gradient

## 🎭 Special Effects

### 1. Gradient Text (Icons)

```css
.metric-icon {
  background: linear-gradient(135deg, var(--color-primary), var(--color-primary-hover));
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
```

### 2. Hover Animations

- Cards: `transform: translateY(-2px)` with shadow
- Buttons: Color transitions
- Navigation: Background fade

### 3. Focus States

```css
--focus-ring: 0 0 0 3px var(--color-focus-ring)
--focus-outline: 2px solid var(--color-primary)
```

## 📐 Layout Patterns

### 1. Grid Systems

#### Metrics Grid

```css
grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
gap: var(--space-24);
```

#### Insights Grid

```css
grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
gap: var(--space-20);
```

### 2. Page Structure

- Fixed sidebar (280px)
- Sticky header
- Scrollable content area
- Responsive breakpoints at 640px, 768px, 1024px, 1280px

## 🌗 Theme Implementation

### Theme Toggle

- Smooth transitions with theme-transition class
- LocalStorage persistence
- System preference detection
- Manual override with data-color-scheme attribute

### Implementation Pattern

```javascript
// Check for saved theme or system preference
const savedTheme = localStorage.getItem('theme');
const systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
const theme = savedTheme || systemTheme;

// Apply theme
document.documentElement.setAttribute('data-color-scheme', theme);
```

## 🎯 Design Principles

1. **Consistency**: Use design tokens for all values
2. **Accessibility**: Focus states, color contrast, keyboard navigation
3. **Performance**: CSS variables for instant theme switching
4. **Scalability**: Component-based architecture
5. **Responsiveness**: Mobile-first with progressive enhancement

## 📱 Responsive Design

### Breakpoints

- Mobile: < 640px
- Tablet: 640px - 1024px
- Desktop: > 1024px

### Mobile Adaptations

- Collapsible sidebar
- Stacked layouts
- Touch-optimized tap targets (min 44px)
- Simplified navigation

## 🚀 Implementation Guidelines

1. **Always use CSS variables** - Never hardcode colors or spacing
2. **Follow naming conventions** - BEM-style with modifiers
3. **Maintain hierarchy** - Use semantic HTML and ARIA labels
4. **Test both themes** - Ensure all components work in light/dark
5. **Optimize performance** - Use CSS transforms for animations

---

This design system provides a complete foundation for implementing the DataFlow Pro UI with consistency and scalability.