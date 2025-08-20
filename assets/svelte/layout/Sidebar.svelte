<script lang="ts">
  import { goto } from '../utils';
  import { 
    currentTeam, 
    currentWorkspace, 
    auth, 
    notifications,
    ui 
  } from '../stores/index';
  import { Button } from '../ui/button';
  import { Icons } from '../shared/icons';
  import { Avatar, AvatarFallback, AvatarImage } from '../ui/avatar';
  import { Badge } from '../ui/badge';
  import { Separator } from '../ui/separator';
  import { 
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger
  } from '../ui/dropdown-menu';
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
    ChevronDown,
    LogOut,
    Building,
    Folder,
    Code,
    PlayCircle,
    Archive,
    Star,
    Clock,
    TrendingUp
  } from '@lucide/svelte';

  interface Props {
    mobile?: boolean;
  }

  let { mobile = false }: Props = $props();

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
    if (mobile) {
      ui.update(state => ({ ...state, mobileMenuOpen: false }));
    }
  }

  function handleTeamSelect() {
    // Open team selector
    goto('/teams');
  }

  function handleWorkspaceSelect() {
    // Open workspace selector
    goto('/workspaces');
  }

  function getInitials(name: string): string {
    return name
      .split(' ')
      .map(word => word.charAt(0))
      .join('')
      .toUpperCase()
      .slice(0, 2);
  }
</script>

<div class="flex flex-col h-full bg-background border-r border-border">
  <!-- Logo/Brand -->
  <div class="flex items-center px-4 py-6">
    <div class="flex items-center space-x-3">
      <Icons.logo size={32} />
      <span class="text-xl font-bold text-foreground">Kyozo</span>
    </div>
  </div>

  <!-- Current Team/Workspace Selector -->
  {#if $currentTeam}
    <div class="px-4 mb-4">
      <DropdownMenu>
        <DropdownMenuTrigger>
          <Button
            variant="ghost"
            class="w-full justify-between p-2 h-auto"
          >
            <div class="flex items-center space-x-3 min-w-0">
              <Avatar class="h-8 w-8">
                <AvatarFallback class="text-xs bg-primary text-primary-foreground">
                  {getInitials($currentTeam.name)}
                </AvatarFallback>
              </Avatar>
              <div class="flex flex-col items-start min-w-0">
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
            <ChevronDown class="h-4 w-4 text-muted-foreground" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent class="w-56" align="start">
          <DropdownMenuLabel>Teams</DropdownMenuLabel>
          <DropdownMenuSeparator />
          <DropdownMenuItem onclick={handleTeamSelect}>
            <Building class="mr-2 h-4 w-4" />
            Switch Team
          </DropdownMenuItem>
          <DropdownMenuItem>
            <Plus class="mr-2 h-4 w-4" />
            Create Team
          </DropdownMenuItem>
          
          {#if $currentTeam}
            <DropdownMenuSeparator />
            <DropdownMenuLabel>Workspaces</DropdownMenuLabel>
            <DropdownMenuItem onclick={handleWorkspaceSelect}>
              <Folder class="mr-2 h-4 w-4" />
              Switch Workspace
            </DropdownMenuItem>
            <DropdownMenuItem>
              <Plus class="mr-2 h-4 w-4" />
              New Workspace
            </DropdownMenuItem>
          {/if}
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  {/if}

  <!-- Quick Actions -->
  <div class="px-4 mb-6">
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
  <nav class="flex-1 px-4 space-y-6">
    {#each navigationItems as section}
      <div>
        <h3 class="px-2 mb-2 text-xs font-semibold text-muted-foreground uppercase tracking-wider">
          {section.section}
        </h3>
        <div class="space-y-1">
          {#each section.items as item}
            <Button
              variant={isActive(item.href) ? 'secondary' : 'ghost'}
              class="w-full justify-start font-normal"
              onclick={() => handleNavigation(item.href)}
            >
              <svelte:component this={item.icon} class="mr-3 h-4 w-4" />
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
    {#if $currentWorkspace}
      <div>
        <h3 class="px-2 mb-2 text-xs font-semibold text-muted-foreground uppercase tracking-wider">
          Recent
        </h3>
        <div class="space-y-1">
          <Button
            variant="ghost"
            class="w-full justify-start font-normal text-muted-foreground"
            size="sm"
          >
            <Clock class="mr-3 h-4 w-4" />
            No recent items
          </Button>
        </div>
      </div>
    {/if}

    <!-- Favorites -->
    <div>
      <h3 class="px-2 mb-2 text-xs font-semibold text-muted-foreground uppercase tracking-wider">
        Favorites
      </h3>
      <div class="space-y-1">
        <Button
          variant="ghost"
          class="w-full justify-start font-normal text-muted-foreground"
          size="sm"
        >
          <Star class="mr-3 h-4 w-4" />
          No favorites yet
        </Button>
      </div>
    </div>
  </nav>

  <!-- Bottom Section -->
  <div class="p-4 space-y-4">
    <Separator />
    
    <!-- Notifications -->
    <Button 
      variant="ghost" 
      class="w-full justify-start"
      onclick={() => handleNavigation('/notifications')}
    >
      <Bell class="mr-3 h-4 w-4" />
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
      <Settings class="mr-3 h-4 w-4" />
      Settings
    </Button>

    <!-- User Profile -->
    {#if $auth.user}
      <DropdownMenu>
        <DropdownMenuTrigger>
          <Button
            variant="ghost"
            class="w-full justify-start p-2 h-auto"
          >
            <div class="flex items-center space-x-3 min-w-0">
              <Avatar class="h-8 w-8">
                <AvatarImage src={$auth.user.avatar} alt={$auth.user.name} />
                <AvatarFallback class="text-xs">
                  {getInitials($auth.user.name)}
                </AvatarFallback>
              </Avatar>
              <div class="flex flex-col items-start min-w-0">
                <span class="text-sm font-medium text-foreground truncate">
                  {$auth.user.name}
                </span>
                <span class="text-xs text-muted-foreground truncate">
                  {$auth.user.email}
                </span>
              </div>
            </div>
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent class="w-56" align="start">
          <DropdownMenuLabel>My Account</DropdownMenuLabel>
          <DropdownMenuSeparator />
          <DropdownMenuItem onclick={() => handleNavigation('/profile')}>
            <Settings class="mr-2 h-4 w-4" />
            Profile Settings
          </DropdownMenuItem>
          <DropdownMenuItem onclick={() => handleNavigation('/billing')}>
            <TrendingUp class="mr-2 h-4 w-4" />
            Billing
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem class="text-destructive">
            <LogOut class="mr-2 h-4 w-4" />
            Sign Out
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    {/if}
  </div>
</div>