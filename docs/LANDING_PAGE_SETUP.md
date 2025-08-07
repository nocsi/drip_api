# Kyozo Landing Page Setup Guide

This guide explains how to use the complete Shadcn Svelte 5 landing page created for Kyozo, your literate programming executable markdown notes app.

## Overview

The landing page is a modern, responsive, and interactive showcase built with:
- **Svelte 5** - Latest version with runes and enhanced reactivity
- **shadcn-svelte** - High-quality, accessible UI components
- **Tailwind CSS 4** - Latest version with modern features
- **Lucide Svelte** - Beautiful, consistent icons
- **Phoenix LiveView Integration** - Seamless backend integration

## File Structure

```
kyozo_api/assets/svelte/
├── landing-page.svelte          # Main landing page component
├── home.svelte                  # Updated home component
├── landing/
│   ├── header.svelte           # Navigation header with mobile menu
│   ├── hero.svelte             # Hero section with CTA
│   ├── features.svelte         # Features showcase
│   ├── demo.svelte             # Interactive demo section
│   ├── how-it-works.svelte     # Process explanation
│   ├── pricing.svelte          # Pricing plans
│   ├── footer.svelte           # Footer with links
│   ├── README.md               # Component documentation
│   └── integration-example.md  # Phoenix integration guide
└── ui/                         # shadcn-svelte components (already present)
```

## Key Features

### 🎨 Modern Design
- Beautiful gradient backgrounds and glass morphism effects
- Responsive design that works on all devices
- Dark/light mode support through shadcn-svelte theming
- Smooth animations and hover effects

### 🚀 Interactive Elements
- Live code execution demo
- Mobile-responsive navigation with hamburger menu
- Interactive pricing cards with "most popular" highlighting
- Newsletter signup and social media links

### 📱 Mobile-First
- Responsive grid layouts
- Mobile hamburger menu
- Touch-friendly buttons and interactions
- Optimized typography scaling

### ⚡ Performance
- Lazy loading of heavy components
- Optimized bundle size with tree-shaking
- Efficient Svelte 5 reactivity
- Custom scrollbar styling

## Components Breakdown

### 1. Header (`header.svelte`)
- Sticky navigation with backdrop blur
- Logo and brand name
- Desktop navigation menu
- Mobile slide-out menu using Sheet component
- GitHub star button and CTAs

### 2. Hero (`hero.svelte`)
- Compelling headline with gradient text effect
- Feature highlights with icons
- Call-to-action buttons
- Interactive demo preview
- Grid background pattern

### 3. Features (`features.svelte`)
- 9 main features in a responsive grid
- Advanced capabilities section
- Icon-based feature cards
- Hover effects and shadows

### 4. Demo (`demo.svelte`)
- Interactive executable markdown demo
- Tabbed interface (Source, Preview, Split View)
- Simulated code execution with loading states
- Syntax-highlighted code blocks
- Output visualization

### 5. How It Works (`how-it-works.svelte`)
- 4-step process visualization
- Interactive demo section
- Benefits highlighting
- Final call-to-action

### 6. Pricing (`pricing.svelte`)
- 3-tier pricing structure (Personal, Pro, Team)
- "Most Popular" badge highlighting
- Feature comparison lists
- Enterprise section
- Money-back guarantee

### 7. Footer (`footer.svelte`)
- Comprehensive link organization
- Social media links
- Newsletter signup
- Company information and copyright

## Usage

### Basic Usage
```svelte
<script>
  import LandingPage from './landing-page.svelte';
</script>

<LandingPage />
```

### Using Individual Components
```svelte
<script>
  import Header from './landing/header.svelte';
  import Hero from './landing/hero.svelte';
  import Features from './landing/features.svelte';
  import Demo from './landing/demo.svelte';
  import HowItWorks from './landing/how-it-works.svelte';
  import Pricing from './landing/pricing.svelte';
  import Footer from './landing/footer.svelte';
</script>

<div class="min-h-screen bg-background">
  <Header />
  <main>
    <Hero />
    <Features />
    <Demo />
    <HowItWorks />
    <Pricing />
  </main>
  <Footer />
</div>
```

## Phoenix LiveView Integration

### Option 1: LiveView Hook (Recommended)

1. Create a LiveView:
```elixir
defmodule KyozoWeb.LandingLive do
  use KyozoWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="landing-page" phx-hook="LandingPage"></div>
    """
  end
end
```

2. Create the hook:
```javascript
// assets/js/hooks/landing_page.js
export default {
  mounted() {
    import("../svelte/landing-page.svelte").then((module) => {
      new module.default({
        target: this.el
      });
    });
  }
};
```

3. Add route:
```elixir
live "/", LandingLive, :index
```

### Option 2: Static Controller

For better SEO and faster initial load:

```elixir
defmodule KyozoWeb.PageController do
  use KyozoWeb, :controller

  def landing(conn, _params) do
    render(conn, :landing, layout: false)
  end
end
```

Then create a template with proper meta tags and mount the Svelte component directly.

## Customization

### 1. Content Updates
- Update company name and branding in `header.svelte` and `footer.svelte`
- Modify pricing plans in `pricing.svelte`
- Update feature descriptions in `features.svelte`
- Customize demo content in `demo.svelte`

### 2. Styling
- Colors are controlled via CSS custom properties in `app.css`
- Tailwind classes can be modified throughout components
- Custom animations are defined in the CSS file

### 3. Links and Navigation
- Update navigation items in `header.svelte`
- Modify footer links in `footer.svelte`
- Add or remove sections as needed

## Features Highlighted

The landing page showcases these key capabilities:

1. **Multi-language Support** - Python, JavaScript, R, SQL execution
2. **Live Execution** - Real-time code running and output
3. **Rich Formatting** - Beautiful markdown rendering
4. **Version Control Ready** - Git-friendly plain text files
5. **Interactive Widgets** - Controls and dynamic content
6. **Fast Performance** - Optimized execution engine
7. **Data Integration** - Database and API connections
8. **Easy Sharing** - Export and collaboration features
9. **Live Preview** - Side-by-side editing and preview

## Development

### Running Locally
```bash
cd kyozo_api/assets
npm install
npm run dev
```

### Building for Production
```bash
npm run build
```

### Updating Components
The landing page uses these shadcn-svelte components:
- Button, Card, Badge, Sheet, Separator, Tabs
- All components are already installed and configured

## SEO Optimization

The landing page includes:
- Semantic HTML structure
- Proper heading hierarchy
- Meta descriptions and Open Graph tags
- Structured data for search engines
- Fast loading times
- Mobile-responsive design

## Performance Features

- Code splitting for optimal bundle size
- Lazy loading of heavy components
- Optimized images and assets
- Efficient Svelte 5 reactivity
- Custom scrollbar styling
- Smooth animations without jank

## Browser Support

- Chrome/Edge 90+
- Firefox 88+
- Safari 14+
- Modern mobile browsers

## Next Steps

1. **Content Review** - Update all placeholder content with your actual copy
2. **Branding** - Replace logos and adjust colors to match your brand
3. **Analytics** - Add tracking for user interactions
4. **A/B Testing** - Set up experiments for different variations
5. **Performance** - Monitor and optimize loading times
6. **SEO** - Add structured data and optimize meta tags

This landing page provides a solid foundation for showcasing Kyozo's literate programming capabilities while maintaining excellent performance and user experience.
