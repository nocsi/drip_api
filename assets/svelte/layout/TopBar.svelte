<script lang="ts">
  import { goto } from '../utils';
  import { 
    ui, 
    currentTeam, 
    currentWorkspace, 
    auth, 
    notifications,
    search,
    useMediaQuery 
  } from '../stores/index';
  import { Button } from '../ui/button';
  import { Input } from '../ui/input';
  import { Avatar, AvatarFallback, AvatarImage } from '../ui/avatar';
  import { Badge } from '../ui/badge';
  import { 
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger
  } from '../ui/dropdown-menu';
  import { 
    Command,
    CommandDialog,
    CommandEmpty,
    CommandGroup,
    CommandInput,
    CommandItem,
    CommandList
  } from '../ui/command';
  import { 
    Menu, 
    Search, 
    Bell,
    Plus,
    Settings,
    LogOut,
    ChevronDown,
    Moon,
    Sun,
    Monitor,
    Command as CommandIcon,
    Zap,
    FileText,
    BookOpen,
    Users,
    Building
  } from '@lucide/svelte';

  interface Props {
    title?: string;
    subtitle?: string;
  }

  let { title = '', subtitle = '' }: Props = $props();

  const screenInfo = useMediaQuery(browser);
  
  const isMobile = $derived($screenInfo?.isMobile ?? false);
  const isTablet = $derived($screenInfo?.isTablet ?? false);

  let searchQuery = $state('');
  let showCommandPalette = $state(false);
  let searchResults = $state<any[]>([]);
  let searchTimeout: number;

  function toggleSidebar() {
    ui.update(state => ({ ...state, sidebarOpen: !state.sidebarOpen }));
  }

  function toggleMobileMenu() {
    ui.update(state => ({ ...state, mobileMenuOpen: !state.mobileMenuOpen }));
  }

  function openCommandPalette() {
    showCommandPalette = true;
  }

  function closeCommandPalette() {
    showCommandPalette = false;
    searchQuery = '';
  }

  function handleSearch(query: string) {
    searchQuery = query;
    
    if (searchTimeout) {
      clearTimeout(searchTimeout);
    }
    
    if (!query.trim()) {
      searchResults = [];
      return;
    }

    searchTimeout = setTimeout(async () => {
      // TODO: Implement actual search via API
      searchResults = [
        {
          id: '1',
          type: 'document',
          title: 'Getting Started Guide',
          description: 'A comprehensive guide to get you started with Kyozo',
          icon: FileText
        },
        {
          id: '2', 
          type: 'notebook',
          title: 'Data Analysis Notebook',
          description: 'Python notebook for data analysis and visualization',
          icon: BookOpen
        },
        {
          id: '3',
          type: 'team',
          title: 'Engineering Team',
          description: 'Main engineering team workspace',
          icon: Users
        }
      ].filter(item => 
        item.title.toLowerCase().includes(query.toLowerCase()) ||
        item.description.toLowerCase().includes(query.toLowerCase())
      );
    }, 300);
  }

  function handleCommandSelect(item: any) {
    closeCommandPalette();
    
    switch (item.type) {
      case 'document':
        goto(`/documents/${item.id}`);
        break;
      case 'notebook':
        goto(`/notebooks/${item.id}`);
        break;
      case 'team':
        goto(`/teams/${item.id}`);
        break;
      default:
        if (item.href) {
          goto(item.href);
        } else if (item.action) {
          item.action();
        }
    }
  }

  function getInitials(name: string): string {
    return name
      .split(' ')
      .map(word => word.charAt(0))
      .join('')
      .toUpperCase()
      .slice(0, 2);
  }

  function setTheme(theme: 'light' | 'dark' | 'system') {
    ui.update(state => ({ ...state, theme }));
    
    if (browser) {
      localStorage.setItem('kyozo-theme', theme);
      const root = document.documentElement;
      
      if (theme === 'system') {
        const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
        root.classList.toggle('dark', prefersDark);
      } else {
        root.classList.toggle('dark', theme === 'dark');
      }
    }
  }

  // Keyboard shortcuts
  function handleKeydown(event: KeyboardEvent) {
    if (browser && (event.metaKey || event.ctrlKey) && event.key === 'k') {
      event.preventDefault();
      openCommandPalette();
    }
  }

  // Quick actions for command palette
  const quickActions = [
    {
      id: 'new-document',
      title: 'New Document',
      description: 'Create a new document',
      icon: FileText,
      action: () => goto('/documents/new')
    },
    {
      id: 'new-notebook',
      title: 'New Notebook',
      description: 'Create a new notebook',
      icon: BookOpen,
      action: () => goto('/notebooks/new')
    },
    {
      id: 'new-workspace',
      title: 'New Workspace',
      description: 'Create a new workspace',
      icon: Building,
      action: () => goto('/workspaces/new')
    },
    {
      id: 'settings',
      title: 'Settings',
      description: 'Open application settings',
      icon: Settings,
      href: '/settings'
    }
  ];
</script>

<svelte:window onkeydown={handleKeydown} />

<header class="flex items-center justify-between px-4 py-3 bg-background border-b border-border">
  <!-- Left Section -->
  <div class="flex items-center space-x-4">
    <!-- Mobile Menu Button -->
    {#if isMobile}
      <Button 
        variant="ghost" 
        size="sm"
        onclick={toggleMobileMenu}
      >
        <Menu class="h-5 w-5" />
      </Button>
    {:else}
      <!-- Desktop Sidebar Toggle -->
      <Button 
        variant="ghost" 
        size="sm"
        onclick={toggleSidebar}
      >
        <Menu class="h-5 w-5" />
      </Button>
    {/if}

    <!-- Page Title -->
    <div class="flex items-center space-x-2">
      {#if title}
        <h1 class="text-lg font-semibold text-foreground">{title}</h1>
      {/if}
      {#if subtitle}
        <span class="text-sm text-muted-foreground">/ {subtitle}</span>
      {/if}
    </div>

    <!-- Breadcrumbs for larger screens -->
    {#if !isMobile && $currentTeam}
      <div class="hidden lg:flex items-center space-x-2 text-sm text-muted-foreground">
        <span>{$currentTeam.name}</span>
        {#if $currentWorkspace}
          <span>/</span>
          <span>{$currentWorkspace.name}</span>
        {/if}
      </div>
    {/if}
  </div>

  <!-- Center Section - Search -->
  <div class="flex-1 max-w-md mx-8 hidden md:block">
    <div class="relative">
      <Button
        variant="outline"
        class="w-full justify-start text-muted-foreground"
        onclick={openCommandPalette}
      >
        <Search class="mr-2 h-4 w-4" />
        Search everything...
        <div class="ml-auto flex items-center space-x-1">
          <kbd class="pointer-events-none inline-flex h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-mono text-[10px] font-medium text-muted-foreground opacity-100">
            <span class="text-xs">{browser && navigator.platform.includes('Mac') ? '⌘' : 'Ctrl'}</span>K
          </kbd>
        </div>
      </Button>
    </div>
  </div>

  <!-- Right Section -->
  <div class="flex items-center space-x-2">
    <!-- Mobile Search Button -->
    {#if isMobile}
      <Button 
        variant="ghost" 
        size="sm"
        onclick={openCommandPalette}
      >
        <Search class="h-5 w-5" />
      </Button>
    {/if}

    <!-- Quick Actions -->
    <DropdownMenu>
      <DropdownMenuTrigger>
        <Button variant="ghost" size="sm">
          <Plus class="h-5 w-5" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" class="w-48">
        <DropdownMenuLabel>Create New</DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuItem onclick={() => goto('/documents/new')}>
          <FileText class="mr-2 h-4 w-4" />
          Document
        </DropdownMenuItem>
        <DropdownMenuItem onclick={() => goto('/notebooks/new')}>
          <BookOpen class="mr-2 h-4 w-4" />
          Notebook
        </DropdownMenuItem>
        <DropdownMenuItem onclick={() => goto('/workspaces/new')}>
          <Building class="mr-2 h-4 w-4" />
          Workspace
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>

    <!-- Theme Switcher -->
    <DropdownMenu>
      <DropdownMenuTrigger>
        <Button variant="ghost" size="sm">
          {#if $ui.theme === 'light'}
            <Sun class="h-5 w-5" />
          {:else if $ui.theme === 'dark'}
            <Moon class="h-5 w-5" />
          {:else}
            <Monitor class="h-5 w-5" />
          {/if}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onclick={() => setTheme('light')}>
          <Sun class="mr-2 h-4 w-4" />
          Light
        </DropdownMenuItem>
        <DropdownMenuItem onclick={() => setTheme('dark')}>
          <Moon class="mr-2 h-4 w-4" />
          Dark
        </DropdownMenuItem>
        <DropdownMenuItem onclick={() => setTheme('system')}>
          <Monitor class="mr-2 h-4 w-4" />
          System
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>

    <!-- Notifications -->
    <Button 
      variant="ghost" 
      size="sm"
      class="relative"
      onclick={() => goto('/notifications')}
    >
      <Bell class="h-5 w-5" />
      {#if $notifications.unreadCount > 0}
        <Badge 
          variant="destructive" 
          class="absolute -top-1 -right-1 h-5 w-5 p-0 text-xs"
        >
          {$notifications.unreadCount > 99 ? '99+' : $notifications.unreadCount}
        </Badge>
      {/if}
    </Button>

    <!-- User Menu -->
    {#if $auth.user}
      <DropdownMenu>
        <DropdownMenuTrigger>
          <Button variant="ghost" class="relative h-8 w-8 rounded-full">
            <Avatar class="h-8 w-8">
              <AvatarImage src={$auth.user.avatar} alt={$auth.user.name} />
              <AvatarFallback>
                {getInitials($auth.user.name)}
              </AvatarFallback>
            </Avatar>
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent class="w-56" align="end">
          <DropdownMenuLabel class="font-normal">
            <div class="flex flex-col space-y-1">
              <p class="text-sm font-medium leading-none">{$auth.user.name}</p>
              <p class="text-xs leading-none text-muted-foreground">
                {$auth.user.email}
              </p>
            </div>
          </DropdownMenuLabel>
          <DropdownMenuSeparator />
          <DropdownMenuItem onclick={() => goto('/profile')}>
            <Settings class="mr-2 h-4 w-4" />
            Profile
          </DropdownMenuItem>
          <DropdownMenuItem onclick={() => goto('/settings')}>
            <Settings class="mr-2 h-4 w-4" />
            Settings
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem class="text-destructive">
            <LogOut class="mr-2 h-4 w-4" />
            Log out
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    {/if}
  </div>
</header>

<!-- Command Palette -->
<CommandDialog bind:open={showCommandPalette}>
  <CommandInput 
    placeholder="Search for documents, notebooks, teams..." 
    bind:value={searchQuery}
    oninput={(e) => handleSearch(e.target.value)}
  />
  <CommandList>
    <CommandEmpty>No results found.</CommandEmpty>
    
    {#if !searchQuery.trim()}
      <CommandGroup heading="Quick Actions">
        {#each quickActions as action}
          <CommandItem onSelect={() => handleCommandSelect(action)}>
            <svelte:component this={action.icon} class="mr-2 h-4 w-4" />
            <div>
              <div class="font-medium">{action.title}</div>
              <div class="text-xs text-muted-foreground">{action.description}</div>
            </div>
          </CommandItem>
        {/each}
      </CommandGroup>
    {:else}
      <CommandGroup heading="Search Results">
        {#each searchResults as result}
          <CommandItem onSelect={() => handleCommandSelect(result)}>
            <svelte:component this={result.icon} class="mr-2 h-4 w-4" />
            <div>
              <div class="font-medium">{result.title}</div>
              <div class="text-xs text-muted-foreground">{result.description}</div>
            </div>
          </CommandItem>
        {/each}
      </CommandGroup>
    {/if}
  </CommandList>
</CommandDialog>