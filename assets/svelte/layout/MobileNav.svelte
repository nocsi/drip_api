<script lang="ts">
  import { goto } from '../utils';
  import { 
    ui, 
    currentTeam, 
    currentWorkspace, 
    auth, 
    notifications 
  } from '../stores/index';
  import { Button } from '../ui/button';
  import { Avatar, AvatarFallback, AvatarImage } from '../ui/avatar';
  import { Badge } from '../ui/badge';
  import { Separator } from '../ui/separator';
  import { 
    Home, 
    Users, 
    FolderOpen, 
    FileText, 
    BookOpen, 
    Settings, 
    Bell,
    Search,
    Plus,
    LogOut,
    Building,
    Folder,
    Code,
    PlayCircle,
    Clock,
    Star,
    X
  } from '@lucide/svelte';
  import { onMount } from 'svelte';

  const workspacesBadge = $derived($currentTeam?.workspaces_count || null);

  const navigationItems = $derived([
    {
      section: 'Main',
      items: [
        { 
          label: 'Dashboard', 
          href: '/dashboard', 
          icon: Home,
          badge: null
        },
        { 
          label: 'Search', 
          href: '/search', 
          icon: Search,
          badge: null
        }
      ]
    },
    {
      section: 'Teams & Workspaces',
      items: [
        { 
          label: 'Teams', 
          href: '/teams', 
          icon: Users,
          badge: null
        },
        { 
          label: 'Workspaces', 
          href: '/workspaces', 
          icon: FolderOpen,
          badge: workspacesBadge
        }
      ]
    },
    {
      section: 'Content',
      items: [
        { 
          label: 'Documents', 
          href: '/documents', 
          icon: FileText,
          badge: null
        },
        { 
          label: 'Notebooks', 
          href: '/notebooks', 
          icon: BookOpen,
          badge: null
        },
        { 
          label: 'Projects', 
          href: '/projects', 
          icon: Code,
          badge: null
        }
      ]
    }
  ]);

  const currentPath = $derived(typeof window !== 'undefined' ? window.location.pathname : '/');
  
  function isActive(href: string): boolean {
    if (href === '/dashboard') {
      return currentPath === '/' || currentPath === '/dashboard';
    }
    return currentPath.startsWith(href);
  }

  function handleNavigation(href: string) {
    goto(href);
    closeMobileMenu();
  }

  function closeMobileMenu() {
    ui.update(state => ({ ...state, mobileMenuOpen: false }));
  }

  function getInitials(name: string): string {
    return name
      .split(' ')
      .map(word => word.charAt(0))
      .join('')
      .toUpperCase()
      .slice(0, 2);
  }

  // Close mobile menu when clicking outside
  function handleBackdropClick(event: MouseEvent) {
    if (event.target === event.currentTarget) {
      closeMobileMenu();
    }
  }

  // Close mobile menu on escape key
  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
      closeMobileMenu();
    }
  }

  onMount(() => {
    // Prevent body scroll when mobile menu is open
    const unsubscribe = ui.subscribe(state => {
      if (state.mobileMenuOpen) {
        document.body.style.overflow = 'hidden';
      } else {
        document.body.style.overflow = '';
      }
    });

    return () => {
      unsubscribe();
      document.body.style.overflow = '';
    };
  });
</script>

<svelte:window onkeydown={handleKeydown} />

{#if $ui.mobileMenuOpen}
  <!-- Backdrop -->
  <div 
    class="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm lg:hidden"
    onclick={handleBackdropClick}
    role="button"
    tabindex="-1"
  >
    <!-- Mobile Menu Panel -->
    <div class="fixed inset-y-0 left-0 z-50 w-full overflow-y-auto bg-background px-6 py-6 sm:max-w-sm sm:ring-1 sm:ring-border/10">
      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center space-x-3">
          <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-primary">
            <span class="text-sm font-bold text-primary-foreground">K</span>
          </div>
          <span class="text-xl font-bold text-foreground">Kyozo</span>
        </div>
        <Button 
          variant="ghost" 
          size="sm"
          onclick={closeMobileMenu}
        >
          <X class="h-6 w-6" />
          <span class="sr-only">Close menu</span>
        </Button>
      </div>

      <!-- User Info -->
      {#if $auth.user}
        <div class="mb-6 p-3 rounded-lg bg-muted/50">
          <div class="flex items-center space-x-3">
            <Avatar class="h-10 w-10">
              <AvatarImage src={$auth.user.avatar} alt={$auth.user.name} />
              <AvatarFallback>
                {getInitials($auth.user.name)}
              </AvatarFallback>
            </Avatar>
            <div class="flex flex-col min-w-0">
              <span class="text-sm font-medium text-foreground truncate">
                {$auth.user.name}
              </span>
              <span class="text-xs text-muted-foreground truncate">
                {$auth.user.email}
              </span>
            </div>
          </div>
        </div>
      {/if}

      <!-- Current Team/Workspace -->
      {#if $currentTeam}
        <div class="mb-6 p-3 rounded-lg border border-border">
          <div class="flex items-center space-x-3 mb-2">
            <Avatar class="h-8 w-8">
              <AvatarFallback class="text-xs bg-primary text-primary-foreground">
                {getInitials($currentTeam.name)}
              </AvatarFallback>
            </Avatar>
            <div class="flex flex-col min-w-0">
              <span class="text-sm font-medium text-foreground truncate">
                {$currentTeam.name}
              </span>
              {#if $currentWorkspace}
                <span class="text-xs text-muted-foreground truncate">
                  {$currentWorkspace.name}
                </span>
              {/if}
            </div>
          </div>
          <div class="flex space-x-2">
            <Button 
              variant="outline" 
              size="sm" 
              class="flex-1"
              onclick={() => handleNavigation('/teams')}
            >
              Switch Team
            </Button>
            <Button 
              variant="outline" 
              size="sm" 
              class="flex-1"
              onclick={() => handleNavigation('/workspaces')}
            >
              Switch Workspace
            </Button>
          </div>
        </div>
      {/if}

      <!-- Quick Actions -->
      <div class="mb-6">
        <h3 class="mb-3 text-sm font-semibold text-foreground">Quick Actions</h3>
        <div class="grid grid-cols-2 gap-2">
          <Button 
            variant="outline" 
            size="sm" 
            class="justify-start"
            onclick={() => handleNavigation('/documents/new')}
          >
            <Plus class="mr-2 h-4 w-4" />
            Document
          </Button>
          <Button 
            variant="outline" 
            size="sm" 
            class="justify-start"
            onclick={() => handleNavigation('/notebooks/new')}
          >
            <PlayCircle class="mr-2 h-4 w-4" />
            Notebook
          </Button>
        </div>
      </div>

      <!-- Navigation -->
      <nav class="space-y-6">
        {#each navigationItems as section}
          <div>
            <h3 class="mb-3 text-sm font-semibold text-muted-foreground uppercase tracking-wider">
              {section.section}
            </h3>
            <div class="space-y-1">
              {#each section.items as item}
                <Button
                  variant={isActive(item.href) ? 'secondary' : 'ghost'}
                  class="w-full justify-start font-normal"
                  onclick={() => handleNavigation(item.href)}
                >
                  <svelte:component this={item.icon} class="mr-3 h-5 w-5" />
                  {item.label}
                  {#if item.badge}
                    <Badge variant="secondary" class="ml-auto">
                      {item.badge}
                    </Badge>
                  {/if}
                </Button>
              {/each}
            </div>
          </div>
        {/each}

        <!-- Recent Items -->
        <div>
          <h3 class="mb-3 text-sm font-semibold text-muted-foreground uppercase tracking-wider">
            Recent
          </h3>
          <div class="space-y-1">
            <Button
              variant="ghost"
              class="w-full justify-start font-normal text-muted-foreground"
              size="sm"
            >
              <Clock class="mr-3 h-5 w-5" />
              No recent items
            </Button>
          </div>
        </div>

        <!-- Favorites -->
        <div>
          <h3 class="mb-3 text-sm font-semibold text-muted-foreground uppercase tracking-wider">
            Favorites
          </h3>
          <div class="space-y-1">
            <Button
              variant="ghost"
              class="w-full justify-start font-normal text-muted-foreground"
              size="sm"
            >
              <Star class="mr-3 h-5 w-5" />
              No favorites yet
            </Button>
          </div>
        </div>
      </nav>

      <!-- Bottom Actions -->
      <div class="mt-8 space-y-2">
        <Separator class="mb-4" />
        
        <!-- Notifications -->
        <Button 
          variant="ghost" 
          class="w-full justify-start"
          onclick={() => handleNavigation('/notifications')}
        >
          <Bell class="mr-3 h-5 w-5" />
          Notifications
          {#if $notifications.unreadCount > 0}
            <Badge variant="destructive" class="ml-auto">
              {$notifications.unreadCount}
            </Badge>
          {/if}
        </Button>

        <!-- Settings -->
        <Button 
          variant="ghost" 
          class="w-full justify-start"
          onclick={() => handleNavigation('/settings')}
        >
          <Settings class="mr-3 h-5 w-5" />
          Settings
        </Button>

        <!-- Sign Out -->
        <Button 
          variant="ghost" 
          class="w-full justify-start text-destructive"
        >
          <LogOut class="mr-3 h-5 w-5" />
          Sign Out
        </Button>
      </div>
    </div>
  </div>
{/if}