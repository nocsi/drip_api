<script lang="ts">
  import { onMount, createEventDispatcher } from 'svelte';
  import type { LiveSvelteProps } from '../liveSvelte';
  import { Card, CardContent, CardHeader, CardTitle } from '../ui/card';
  import { Button } from '../ui/button';
  import { Badge } from '../ui/badge';
  import { Progress } from '../ui/progress';
  import { Avatar, AvatarFallback, AvatarImage } from '../ui/avatar';
  import {
    FileText,
    BookOpen,
    Users,
    FolderOpen,
    Plus,
    TrendingUp,
    Activity,
    Clock,
    Calendar,
    Target,
    Zap,
    ArrowRight,
    MoreHorizontal,
    CheckCircle,
    AlertCircle,
    PlayCircle,
    Eye,
    Edit,
    Share
  } from '@lucide/svelte';

  // Props from LiveView
  interface Props {
    currentUser: any;
    currentTeam: any;
    stats?: {
      totalWorkspaces?: number;
      totalDocuments?: number;
      totalNotebooks?: number;
      activeCollaborators?: number;
      recentActivity?: any[];
      weeklyStats?: any;
      monthlyGrowth?: any;
    };
    recentWorkspaces?: any[];
    recentDocuments?: any[];
    recentNotebooks?: any[];
    upcomingTasks?: any[];
    teamActivity?: any[];
    quickActions?: string[];
    apiToken?: string;
    csrfToken?: string;
    apiBaseUrl?: string;
  }

  let {
    currentUser,
    currentTeam,
    stats = {
      totalWorkspaces: 0,
      totalDocuments: 0,
      totalNotebooks: 0,
      activeCollaborators: 0,
      recentActivity: [],
      weeklyStats: null,
      monthlyGrowth: null
    },
    recentWorkspaces = [],
    recentDocuments = [],
    recentNotebooks = [],
    upcomingTasks = [],
    teamActivity = [],
    quickActions = ['create_workspace', 'create_document', 'create_notebook'],
    apiToken = '',
    csrfToken = '',
    apiBaseUrl = '/api/v1'
  }: Props = $props();

  // Component state
  let loading = $state(false);
  let error = $state(null);
  let selectedPeriod = $state('week');

  const dispatch = createEventDispatcher();

  // API client
  const apiClient = {
    async request(endpoint: string, options: RequestInit = {}) {
      const url = `${apiBaseUrl}${endpoint}`;
      const headers = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiToken}`,
        'X-CSRF-Token': csrfToken,
        'X-Team-ID': currentTeam?.id || '',
        ...options.headers
      };

      const response = await fetch(url, {
        ...options,
        headers
      });

      if (!response.ok) {
        throw new Error(`API Error: ${response.status} ${response.statusText}`);
      }

      return response.json();
    },

    async getDashboardStats(period = 'week') {
      return this.request(`/dashboard/stats?period=${period}`);
    },

    async getRecentActivity() {
      return this.request('/dashboard/activity');
    }
  };

  // Event handlers
  function handleQuickAction(action: string) {
    switch (action) {
      case 'create_workspace':
        dispatch('createWorkspace');
        break;
      case 'create_document':
        dispatch('createDocument');
        break;
      case 'create_notebook':
        dispatch('createNotebook');
        break;
      case 'invite_member':
        dispatch('inviteMember');
        break;
      default:
        dispatch('quickAction', { action });
    }
  }

  function handleViewAll(type: string) {
    dispatch('viewAll', { type });
  }

  function handleItemClick(type: string, item: any) {
    dispatch('itemClick', { type, item });
  }

  async function refreshStats() {
    loading = true;
    try {
      const response = await apiClient.getDashboardStats(selectedPeriod);
      stats = response.data || stats;
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  function formatDate(dateString: string): string {
    if (!dateString) return 'Unknown';
    const date = new Date(dateString);
    const now = new Date();
    const diffTime = Math.abs(now.getTime() - date.getTime());
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    if (diffDays === 1) return 'Yesterday';
    if (diffDays < 7) return `${diffDays} days ago`;
    if (diffDays < 30) return `${Math.ceil(diffDays / 7)} weeks ago`;
    return date.toLocaleDateString();
  }

  function getActivityIcon(activityType: string) {
    switch (activityType) {
      case 'document_created':
      case 'document_updated':
        return FileText;
      case 'notebook_created':
      case 'notebook_executed':
        return BookOpen;
      case 'workspace_created':
        return FolderOpen;
      case 'user_joined':
        return Users;
      default:
        return Activity;
    }
  }

  function getActivityColor(activityType: string): string {
    switch (activityType) {
      case 'document_created':
      case 'document_updated':
        return 'text-blue-600';
      case 'notebook_created':
      case 'notebook_executed':
        return 'text-purple-600';
      case 'workspace_created':
        return 'text-green-600';
      case 'user_joined':
        return 'text-orange-600';
      default:
        return 'text-gray-600';
    }
  }

  function getGrowthPercentage(current: number, previous: number): number {
    if (previous === 0) return current > 0 ? 100 : 0;
    return Math.round(((current - previous) / previous) * 100);
  }

  function getUserInitials(name: string): string {
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
  }

  onMount(() => {
    refreshStats();
  });

  // Watch for period changes
  $effect(() => {
    refreshStats();
  });
</script>

<div class="p-6 space-y-6 bg-background min-h-screen">
  <!-- Header -->
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-3xl font-bold text-foreground">
        Welcome back, {currentUser?.name || 'User'}!
      </h1>
      <p class="text-muted-foreground mt-1">
        Here's what's happening with your projects today.
      </p>
    </div>
    
    <div class="flex items-center space-x-2">
      <select
        bind:value={selectedPeriod}
        class="px-3 py-2 border rounded-md text-sm"
      >
        <option value="day">Today</option>
        <option value="week">This Week</option>
        <option value="month">This Month</option>
        <option value="quarter">This Quarter</option>
      </select>
    </div>
  </div>

  <!-- Quick Actions -->
  <Card>
    <CardHeader>
      <CardTitle class="flex items-center">
        <Zap class="w-5 h-5 mr-2" />
        Quick Actions
      </CardTitle>
    </CardHeader>
    <CardContent>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Button
          variant="outline"
          class="h-24 flex-col space-y-2"
          onclick={() => handleQuickAction('create_workspace')}
        >
          <FolderOpen class="w-8 h-8 text-primary" />
          <span class="text-sm">New Workspace</span>
        </Button>
        <Button
          variant="outline"
          class="h-24 flex-col space-y-2"
          onclick={() => handleQuickAction('create_document')}
        >
          <FileText class="w-8 h-8 text-primary" />
          <span class="text-sm">New Document</span>
        </Button>
        <Button
          variant="outline"
          class="h-24 flex-col space-y-2"
          onclick={() => handleQuickAction('create_notebook')}
        >
          <BookOpen class="w-8 h-8 text-primary" />
          <span class="text-sm">New Notebook</span>
        </Button>
        <Button
          variant="outline"
          class="h-24 flex-col space-y-2"
          onclick={() => handleQuickAction('invite_member')}
        >
          <Users class="w-8 h-8 text-primary" />
          <span class="text-sm">Invite Member</span>
        </Button>
      </div>
    </CardContent>
  </Card>

  <!-- Stats Overview -->
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
    <!-- Total Workspaces -->
    <Card>
      <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle class="text-sm font-medium">Workspaces</CardTitle>
        <FolderOpen class="h-4 w-4 text-muted-foreground" />
      </CardHeader>
      <CardContent>
        <div class="text-2xl font-bold">{stats.totalWorkspaces || 0}</div>
        {#if stats.weeklyStats?.workspaces}
          <p class="text-xs text-muted-foreground">
            {#if getGrowthPercentage(stats.totalWorkspaces, stats.weeklyStats.workspaces) > 0}
              <TrendingUp class="w-3 h-3 inline mr-1 text-green-600" />
              +{getGrowthPercentage(stats.totalWorkspaces, stats.weeklyStats.workspaces)}% from last week
            {:else}
              No change from last week
            {/if}
          </p>
        {/if}
      </CardContent>
    </Card>

    <!-- Total Documents -->
    <Card>
      <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle class="text-sm font-medium">Documents</CardTitle>
        <FileText class="h-4 w-4 text-muted-foreground" />
      </CardHeader>
      <CardContent>
        <div class="text-2xl font-bold">{stats.totalDocuments || 0}</div>
        {#if stats.weeklyStats?.documents}
          <p class="text-xs text-muted-foreground">
            {#if getGrowthPercentage(stats.totalDocuments, stats.weeklyStats.documents) > 0}
              <TrendingUp class="w-3 h-3 inline mr-1 text-green-600" />
              +{getGrowthPercentage(stats.totalDocuments, stats.weeklyStats.documents)}% from last week
            {:else}
              No change from last week
            {/if}
          </p>
        {/if}
      </CardContent>
    </Card>

    <!-- Total Notebooks -->
    <Card>
      <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle class="text-sm font-medium">Notebooks</CardTitle>
        <BookOpen class="h-4 w-4 text-muted-foreground" />
      </CardHeader>
      <CardContent>
        <div class="text-2xl font-bold">{stats.totalNotebooks || 0}</div>
        {#if stats.weeklyStats?.notebooks}
          <p class="text-xs text-muted-foreground">
            {#if getGrowthPercentage(stats.totalNotebooks, stats.weeklyStats.notebooks) > 0}
              <TrendingUp class="w-3 h-3 inline mr-1 text-green-600" />
              +{getGrowthPercentage(stats.totalNotebooks, stats.weeklyStats.notebooks)}% from last week
            {:else}
              No change from last week
            {/if}
          </p>
        {/if}
      </CardContent>
    </Card>

    <!-- Active Collaborators -->
    <Card>
      <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle class="text-sm font-medium">Active Collaborators</CardTitle>
        <Users class="h-4 w-4 text-muted-foreground" />
      </CardHeader>
      <CardContent>
        <div class="text-2xl font-bold">{stats.activeCollaborators || 0}</div>
        <p class="text-xs text-muted-foreground">
          Across all your projects
        </p>
      </CardContent>
    </Card>
  </div>

  <!-- Main Content Grid -->
  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <!-- Recent Activity -->
    <div class="lg:col-span-2">
      <Card class="h-full">
        <CardHeader class="flex flex-row items-center justify-between">
          <CardTitle class="flex items-center">
            <Activity class="w-5 h-5 mr-2" />
            Recent Activity
          </CardTitle>
          <Button variant="ghost" size="sm" onclick={() => handleViewAll('activity')}>
            <MoreHorizontal class="w-4 h-4" />
          </Button>
        </CardHeader>
        <CardContent>
          <div class="space-y-4">
            {#if teamActivity.length === 0}
              <div class="text-center py-8 text-muted-foreground">
                <Activity class="w-12 h-12 mx-auto mb-4 text-muted-foreground/50" />
                <p>No recent activity</p>
              </div>
            {:else}
              {#each teamActivity.slice(0, 8) as activity}
                {@const IconComponent = getActivityIcon(activity.type)}
                <div class="flex items-start space-x-3">
                  <div class="flex-shrink-0">
                    <Avatar class="h-8 w-8">
                      <AvatarImage src={activity.user?.avatar} alt={activity.user?.name} />
                      <AvatarFallback class="text-xs">
                        {getUserInitials(activity.user?.name || 'U')}
                      </AvatarFallback>
                    </Avatar>
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center space-x-2">
                      <IconComponent class="w-4 h-4 {getActivityColor(activity.type)}" />
                      <span class="text-sm font-medium">{activity.user?.name}</span>
                      <span class="text-sm text-muted-foreground">{activity.action}</span>
                      {#if activity.target}
                        <span class="text-sm font-medium truncate">{activity.target.name}</span>
                      {/if}
                    </div>
                    <p class="text-xs text-muted-foreground mt-1">
                      {formatDate(activity.created_at)}
                    </p>
                  </div>
                </div>
              {/each}
            {/if}
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- Sidebar Content -->
    <div class="space-y-6">
      <!-- Upcoming Tasks -->
      <Card>
        <CardHeader>
          <CardTitle class="flex items-center">
            <Target class="w-5 h-5 mr-2" />
            Upcoming Tasks
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div class="space-y-3">
            {#if upcomingTasks.length === 0}
              <div class="text-center py-4 text-muted-foreground">
                <CheckCircle class="w-8 h-8 mx-auto mb-2 text-muted-foreground/50" />
                <p class="text-sm">All caught up!</p>
              </div>
            {:else}
              {#each upcomingTasks.slice(0, 5) as task}
                <div class="flex items-center space-x-3">
                  <div class="flex-shrink-0">
                    {#if task.priority === 'high'}
                      <AlertCircle class="w-4 h-4 text-red-500" />
                    {:else if task.status === 'completed'}
                      <CheckCircle class="w-4 h-4 text-green-500" />
                    {:else}
                      <Clock class="w-4 h-4 text-blue-500" />
                    {/if}
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium truncate">{task.title}</p>
                    <p class="text-xs text-muted-foreground">
                      Due {formatDate(task.due_date)}
                    </p>
                  </div>
                </div>
              {/each}
            {/if}
          </div>
        </CardContent>
      </Card>

      <!-- Team Progress -->
      {#if currentTeam}
        <Card>
          <CardHeader>
            <CardTitle class="flex items-center">
              <Users class="w-5 h-5 mr-2" />
              Team Progress
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div class="space-y-4">
              <div>
                <div class="flex justify-between text-sm mb-2">
                  <span>Monthly Goals</span>
                  <span>75%</span>
                </div>
                <Progress value={75} class="h-2" />
              </div>
              <div>
                <div class="flex justify-between text-sm mb-2">
                  <span>Project Completion</span>
                  <span>60%</span>
                </div>
                <Progress value={60} class="h-2" />
              </div>
              <div>
                <div class="flex justify-between text-sm mb-2">
                  <span>Documentation Coverage</span>
                  <span>85%</span>
                </div>
                <Progress value={85} class="h-2" />
              </div>
            </div>
          </CardContent>
        </Card>
      {/if}
    </div>
  </div>

  <!-- Recent Items -->
  <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
    <!-- Recent Workspaces -->
    <Card>
      <CardHeader class="flex flex-row items-center justify-between">
        <CardTitle class="text-lg">Recent Workspaces</CardTitle>
        <Button variant="ghost" size="sm" onclick={() => handleViewAll('workspaces')}>
          <ArrowRight class="w-4 h-4" />
        </Button>
      </CardHeader>
      <CardContent>
        <div class="space-y-3">
          {#if recentWorkspaces.length === 0}
            <div class="text-center py-4 text-muted-foreground">
              <FolderOpen class="w-8 h-8 mx-auto mb-2 text-muted-foreground/50" />
              <p class="text-sm">No workspaces yet</p>
            </div>
          {:else}
            {#each recentWorkspaces.slice(0, 3) as workspace}
              <div 
                class="flex items-center space-x-3 p-2 rounded hover:bg-muted cursor-pointer"
                onclick={() => handleItemClick('workspace', workspace)}
              >
                <FolderOpen class="w-8 h-8 text-primary" />
                <div class="flex-1 min-w-0">
                  <p class="font-medium truncate">{workspace.name}</p>
                  <p class="text-sm text-muted-foreground">
                    {workspace.documents_count || 0} documents
                  </p>
                </div>
              </div>
            {/each}
          {/if}
        </div>
      </CardContent>
    </Card>

    <!-- Recent Documents -->
    <Card>
      <CardHeader class="flex flex-row items-center justify-between">
        <CardTitle class="text-lg">Recent Documents</CardTitle>
        <Button variant="ghost" size="sm" onclick={() => handleViewAll('documents')}>
          <ArrowRight class="w-4 h-4" />
        </Button>
      </CardHeader>
      <CardContent>
        <div class="space-y-3">
          {#if recentDocuments.length === 0}
            <div class="text-center py-4 text-muted-foreground">
              <FileText class="w-8 h-8 mx-auto mb-2 text-muted-foreground/50" />
              <p class="text-sm">No documents yet</p>
            </div>
          {:else}
            {#each recentDocuments.slice(0, 3) as document}
              <div 
                class="flex items-center space-x-3 p-2 rounded hover:bg-muted cursor-pointer"
                onclick={() => handleItemClick('document', document)}
              >
                <FileText class="w-8 h-8 text-primary" />
                <div class="flex-1 min-w-0">
                  <p class="font-medium truncate">{document.title}</p>
                  <p class="text-sm text-muted-foreground">
                    {formatDate(document.updated_at)}
                  </p>
                </div>
              </div>
            {/each}
          {/if}
        </div>
      </CardContent>
    </Card>

    <!-- Recent Notebooks -->
    <Card>
      <CardHeader class="flex flex-row items-center justify-between">
        <CardTitle class="text-lg">Recent Notebooks</CardTitle>
        <Button variant="ghost" size="sm" onclick={() => handleViewAll('notebooks')}>
          <ArrowRight class="w-4 h-4" />
        </Button>
      </CardHeader>
      <CardContent>
        <div class="space-y-3">
          {#if recentNotebooks.length === 0}
            <div class="text-center py-4 text-muted-foreground">
              <BookOpen class="w-8 h-8 mx-auto mb-2 text-muted-foreground/50" />
              <p class="text-sm">No notebooks yet</p>
            </div>
          {:else}
            {#each recentNotebooks.slice(0, 3) as notebook}
              <div 
                class="flex items-center space-x-3 p-2 rounded hover:bg-muted cursor-pointer"
                onclick={() => handleItemClick('notebook', notebook)}
              >
                <BookOpen class="w-8 h-8 text-primary" />
                <div class="flex-1 min-w-0">
                  <p class="font-medium truncate">{notebook.title}</p>
                  <div class="flex items-center space-x-2">
                    <Badge 
                      variant="secondary" 
                      class="text-xs {notebook.status === 'running' ? 'bg-blue-100 text-blue-800' : notebook.status === 'completed' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}"
                    >
                      {notebook.status || 'idle'}
                    </Badge>
                    <span class="text-sm text-muted-foreground">
                      {formatDate(notebook.updated_at)}
                    </span>
                  </div>
                </div>
              </div>
            {/each}
          {/if}
        </div>
      </CardContent>
    </Card>
  </div>
</div>