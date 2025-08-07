# Landing Page Components

This directory contains the Svelte 5 components for the Kyozo landing page, built with shadcn-svelte and Tailwind CSS.

## Overview

The landing page is designed for Kyozo, a literate programming executable markdown notes app. It showcases the key features and benefits of combining beautiful prose with live code execution.

## Components

### `landing-page.svelte`

The main landing page component that combines all sections into a complete page layout.

### `header.svelte`

Navigation header with:

- Logo and branding
- Desktop navigation menu
- Mobile responsive hamburger menu
- CTA buttons (Sign in, Get started)
- GitHub star button

### `hero.svelte`

Hero section featuring:

- Compelling headline with gradient text
- Feature highlights with icons
- Call-to-action buttons
- Interactive demo preview
- Grid background pattern

### `features.svelte`

Comprehensive features section with:

- Multi-language support
- Live code execution
- Rich formatting capabilities
- Version control integration
- Interactive widgets
- Data integration
- Advanced capabilities showcase

### `how-it-works.svelte`

Step-by-step process explanation:

- 4-step workflow visualization
- Interactive demo with input/output
- Benefits highlighting
- Final CTA

### `pricing.svelte`

Pricing plans section:

- Three-tier pricing (Personal, Pro, Team)
- Enterprise option
- Feature comparison
- Money-back guarantee
- FAQ preview

### `footer.svelte`

Comprehensive footer with:

- Brand information and social links
- Organized link sections (Product, Company, Resources, Legal)
- Newsletter signup
- Copyright and attribution

## Usage

```svelte
<!-- Use the complete landing page -->
<script>
  import LandingPage from './landing-page.svelte';
</script>

<LandingPage />
```

Or use individual components:

```svelte
<script>
  import Header from './landing/header.svelte';
  import Hero from './landing/hero.svelte';
  import Features from './landing/features.svelte';
  // ... other components
</script>

<Header />
<Hero />
<Features />
<!-- ... other sections -->
```

## Dependencies

The components use the following shadcn-svelte components:

- `Button`
- `Card` (with `CardContent`, `CardDescription`, `CardHeader`, `CardTitle`)
- `Badge`
- `Sheet` (with `SheetContent`, `SheetTrigger`)
- `Separator`

Icons are provided by `@lucide/svelte`.

## Styling

The components use Tailwind CSS classes and follow the shadcn-svelte design system. Key design features:

- **Color Scheme**: Uses CSS custom properties for theming
- **Typography**: Responsive text sizing with proper hierarchy
- **Spacing**: Consistent padding and margins
- **Animations**: Subtle hover effects and transitions
- **Responsive**: Mobile-first responsive design
- **Accessibility**: Proper ARIA labels and semantic HTML

## Customization

### Colors

The components use the shadcn-svelte color palette. Customize colors by modifying your Tailwind CSS configuration and CSS custom properties.

### Content

Update text content, links, and features by modifying the component scripts and templates.

### Branding

Replace the logo, company name, and branding elements in the header and footer components.

### Pricing

Modify the pricing plans in `pricing.svelte` by updating the `plans` array.

## Features Highlighted

The landing page emphasizes these key capabilities of the literate programming app:

1. **Multi-language Code Execution**: Python, JavaScript, R, SQL, and more
2. **Live Documentation**: Real-time preview and execution
3. **Version Control Friendly**: Standard markdown files
4. **Interactive Elements**: Widgets and controls
5. **Beautiful Formatting**: Rich markdown rendering
6. **Data Integration**: Database and API connections
7. **Export Options**: HTML, PDF, and sharing capabilities
8. **Collaboration**: Team features and real-time editing

## Browser Support

The components are built with modern web standards and support:

- Chrome/Edge 90+
- Firefox 88+
- Safari 14+

## Performance

- Optimized bundle size with tree-shaking
- Lazy loading of heavy components
- Efficient Svelte 5 reactivity
- Minimal runtime overhead
