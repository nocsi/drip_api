<script lang="ts">
  import { onMount } from 'svelte';
  import {
    ui,
    currentTeam,
    currentWorkspace,
    auth,
    notifications,
    useMediaQuery
  } from '../stores/index';
  import { Button } from '../ui/button';
  import { Sheet, SheetContent, SheetTrigger } from '../ui/sheet';
  import { Avatar, AvatarFallback, AvatarImage } from '../ui/avatar';
  import { Badge } from '../ui/badge';
  import { Separator } from '../ui/separator';
  import {
    Menu,
    Home,
    Users,
    FolderOpen,
    FileText,
    BookOpen,
    Settings,
    Bell,
    Search,
    Plus,
    ChevronDown,
    LogOut
  } from '@lucide/svelte';
  import Sidebar from './Sidebar.svelte';
  import TopBar from './TopBar.svelte';
  import MobileNav from './MobileNav.svelte';

  interface Props {
    title?: string;
    subtitle?: string;
    children?: any;
  }

  let { title = 'Kyozo', subtitle = '', children }: Props = $props();

  const screenInfo = useMediaQuery(typeof window !== 'undefined');

  const isMobile = $derived($screenInfo?.isMobile ?? false);
  const isTablet = $derived($screenInfo?.isTablet ?? false);
  const sidebarOpen = $derived($ui.sidebarOpen && !isMobile);

  onMount(() => {
    // Initialize theme
    if (typeof window !== 'undefined') {
      const root = document.documentElement;
      const theme = localStorage.getItem('kyozo-theme') || 'system';

      if (theme === 'system') {
        const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
        root.classList.toggle('dark', prefersDark);
      } else {
        root.classList.toggle('dark', theme === 'dark');
      }
    }
  });

  function toggleSidebar() {
    ui.update(state => ({ ...state, sidebarOpen: !state.sidebarOpen }));
  }

  function toggleMobileMenu() {
    ui.update(state => ({ ...state, mobileMenuOpen: !state.mobileMenuOpen }));
  }
</script>

<div class="flex h-screen bg-background">
  <!-- Desktop Sidebar -->
  {#if !isMobile}
    <div class="hidden lg:flex lg:flex-shrink-0">
      <div class="flex flex-col w-64">
        <Sidebar />
      </div>
    </div>
  {/if}

  <!-- Mobile Navigation -->
  {#if isMobile}
    <MobileNav />
  {/if}

  <!-- Main Content Area -->
  <div class="flex-1 flex flex-col overflow-hidden">
    <!-- Top Bar -->
    <TopBar {title} {subtitle} />

    <!-- Main Content -->
    <main class="flex-1 overflow-y-auto bg-background">
      <div class="h-full">
        {@render children?.()}
      </div>
    </main>
  </div>
</div>

<!-- Mobile Menu Overlay -->
{#if isMobile && $ui.mobileMenuOpen}
  <div
    class="fixed inset-0 z-50 lg:hidden"
    role="dialog"
    aria-modal="true"
  >
    <div class="fixed inset-0 bg-background/80 backdrop-blur-sm" />
    <div class="fixed inset-y-0 left-0 z-50 w-full overflow-y-auto bg-background px-6 py-6 sm:max-w-sm sm:ring-1 sm:ring-border">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-2">
          <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-primary">
            <span class="text-sm font-bold text-primary-foreground">K</span>
          </div>
          <span class="text-lg font-semibold">Kyozo</span>
        </div>
        <Button
          variant="ghost"
          size="sm"
          onclick={toggleMobileMenu}
        >
          <span class="sr-only">Close menu</span>
          <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </Button>
      </div>

      <nav class="mt-6">
        <Sidebar mobile={true} />
      </nav>
    </div>
  </div>
{/if}

<style>
  :global(html) {
    height: 100%;
    overflow: hidden;
  }

  :global(body) {
    height: 100%;
    overflow: hidden;
  }
</style>