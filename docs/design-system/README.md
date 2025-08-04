# DataFlow Pro Design System

Welcome to the DataFlow Pro Design System documentation. This comprehensive guide provides everything you need to implement and maintain consistent, beautiful interfaces across the Data Refinery Platform.

## 📚 Documentation Structure

### Core Documentation

1. **[Design System Overview](./DESIGN_SYSTEM.md)**
   - Complete design philosophy and principles
   - All design tokens (colors, typography, spacing, etc.)
   - Component specifications
   - Theme implementation details

2. **[Component Guide](./components.md)**
   - Detailed implementation examples for all components
   - Code snippets for buttons, cards, forms, navigation, etc.
   - Best practices for component usage
   - ViewComponent patterns

3. **[Implementation Guide](./implementation-guide.md)**
   - Setup instructions for the design system
   - Tailwind CSS configuration
   - Theme management with Stimulus
   - Performance optimization tips
   - Testing strategies

4. **[Migration Guide](./migration-guide.md)**
   - Step-by-step migration from legacy styles
   - Color and typography mapping
   - Component migration examples
   - Migration checklist and troubleshooting

### Reference Files

- **[Design Tokens JSON](./tokens.json)**
  - Machine-readable design tokens
  - Useful for tooling and automation
  - Complete color palettes for both themes
  - Typography, spacing, and animation values

## 🎨 Quick Start

### Using Design Tokens

```css
/* Always use CSS variables */
.custom-component {
  background: var(--color-surface);
  color: var(--color-text);
  padding: var(--space-16);
  border-radius: var(--radius-lg);
}
```

### Using Tailwind Classes

```erb
<!-- Use the df- prefixed classes -->
<div class="bg-df-surface text-df-text p-df-16 rounded-df-lg">
  Content
</div>
```

### Theme Support

Both light and dark themes are supported automatically:

```html
<!-- Light theme -->
<html data-color-scheme="light">

<!-- Dark theme -->
<html data-color-scheme="dark">
```

## 🔧 Key Features

- **Dual Theme Support**: Seamless light/dark mode switching
- **Design Tokens**: Consistent values across the entire platform
- **Component Library**: Pre-built, accessible components
- **Tailwind Integration**: Extended with design system values
- **ViewComponent Support**: Reusable Ruby components
- **Performance Optimized**: Fast theme switching and minimal CSS

## 📋 Design Principles

1. **Consistency**: Use design tokens for all values
2. **Accessibility**: WCAG 2.1 AA compliant with proper contrast and keyboard navigation
3. **Performance**: Optimized for fast loading and smooth interactions
4. **Scalability**: Component-based architecture for easy maintenance
5. **Responsiveness**: Mobile-first design approach

## 🚀 Getting Started

1. Review the [Design System Overview](./DESIGN_SYSTEM.md) to understand the philosophy
2. Check the [Implementation Guide](./implementation-guide.md) for setup instructions
3. Browse the [Component Guide](./components.md) for implementation examples
4. Use the [Migration Guide](./migration-guide.md) if updating existing code

## 💡 Tips

- Always use design tokens instead of hardcoded values
- Test components in both light and dark themes
- Follow the component patterns for consistency
- Keep accessibility in mind when building new components
- Use the ViewComponent pattern for reusable UI elements

## 🤝 Contributing

When adding new components or updating the design system:

1. Update the relevant documentation files
2. Add examples to the component guide
3. Update the design tokens if adding new values
4. Test in both themes
5. Ensure accessibility standards are met

---

For questions or suggestions about the design system, please create an issue in the repository or contact the design team.