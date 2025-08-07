<script lang="ts">
  import { onMount } from 'svelte';
  import {
    initializeApp,
    auth,
    currentTeam,
    currentWorkspace,
    ui,
    teams,
    workspaces,
    documents,
    notebooks,
    notifications,
    apiService
  } from './stores/index';
  import { createApiService } from './services/api';
  import type { ApiConfig } from './types';

  // Layout components
  import AppLayout from './layout/AppLayout.svelte';

  // Feature components
  import TeamManager from './components/teams/TeamManager.svelte';
  import WorkspaceManager from './components/workspaces/WorkspaceManager.svelte';
  import DocumentBrowser from './components/documents/DocumentBrowser.svelte';
  import NotebookManager from './components/notebooks/NotebookManager.svelte';
  import ProjectManager from './components/projects/ProjectManager.svelte';
  import Dashboard from './components/dashboard/Dashboard.svelte';
  import Settings from './components/settings/Settings.svelte';
  // import NotificationCenter from './components/notifications/NotificationCenter.svelte';
  // import SearchInterface from './components/search/SearchInterface.svelte';

  // UI components
  import { Button } from './ui/button';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';
  import { Alert, AlertDescription } from './ui/alert';
  import { Skeleton } from './ui/skeleton';

  // Icons
  import {
    AlertCircle,
    Loader2,
    Wifi,
    WifiOff
  } from '@lucide/svelte';

  const {
    apiToken = '',
    csrfToken = '',
    baseUrl = '/api/v1',
    teamId = '',
    userId = '',
    userName = '',
    userEmail = '',
    userAvatar = ''
  } = $props();

  let mounted = $state(false);
  let initError = $state<string | null>(null);
  let isOnline = $state(true);
  let currentRoute = $state('/dashboard');

  // Route mapping
  const routeComponent = $derived(getRouteComponent(currentRoute));

  function getRouteComponent(path: string) {
    if (path === '/' || path === '/dashboard') return Dashboard;
    if (path.startsWith('/teams')) return TeamManager;
    if (path.startsWith('/workspaces')) return WorkspaceManager;
    if (path.startsWith('/documents')) return DocumentBrowser;
    if (path.startsWith('/notebooks')) return NotebookManager;
    if (path.startsWith('/projects')) return ProjectManager;
    if (path.startsWith('/settings')) return Settings;
    if (path.startsWith('/notifications')) return NotificationPlaceholder;
    if (path.startsWith('/search')) return SearchPlaceholder;
    return Dashboard; // Default fallback
  }

  // Placeholder components for missing imports
  function NotificationPlaceholder() {
    return 'div';
  }

  function SearchPlaceholder() {
    return 'div';
  }

  function getPageTitle(path: string): string {
    if (path === '/' || path === '/dashboard') return 'Dashboard';
    if (path.startsWith('/teams')) return 'Teams';
    if (path.startsWith('/workspaces')) return 'Workspaces';
    if (path.startsWith('/documents')) return 'Documents';
    if (path.startsWith('/notebooks')) return 'Notebooks';
    if (path.startsWith('/projects')) return 'Projects';
    if (path.startsWith('/settings')) return 'Settings';
    if (path.startsWith('/notifications')) return 'Notifications';
    if (path.startsWith('/search')) return 'Search';
    return 'Kyozo';
  }

  function getPageSubtitle(path: string): string {
    if ($currentTeam && $currentWorkspace) {
      return `${$currentTeam.name} / ${$currentWorkspace.name}`;
    } else if ($currentTeam) {
      return $currentTeam.name;
    }
    return '';
  }

  onMount(async () => {
    if (typeof window === 'undefined') return;

    // Get current route from window location
    currentRoute = window.location.pathname;

    try {
      // Check online status
      isOnline = navigator.onLine;
      window.addEventListener('online', () => isOnline = true);
      window.addEventListener('offline', () => isOnline = false);

      // Initialize API configuration
      const config: ApiConfig = {
        baseUrl,
        apiToken,
        csrfToken,
        teamId
      };

      // Initialize the app
      const api = initializeApp(config);

      // Set initial auth state if we have user data
      if (userId && userName && userEmail) {
        auth.update(state => ({
          ...state,
          user: {
            id: userId,
            name: userName,
            email: userEmail,
            avatar: userAvatar,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
          },
          isAuthenticated: true
        }));
      }

      // Load initial data
      await loadInitialData();

      mounted = true;
    } catch (error) {
      console.error('Failed to initialize app:', error);
      initError = error instanceof Error ? error.message : 'Failed to initialize application';
    }
  });

  async function loadInitialData() {
    try {
      ui.update(state => ({ ...state, loading: true }));

      // Temporarily disabled - causing backend error
      // await teams.load($apiService);

      // Set current team if teamId is provided
      if (teamId) {
        // Temporarily disabled loading logic to fix backend error
        console.log('Would load team data for teamId:', teamId);
      }

      // Listen for route changes
      window.addEventListener('popstate', () => {
        currentRoute = window.location.pathname;
      });
      
      // Listen for custom navigation events
      window.addEventListener('navigate', (event: Event) => {
        const customEvent = event as CustomEvent<{ url: string }>;
        currentRoute = customEvent.detail.url;
      });

      // Load notifications
      await notifications.load($apiService);

    } catch (error) {
      console.error('Failed to load initial data:', error);
      ui.update(state => ({
        ...state,
        error: error instanceof Error ? error.message : 'Failed to load data'
      }));
    } finally {
      ui.update(state => ({ ...state, loading: false }));
    }
  }

  // Reactive data loading when team/workspace changes
  $effect(() => {
    if (mounted && $currentTeam && $apiService) {
      workspaces.load($apiService);
    }
  });

  $effect(() => {
    if (mounted && $currentWorkspace && $apiService) {
      Promise.all([
        documents.load($apiService, $currentWorkspace.id),
        notebooks.load($apiService, $currentWorkspace.id)
      ]);
    }
  });

  // Handle route changes
  $effect(() => {
    if (mounted && currentRoute && typeof window !== 'undefined') {
      // Update page title
      document.title = `${getPageTitle(currentRoute)} - Kyozo`;
    }
  });

  function retryInitialization() {
    initError = null;
    mounted = false;
    loadInitialData();
  }

  function dismissError() {
    ui.update(state => ({ ...state, error: undefined }));
  }
</script>

<svelte:head>
  <title>{getPageTitle(currentRoute)} - Kyozo</title>
  <meta name="description" content="Kyozo - Collaborative Notebook Platform" />
</svelte:head>

<!-- Global loading indicator -->
{#if $ui.loading && !mounted}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-background/80 backdrop-blur-sm">
    <div class="flex flex-col items-center space-y-4">
      <Loader2 class="h-8 w-8 animate-spin text-primary" />
      <p class="text-sm text-muted-foreground">Loading Kyozo...</p>
    </div>
  </div>
{/if}

<!-- Initialization error -->
{#if initError}
  <div class="flex min-h-screen items-center justify-center bg-background p-4">
    <Card class="w-full max-w-md">
      <CardHeader>
        <div class="flex items-center space-x-2">
          <AlertCircle class="h-5 w-5 text-destructive" />
          <CardTitle>Initialization Failed</CardTitle>
        </div>
        <CardDescription>
          There was a problem starting the application.
        </CardDescription>
      </CardHeader>
      <CardContent class="space-y-4">
        <Alert variant="destructive">
          <AlertDescription>
            {initError}
          </AlertDescription>
        </Alert>

        <div class="flex justify-end space-x-2">
          <Button variant="outline" onclick={() => window.location.reload()}>
            Refresh Page
          </Button>
          <Button onclick={retryInitialization}>
            Try Again
          </Button>
        </div>
      </CardContent>
    </Card>
  </div>
{:else if !mounted}
  <!-- Loading skeleton -->
  <div class="flex h-screen">
    <div class="hidden w-64 border-r bg-background lg:block">
      <div class="p-6">
        <Skeleton class="h-8 w-24 mb-6" />
        <div class="space-y-3">
          <Skeleton class="h-4 w-full" />
          <Skeleton class="h-4 w-3/4" />
          <Skeleton class="h-4 w-1/2" />
        </div>
      </div>

    </div>
    <div class="flex-1">
      <div class="border-b p-4">
        <Skeleton class="h-6 w-32" />
      </div>
      <div class="p-6">
        <div class="space-y-4">
          <Skeleton class="h-8 w-48" />
          <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {#each Array(6) as _}
              <Skeleton class="h-48 w-full" />
            {/each}
          </div>
        </div>
      </div>
    </div>
  </div>
{:else}
  <!-- Main application -->
  <AppLayout
    title={getPageTitle(currentRoute)}
    subtitle={getPageSubtitle(currentRoute)}
  >
    <!-- Global error message -->
    {#if $ui.error}
      <div class="mb-4">
        <Alert variant="destructive">
          <AlertCircle class="h-4 w-4" />
          <AlertDescription class="flex items-center justify-between">
            <span>{$ui.error}</span>
            <Button variant="ghost" size="sm" onclick={dismissError}>
              Dismiss
            </Button>
          </AlertDescription>
        </Alert>
      </div>
    {/if}

    <!-- Offline indicator -->
    {#if !isOnline}
      <div class="mb-4">
        <Alert>
          <WifiOff class="h-4 w-4" />
          <AlertDescription>
            You're currently offline. Some features may not be available.
          </AlertDescription>
        </Alert>
      </div>
    {/if}

    <!-- Route-specific content -->
    <div class="flex-1 overflow-auto">
      {#if routeComponent && typeof routeComponent !== 'function'}
        {@const Component = routeComponent}
        <Component />
      {:else if routeComponent === NotificationPlaceholder}
        <div class="p-6">
          <h1 class="text-2xl font-bold mb-4">Notifications</h1>
          <p class="text-muted-foreground">Notifications feature coming soon...</p>
        </div>
      {:else if routeComponent === SearchPlaceholder}
        <div class="p-6">
          <h1 class="text-2xl font-bold mb-4">Search</h1>
          <p class="text-muted-foreground">Search feature coming soon...</p>
        </div>
      {:else}
        <!-- 404 fallback -->
        <div class="flex flex-col items-center justify-center min-h-[50vh] space-y-4">
          <h2 class="text-2xl font-bold">Page Not Found</h2>
          <p class="text-muted-foreground">The page you're looking for doesn't exist.</p>
          <Button onclick={() => window.history.back()}>
            Go Back
          </Button>
        </div>
      {/if}
    </div>
  </AppLayout>
{/if}

<!-- Global styles -->
<style>
  :global(html) {
    height: 100%;
    overflow-x: hidden;
  }

  :global(body) {
    height: 100%;
    overflow-x: hidden;
  }

  :global(.line-clamp-2) {
    overflow: hidden;
    display: -webkit-box;
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 2;
  }

  :global(.line-clamp-3) {
    overflow: hidden;
    display: -webkit-box;
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 3;
  }

  /* Custom scrollbar */
  :global(.overflow-auto) {
    scrollbar-width: thin;
    scrollbar-color: hsl(var(--muted)) transparent;
  }

  :global(.overflow-auto::-webkit-scrollbar) {
    width: 6px;
    height: 6px;
  }

  :global(.overflow-auto::-webkit-scrollbar-track) {
    background: transparent;
  }

  :global(.overflow-auto::-webkit-scrollbar-thumb) {
    background-color: hsl(var(--muted));
    border-radius: 3px;
  }

  :global(.overflow-auto::-webkit-scrollbar-thumb:hover) {
    background-color: hsl(var(--muted-foreground));
  }

  /* Loading states */
  :global(.loading) {
    pointer-events: none;
    opacity: 0.7;
  }

  /* Responsive utilities */
  @media (max-width: 768px) {
    :global(.mobile-hidden) {
      display: none !important;
    }
  }

  @media (min-width: 769px) {
    :global(.desktop-hidden) {
      display: none !important;
    }
  }

  /* Animation utilities */
  :global(.fade-in) {
    animation: fadeIn 0.2s ease-in-out;
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
      transform: translateY(4px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  :global(.slide-in) {
    animation: slideIn 0.3s ease-out;
  }

  @keyframes slideIn {
    from {
      transform: translateX(-100%);
    }
    to {
      transform: translateX(0);
    }
  }

  /* Focus states */
  :global(.focus-visible) {
    outline: 2px solid hsl(var(--ring));
    outline-offset: 2px;
  }

  /* High contrast mode support */
  @media (prefers-contrast: high) {
    :global(.border) {
      border-width: 2px;
    }
  }

  /* Reduced motion support */
  @media (prefers-reduced-motion: reduce) {
    :global(*) {
      animation-duration: 0.01ms !important;
      animation-iteration-count: 1 !important;
      transition-duration: 0.01ms !important;
    }
  }
</style>