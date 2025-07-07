const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}',
    './app/components/**/*.{erb,haml,html,slim,rb}'
  ],
  theme: {
    extend: {
      colors: {
        // DataFlow Pro color palette
        'df-background': 'rgba(252, 252, 249, 1)',
        'df-surface': 'rgba(255, 255, 253, 1)',
        'df-text': 'rgba(19, 52, 59, 1)',
        'df-text-secondary': 'rgba(98, 108, 113, 1)',
        'df-primary': 'rgba(33, 128, 141, 1)',
        'df-primary-hover': 'rgba(29, 116, 128, 1)',
        'df-primary-active': 'rgba(26, 104, 115, 1)',
        'df-secondary': 'rgba(94, 82, 64, 0.12)',
        'df-secondary-hover': 'rgba(94, 82, 64, 0.2)',
        'df-secondary-active': 'rgba(94, 82, 64, 0.25)',
        'df-border': 'rgba(94, 82, 64, 0.2)',
        'df-card-border': 'rgba(94, 82, 64, 0.12)',
        'df-error': 'rgba(192, 21, 47, 1)',
        'df-success': 'rgba(33, 128, 141, 1)',
        'df-warning': 'rgba(168, 75, 47, 1)',
        'df-info': 'rgba(98, 108, 113, 1)',
        'df-focus-ring': 'rgba(33, 128, 141, 0.4)',
      },
      fontFamily: {
        'sans': ['FKGroteskNeue', 'Geist', 'Inter', ...defaultTheme.fontFamily.sans],
        'mono': ['Berkeley Mono', 'ui-monospace', ...defaultTheme.fontFamily.mono],
      },
      fontSize: {
        'df-xs': '11px',
        'df-sm': '12px',
        'df-base': '14px',
        'df-md': '14px',
        'df-lg': '16px',
        'df-xl': '18px',
        'df-2xl': '20px',
        'df-3xl': '24px',
        'df-4xl': '30px',
      },
      spacing: {
        'df-1': '1px',
        'df-2': '2px',
        'df-4': '4px',
        'df-6': '6px',
        'df-8': '8px',
        'df-10': '10px',
        'df-12': '12px',
        'df-16': '16px',
        'df-20': '20px',
        'df-24': '24px',
        'df-32': '32px',
      },
      borderRadius: {
        'df-sm': '6px',
        'df-base': '8px',
        'df-md': '10px',
        'df-lg': '12px',
      },
      boxShadow: {
        'df-xs': '0 1px 2px rgba(0, 0, 0, 0.02)',
        'df-sm': '0 1px 3px rgba(0, 0, 0, 0.04), 0 1px 2px rgba(0, 0, 0, 0.02)',
        'df-md': '0 4px 6px -1px rgba(0, 0, 0, 0.04), 0 2px 4px -1px rgba(0, 0, 0, 0.02)',
        'df-lg': '0 10px 15px -3px rgba(0, 0, 0, 0.04), 0 4px 6px -2px rgba(0, 0, 0, 0.02)',
        'df-inset': 'inset 0 1px 0 rgba(255, 255, 255, 0.15), inset 0 -1px 0 rgba(0, 0, 0, 0.03)',
      },
      animation: {
        'df-fade-in': 'fadeIn 250ms cubic-bezier(0.16, 1, 0.3, 1)',
        'df-slide-in': 'slideIn 250ms cubic-bezier(0.16, 1, 0.3, 1)',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideIn: {
          '0%': { transform: 'translateX(-100%)' },
          '100%': { transform: 'translateX(0)' },
        }
      },
      transitionTimingFunction: {
        'df-standard': 'cubic-bezier(0.16, 1, 0.3, 1)',
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
  ],
  darkMode: 'class',
}