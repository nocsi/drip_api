# Kyozo Store Frontend Architecture

## Overview

Kyozo Store's frontend is built with **Svelte 5** and **TypeScript**, providing a modern, reactive user interface with real-time collaboration features. The architecture emphasizes performance, accessibility, and progressive enhancement while maintaining tight integration with the Phoenix LiveView backend.

## Technology Stack

### Core Framework
- **Svelte 5** with runes-based reactivity system
- **TypeScript** for type safety and developer experience
- **Vite** for fast development builds and HMR
- **Phoenix LiveView** for server-driven state and real-time updates

### UI Framework
- **shadcn/ui** components adapted for Svelte
- **Tailwind CSS** for utility-first styling
- **Radix UI** primitives for accessibility
- **Lucide Icons** for consistent iconography

### Build and Development
- **Vite 5+** for build tooling and asset processing
- **TypeScript 5+** for static type checking
- **ESLint + Prettier** for code quality
- **Svelte Language Server** for IDE support

## Architecture Principles

### 1. Component-Driven Development
- **Atomic Design**: Components organized from atoms to organisms
- **Single Responsibility**: Each component has a focused purpose
- **Composition over Inheritance**: Favor component composition patterns
- **Accessibility First**: WCAG compliance built into all components

### 2. Reactive State Management
- **Svelte Stores**: Global state management with reactive subscriptions
- **Runes-Based Reactivity**: Svelte 5's modern reactivity system
- **Server State Sync**: LiveView integration for server-driven updates
- **Optimistic Updates**: Client-side predictions with server reconciliation

### 3. Progressive Enhancement
- **Server-Side Rendering**: Initial page loads via Phoenix templates
- **Hydration Strategy**: Progressive JavaScript enhancement
- **Offline Resilience**: Graceful degradation when connectivity is lost
- **Mobile-First Design**: Responsive layouts with touch-friendly interactions

### 4. Performance Optimization
- **Code Splitting**: Dynamic imports for route-based chunks
- **Bundle Analysis**: Regular bundle size monitoring
- **Asset Optimization**: Image compression and WebP conversion
- **Lazy Loading**: Deferred loading for non-critical resources

## Project Structure

```
assets/
├── svelte/                    # Svelte application root
│   ├── App.svelte            # Main application component
│   ├── components/           # Feature-specific components
│   │   ├── dashboard/        # Dashboard components
│   │   ├── workspaces/       # Workspace management
│   │   ├── documents/        # Document browser
│   │   ├── notebooks/        # Notebook editor
│   │   ├── teams/           # Team management
│   │   ├── projects/        # Project explorer
│   │   └── settings/        # Application settings
│   ├── layout/              # Layout components
│   │   ├── AppLayout.svelte  # Main application shell
│   │   ├── Sidebar.svelte    # Navigation sidebar
│   │   ├── TopBar.svelte     # Top navigation bar
│   │   └── MobileNav.svelte  # Mobile navigation
│   ├── ui/                  # Base UI component library
│   │   ├── button/          # Button components
│   │   ├── card/            # Card components  
│   │   ├── input/           # Form inputs
│   │   ├── modal/           # Modal dialogs
│   │   └── ...              # Other UI primitives
│   ├── stores/              # State management
│   │   ├── index.ts         # Store exports
│   │   ├── auth.ts          # Authentication state
│   │   ├── teams.ts         # Team management
│   │   ├── workspaces.ts    # Workspace state
│   │   └── ui.ts            # UI state (loading, errors)
│   ├── services/            # API integration
│   │   ├── api.ts           # API client
│   │   └── websocket.ts     # WebSocket integration
│   ├── types/               # TypeScript definitions
│   │   ├── index.ts         # Type exports
│   │   ├── api.ts           # API response types
│   │   └── stores.ts        # Store type definitions
│   ├── utils.ts             # Utility functions
│   └── hooks/               # Custom hooks
├── js/                      # JavaScript utilities
│   ├── app.ts              # Application bootstrap
│   └── hooks/              # Phoenix LiveView hooks
├── css/                     # Global styles
│   ├── app.css             # Main stylesheet
│   └── theme.css           # Theme variables
└── static/                  # Static assets
```

## Component Architecture

### Layout System

#### AppLayout.svelte
```svelte
<script lang="ts">
  import Sidebar from './Sidebar.svelte';
  import TopBar from './TopBar.svelte';
  import MobileNav from './MobileNav.svelte';
  import { isMobile } from '../stores/ui';
  
  let { title, subtitle, children } = $props();
</script>

<div class="flex h-screen bg-background">
  {#if $isMobile}
    <MobileNav />
  {:else}
    <Sidebar />
  {/if}
  
  <div class="flex-1 flex flex-col overflow-hidden">
    <TopBar {title} {subtitle} />
    <main class="flex-1 overflow-auto p-6">
      {@render children()}
    </main>
  </div>
</div>
```

#### Responsive Design Strategy
- **Desktop First**: Primary layout for desktop screens (1024px+)
- **Mobile Adaptation**: Collapsible sidebar, touch-friendly controls
- **Tablet Support**: Responsive grid layouts, optimized touch targets
- **Breakpoint System**: Tailwind's responsive utilities

### State Management Architecture

#### Store Pattern
```typescript
// stores/workspaces.ts
import { writable, derived } from 'svelte/store';
import type { Workspace, ApiService } from '../types';

interface WorkspacesState {
  items: Workspace[];
  current: Workspace | null;
  loading: boolean;
  error: string | null;
}

const initialState: WorkspacesState = {
  items: [],
  current: null,
  loading: false,
  error: null
};

export const workspaces = writable(initialState);

// Derived stores for computed values
export const currentWorkspace = derived(
  workspaces,
  ($workspaces) => $workspaces.current
);

export const activeWorkspaces = derived(
  workspaces,
  ($workspaces) => $workspaces.items.filter(w => w.status === 'active')
);

// Actions
export const workspaceActions = {
  async load(api: ApiService) {
    workspaces.update(state => ({ ...state, loading: true, error: null }));
    
    try {
      const items = await api.workspaces.list();
      workspaces.update(state => ({ 
        ...state, 
        items, 
        loading: false 
      }));
    } catch (error) {
      workspaces.update(state => ({ 
        ...state, 
        loading: false,
        error: error instanceof Error ? error.message : 'Failed to load workspaces'
      }));
    }
  },

  setCurrent(workspace: Workspace | null) {
    workspaces.update(state => ({ ...state, current: workspace }));
  }
};
```

#### Store Integration Pattern
```svelte
<!-- Component using stores -->
<script lang="ts">
  import { workspaces, workspaceActions } from '../stores/workspaces';
  import { apiService } from '../stores';
  import { onMount } from 'svelte';
  
  onMount(() => {
    workspaceActions.load($apiService);
  });
  
  // Reactive declarations
  $: isLoading = $workspaces.loading;
  $: workspaceList = $workspaces.items;
</script>

{#if isLoading}
  <div>Loading workspaces...</div>
{:else}
  {#each workspaceList as workspace}
    <WorkspaceCard {workspace} />
  {/each}
{/if}
```

### UI Component Library

#### Design System Foundation
The UI component library is based on **shadcn/ui** adapted for Svelte, providing:

- **Consistent Visual Language**: Unified colors, typography, spacing
- **Accessibility Standards**: WCAG AA compliance built-in
- **Theme Support**: Light/dark mode with CSS custom properties
- **Component Variants**: Size, color, and style variations

#### Core UI Components

##### Button Component
```svelte
<!-- ui/button/button.svelte -->
<script lang="ts">
  import { cn } from '../../utils';
  import type { ButtonVariant, ButtonSize } from './types';
  
  let {
    variant = 'default',
    size = 'default',
    disabled = false,
    loading = false,
    onclick,
    children,
    ...props
  }: {
    variant?: ButtonVariant;
    size?: ButtonSize;
    disabled?: boolean;
    loading?: boolean;
    onclick?: () => void;
    children: any;
  } = $props();
  
  const variants = {
    default: 'bg-primary text-primary-foreground hover:bg-primary/90',
    destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
    outline: 'border border-input bg-background hover:bg-accent hover:text-accent-foreground',
    secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/80',
    ghost: 'hover:bg-accent hover:text-accent-foreground',
    link: 'text-primary underline-offset-4 hover:underline'
  };
  
  const sizes = {
    default: 'h-10 px-4 py-2',
    sm: 'h-9 rounded-md px-3',
    lg: 'h-11 rounded-md px-8',
    icon: 'h-10 w-10'
  };
</script>

<button
  class={cn(
    'inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
    variants[variant],
    sizes[size]
  )}
  {disabled}
  {onclick}
  {...props}
>
  {#if loading}
    <Loader2 class="mr-2 h-4 w-4 animate-spin" />
  {/if}
  {@render children()}
</button>
```

##### Card Component
```svelte
<!-- ui/card/card.svelte -->
<script lang="ts">
  import { cn } from '../../utils';
  
  let { 
    class: className = '',
    children,
    ...props 
  } = $props();
</script>

<div
  class={cn('rounded-lg border bg-card text-card-foreground shadow-sm', className)}
  {...props}
>
  {@render children()}
</div>
```

#### Component Composition Pattern
```svelte
<!-- Usage example -->
<Card class="p-6">
  <CardHeader>
    <CardTitle>Workspace Settings</CardTitle>
    <CardDescription>
      Configure your workspace preferences
    </CardDescription>
  </CardHeader>
  <CardContent>
    <Button variant="outline" onclick={handleSave}>
      Save Changes
    </Button>
  </CardContent>
</Card>
```

### Real-Time Integration

#### Phoenix LiveView Integration
```typescript
// services/liveview.ts
export class LiveViewIntegration {
  private hooks: Map<string, Function> = new Map();
  
  registerHook(name: string, hookFunction: Function) {
    this.hooks.set(name, hookFunction);
    window.addEventListener(`phx:${name}`, hookFunction);
  }
  
  pushEvent(event: string, payload: any) {
    window.liveSocket?.push(event, payload);
  }
  
  handlePush(event: string, payload: any) {
    // Handle server-pushed events
    switch (event) {
      case 'workspace_updated':
        workspaceActions.updateFromServer(payload);
        break;
      case 'document_changed':
        documentActions.syncFromServer(payload);
        break;
    }
  }
}
```

#### WebSocket Integration
```typescript
// services/websocket.ts
export class WebSocketService {
  private socket: Phoenix.Socket;
  private channels: Map<string, Phoenix.Channel> = new Map();
  
  constructor(token: string) {
    this.socket = new Socket('/socket', {
      params: { token },
      logger: (kind, msg, data) => console.log(`${kind}: ${msg}`, data)
    });
  }
  
  joinWorkspaceChannel(workspaceId: string) {
    const channel = this.socket.channel(`workspace:${workspaceId}`);
    
    channel.on('document_updated', (payload) => {
      // Update document state
      documentActions.handleRemoteUpdate(payload);
    });
    
    channel.on('user_joined', (payload) => {
      // Update collaboration state
      collaborationActions.userJoined(payload);
    });
    
    channel.join();
    this.channels.set(workspaceId, channel);
  }
}
```

### Editor Integration

#### TipTap Editor Component

**CRITICAL IMPLEMENTATION NOTE**: The system uses an existing `Editor.svelte` component that integrates with the `elim` package. This component includes specialized integrations (`ShadcnEditor`, `ShadcnToolBar`, `ShadcnBubbleMenu`, `ShadcnDragHandle`) and should **NOT** be reimplemented.

```svelte
<!-- Editor.svelte (Existing Implementation) -->
<script lang="ts">
  import { ShadcnEditor, ShadcnToolBar, ShadcnBubbleMenu, ShadcnDragHandle } from 'elim';
  
  let { 
    content = '',
    onUpdate,
    collaborative = false,
    readonly = false
  } = $props();
  
  // Editor configuration with elim components
  const editorConfig = {
    content,
    editable: !readonly,
    onUpdate: ({ editor }) => {
      onUpdate?.(editor.getHTML());
    },
    extensions: [
      // Pre-configured extensions from elim package
    ]
  };
</script>

<div class="editor-container">
  <ShadcnToolBar />
  <ShadcnEditor config={editorConfig}>
    <ShadcnBubbleMenu />
    <ShadcnDragHandle />
  </ShadcnEditor>
</div>
```

#### Collaborative Editing Features
- **Real-time synchronization** via WebSocket channels
- **Conflict resolution** using operational transforms
- **Cursor awareness** showing other users' positions
- **Change attribution** with user avatars and colors

### Routing and Navigation

#### Client-Side Routing
```typescript
// Router implementation
export class Router {
  private routes: Map<string, Component> = new Map();
  private currentRoute = writable('/dashboard');
  
  register(path: string, component: Component) {
    this.routes.set(path, component);
  }
  
  navigate(path: string) {
    history.pushState({}, '', path);
    this.currentRoute.set(path);
    
    // Emit custom navigation event
    window.dispatchEvent(new CustomEvent('navigate', {
      detail: { url: path }
    }));
  }
  
  getComponent(path: string) {
    return this.routes.get(path) || NotFoundComponent;
  }
}
```

#### Route Components
```svelte
<!-- App.svelte route handling -->
<script lang="ts">
  import { onMount } from 'svelte';
  
  let currentRoute = $state('/dashboard');
  
  // Route component mapping
  const routes = {
    '/dashboard': Dashboard,
    '/workspaces': WorkspaceManager,
    '/documents': DocumentBrowser,
    '/notebooks': NotebookManager,
    '/teams': TeamManager,
    '/settings': Settings
  };
  
  const routeComponent = $derived(
    routes[currentRoute] || NotFound
  );
  
  onMount(() => {
    // Listen for navigation events
    window.addEventListener('navigate', (event) => {
      currentRoute = event.detail.url;
    });
    
    // Handle browser back/forward
    window.addEventListener('popstate', () => {
      currentRoute = window.location.pathname;
    });
  });
</script>

<AppLayout>
  {#if routeComponent}
    {@const Component = routeComponent}
    <Component />
  {/if}
</AppLayout>
```

### Performance Optimization

#### Code Splitting Strategy
```typescript
// Dynamic imports for route-based splitting
const routes = {
  '/dashboard': () => import('./components/dashboard/Dashboard.svelte'),
  '/workspaces': () => import('./components/workspaces/WorkspaceManager.svelte'),
  '/documents': () => import('./components/documents/DocumentBrowser.svelte'),
  '/notebooks': () => import('./components/notebooks/NotebookManager.svelte')
};

// Lazy loading with suspense
async function loadRouteComponent(path: string) {
  const loader = routes[path];
  if (loader) {
    const module = await loader();
    return module.default;
  }
  return NotFound;
}
```

#### Bundle Analysis
```bash
# Analyze bundle size
npm run build:analyze

# Bundle size monitoring
npm run bundle:size
```

#### Image Optimization
```typescript
// Image optimization utilities
export function optimizeImage(src: string, options: ImageOptions = {}) {
  const { width, height, format = 'webp', quality = 80 } = options;
  
  // Generate optimized image URL
  return `/api/images/optimize?src=${encodeURIComponent(src)}&w=${width}&h=${height}&f=${format}&q=${quality}`;
}

// Lazy loading implementation
export function lazyLoad(node: HTMLImageElement, src: string) {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        node.src = src;
        observer.disconnect();
      }
    });
  });
  
  observer.observe(node);
  
  return {
    destroy() {
      observer.disconnect();
    }
  };
}
```

### Accessibility Implementation

#### Semantic HTML Structure
```svelte
<!-- Proper semantic structure -->
<main role="main" aria-label="Workspace dashboard">
  <header>
    <h1>Dashboard</h1>
    <nav aria-label="Workspace navigation">
      <ul role="list">
        <li><a href="/documents">Documents</a></li>
        <li><a href="/notebooks">Notebooks</a></li>
      </ul>
    </nav>
  </header>
  
  <section aria-labelledby="recent-activity">
    <h2 id="recent-activity">Recent Activity</h2>
    <!-- Content -->
  </section>
</main>
```

#### Keyboard Navigation
```svelte
<script lang="ts">
  function handleKeydown(event: KeyboardEvent) {
    switch (event.key) {
      case 'Escape':
        closeModal();
        break;
      case 'Enter':
      case ' ':
        if (event.target === button) {
          handleClick();
        }
        break;
    }
  }
</script>

<div onkeydown={handleKeydown} tabindex="0" role="button" aria-pressed={isPressed}>
  <!-- Interactive content -->
</div>
```

#### Screen Reader Support
```svelte
<!-- Screen reader friendly components -->
<button
  aria-label="Delete document"
  aria-describedby="delete-description"
  onclick={handleDelete}
>
  <TrashIcon aria-hidden="true" />
</button>

<div id="delete-description" class="sr-only">
  This action cannot be undone
</div>
```

### Testing Strategy

#### Component Testing
```typescript
// Component test example
import { render, screen } from '@testing-library/svelte';
import { expect, test } from 'vitest';
import Button from './Button.svelte';

test('renders button with correct text', () => {
  render(Button, { props: { children: 'Click me' } });
  
  const button = screen.getByRole('button', { name: /click me/i });
  expect(button).toBeInTheDocument();
});

test('calls onclick handler when clicked', async () => {
  const handleClick = vi.fn();
  render(Button, { props: { onclick: handleClick, children: 'Click me' } });
  
  const button = screen.getByRole('button');
  await button.click();
  
  expect(handleClick).toHaveBeenCalledOnce();
});
```

#### Integration Testing
```typescript
// Store integration tests
import { get } from 'svelte/store';
import { workspaces, workspaceActions } from '../stores/workspaces';

test('loads workspaces successfully', async () => {
  const mockApi = {
    workspaces: {
      list: vi.fn().mockResolvedValue([
        { id: '1', name: 'Test Workspace' }
      ])
    }
  };
  
  await workspaceActions.load(mockApi);
  
  const state = get(workspaces);
  expect(state.items).toHaveLength(1);
  expect(state.loading).toBe(false);
});
```

### Development Workflow

#### Hot Module Replacement
```typescript
// Vite HMR configuration
if (import.meta.hot) {
  import.meta.hot.accept('./stores/workspaces.ts', (newModule) => {
    // Update store without losing state
    console.log('Store updated:', newModule);
  });
}
```

#### Development Server
```bash
# Start development server with HMR
npm run dev

# Start with specific port
npm run dev -- --port 4000

# Build for production
npm run build

# Preview production build
npm run preview
```

### Icon Integration

#### Correct Lucide Import Pattern
**CRITICAL**: Always use the correct import path for Lucide icons:

```typescript
// CORRECT - Use @lucide/svelte
import { Users, Plus, Mail, Settings, Loader2, AlertCircle } from '@lucide/svelte';

// WRONG - Do not use lucide-svelte (causes build failures)
import { Users } from 'lucide-svelte';
```

#### Icon Usage Patterns
```svelte
<script lang="ts">
  import { ChevronDown, Settings, User } from '@lucide/svelte';
</script>

<!-- Icon with accessibility -->
<button aria-label="Open settings">
  <Settings class="h-4 w-4" aria-hidden="true" />
</button>

<!-- Icon with text -->
<div class="flex items-center gap-2">
  <User class="h-4 w-4" />
  <span>User Profile</span>
</div>
```

### Deployment and Build

#### Production Build Configuration
```typescript
// vite.config.mts
export default defineConfig({
  plugins: [sveltekit()],
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['svelte', '@lucide/svelte'],
          ui: ['./src/ui/button', './src/ui/card']
        }
      }
    },
    sourcemap: false,
    minify: 'terser'
  }
});
```

#### Asset Optimization
```bash
# Image optimization
npm run optimize:images

# Bundle analysis
npm run analyze:bundle

# Performance audit
npm run audit:performance
```

This frontend architecture provides a solid foundation for building responsive, accessible, and performant user interfaces while maintaining tight integration with the Phoenix LiveView backend and supporting real-time collaborative features.