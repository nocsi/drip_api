<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '../../utils';
  import {
    currentTeam,
    currentWorkspace,
    auth,
    apiService,
    workspaces,
    documents,
    notebooks
  } from '../../stores/index';
  import { Button } from '../../ui/button';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../../ui/card';
  import { Avatar, AvatarFallback, AvatarImage } from '../../ui/avatar';
  import { Badge } from '../../ui/badge';
  import { Progress } from '../../ui/progress';
  import { Separator } from '../../ui/separator';
  import {
    Plus,
    Users,
    FolderOpen,
    FileText,
    BookOpen,
    Activity,
    TrendingUp,
    Clock,
    Calendar,
    User,
    PlayCircle,
    CheckCircle,
    XCircle,
    Archive,
    Star,
    Eye,
    Edit,
    Zap,
    Database,
    GitBranch,
    Building,
    Code2,
    Timer,
    Loader2,
    Settings
  } from '@lucide/svelte';

  let loading = $state(false);
  let dashboardStats = $state({
    total_workspaces: 0,
    active_workspaces: 0,
    total_documents: 0,
    total_notebooks: 0,
    total_tasks: 0,
    completed_tasks: 0,
    total_executions: 0,
    successful_executions: 0,
    avg_execution_time_ms: 0,
    storage_used_bytes: 0
  });
  let recentActivity = $state<any[]>([]);
  let quickStats = $state({
    workspaces: 0,
    documents: 0,
    notebooks: 0,
    executionsToday: 0
  });

  const hasTeam = $derived(!!$currentTeam);
  const hasWorkspace = $derived(!!$currentWorkspace);
  const workspacesData = $derived($workspaces.data || []);
  const documentsData = $derived($documents.data || []);
  const notebooksData = $derived($notebooks.data || []);

  // Calculate quick stats from loaded data
  $effect(() => {
    quickStats = {
      workspaces: workspacesData.length,
      documents: documentsData.length,
      notebooks: notebooksData.length,
      executionsToday: notebooksData.filter(n =>
        n.last_execution_at &&
        new Date(n.last_execution_at).toDateString() === new Date().toDateString()
      ).length
    };
  });

  onMount(async () => {
    if ($apiService && hasTeam) {
      await loadDashboardData();
    }
  });

  async function loadDashboardData() {
    if (!$apiService) return;

    try {
      loading = true;

      // Load dashboard stats if API exists
      try {
        const statsResponse = await $apiService.getDashboardStats('week');
        dashboardStats = statsResponse.data.stats;
      } catch (error) {
        console.log('Dashboard stats not available:', error);
      }

      // Load recent activity if API exists
      try {
        const activityResponse = await $apiService.getDashboardActivity();
        recentActivity = activityResponse.data.activities.slice(0, 10);
      } catch (error) {
        console.log('Recent activity not available:', error);
      }

    } catch (error) {
      console.error('Failed to load dashboard data:', error);
    } finally {
      loading = false;
    }
  }

  function formatBytes(bytes: number): string {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

  function formatDuration(ms: number): string {
    if (ms < 1000) return `${ms}ms`;
    if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`;
    return `${(ms / 60000).toFixed(1)}m`;
  }

  function formatDate(dateString: string): string {
    return new Date(dateString).toLocaleDateString();
  }

  function getInitials(name: string): string {
    return name
      .split(' ')
      .map(word => word.charAt(0))
      .join('')
      .toUpperCase()
      .slice(0, 2);
  }

  function getActivityIcon(type: string) {
    switch (type) {
      case 'create':
        return Plus;
      case 'update':
        return Edit;
      case 'execute':
        return PlayCircle;
      case 'delete':
        return Archive;
      default:
        return Activity;
    }
  }

  function getResourceIcon(resourceType: string) {
    switch (resourceType) {
      case 'workspace':
        return FolderOpen;
      case 'document':
        return FileText;
      case 'notebook':
        return BookOpen;
      case 'task':
        return Code2;
      default:
        return Activity;
    }
  }

  function getSuccessRate(): number {
    if (dashboardStats.total_executions === 0) return 0;
    return Math.round((dashboardStats.successful_executions / dashboardStats.total_executions) * 100);
  }

  function getTaskCompletionRate(): number {
    if (dashboardStats.total_tasks === 0) return 0;
    return Math.round((dashboardStats.completed_tasks / dashboardStats.total_tasks) * 100);
  }
</script>

<div class="space-y-6">
  <!-- Welcome Header -->
  <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
    <div>
      <h1 class="text-3xl font-bold text-foreground">
        Welcome back{#if $auth.user}, {$auth.user.name.split(' ')[0]}{/if}!
      </h1>
      <p class="text-muted-foreground">
        {#if hasTeam && hasWorkspace}
          Here's what's happening in {$currentWorkspace.name}
        {:else if hasTeam}
          Here's an overview of your team's activity
        {:else}
          Get started by selecting or creating a team
        {/if}
      </p>
    </div>

    {#if hasTeam}
      <div class="flex items-center gap-2">
        <Button variant="outline" onclick={() => goto('/documents/new')}>
          <FileText class="mr-2 h-4 w-4" />
          New Document
        </Button>
        <Button onclick={() => goto('/notebooks/new')}>
          <BookOpen class="mr-2 h-4 w-4" />
          New Notebook
        </Button>
      </div>
    {/if}
  </div>

  {#if !hasTeam}
    <!-- No Team Selected -->
    <div class="grid gap-6 md:grid-cols-2">
      <Card>
        <CardContent class="flex flex-col items-center justify-center py-12">
          <Building class="h-12 w-12 text-muted-foreground mb-4" />
          <h3 class="text-lg font-semibold mb-2">No Team Selected</h3>
          <p class="text-muted-foreground text-center mb-4">
            Create or join a team to start collaborating
          </p>
          <Button onclick={() => goto('/teams')}>
            <Users class="mr-2 h-4 w-4" />
            Manage Teams
          </Button>
        </CardContent>
      </Card>

      <Card>
        <CardContent class="flex flex-col items-center justify-center py-12">
          <User class="h-12 w-12 text-muted-foreground mb-4" />
          <h3 class="text-lg font-semibold mb-2">Getting Started</h3>
          <p class="text-muted-foreground text-center mb-4">
            Set up your profile and preferences
          </p>
          <Button variant="outline" onclick={() => goto('/settings')}>
            <Settings class="mr-2 h-4 w-4" />
            Go to Settings
          </Button>
        </CardContent>
      </Card>
    </div>
  {:else}
    <!-- Main Dashboard Content -->

    <!-- Quick Stats -->
    <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
      <Card>
        <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle class="text-sm font-medium">Workspaces</CardTitle>
          <FolderOpen class="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div class="text-2xl font-bold">{quickStats.workspaces}</div>
          <p class="text-xs text-muted-foreground">
            {dashboardStats.active_workspaces} active
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle class="text-sm font-medium">Documents</CardTitle>
          <FileText class="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div class="text-2xl font-bold">{quickStats.documents}</div>
          <p class="text-xs text-muted-foreground">
            Total documents
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle class="text-sm font-medium">Notebooks</CardTitle>
          <BookOpen class="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div class="text-2xl font-bold">{quickStats.notebooks}</div>
          <p class="text-xs text-muted-foreground">
            {quickStats.executionsToday} ran today
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle class="text-sm font-medium">Executions</CardTitle>
          <Zap class="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div class="text-2xl font-bold">{dashboardStats.total_executions}</div>
          <p class="text-xs text-muted-foreground">
            {getSuccessRate()}% success rate
          </p>
        </CardContent>
      </Card>
    </div>

    <!-- Main Content Grid -->
    <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
      <!-- Current Team/Workspace Info -->
      <Card>
        <CardHeader>
          <CardTitle class="flex items-center space-x-2">
            <Building class="h-5 w-5" />
            <span>Current Context</span>
          </CardTitle>
        </CardHeader>
        <CardContent class="space-y-4">
          {#if $currentTeam}
            <div class="flex items-center space-x-3">
              <Avatar class="h-8 w-8">
                <AvatarFallback class="bg-primary text-primary-foreground">
                  {getInitials($currentTeam.name)}
                </AvatarFallback>
              </Avatar>
              <div>
                <p class="font-medium">{$currentTeam.name}</p>
                <p class="text-sm text-muted-foreground">Team</p>
              </div>
            </div>
          {/if}

          {#if $currentWorkspace}
            <div class="flex items-center space-x-3">
              <Avatar class="h-8 w-8">
                <AvatarFallback class="bg-secondary text-secondary-foreground">
                  {getInitials($currentWorkspace.name)}
                </AvatarFallback>
              </Avatar>
              <div>
                <p class="font-medium">{$currentWorkspace.name}</p>
                <p class="text-sm text-muted-foreground">Workspace</p>
              </div>
            </div>
          {:else}
            <div class="text-center py-4">
              <p class="text-muted-foreground mb-2">No workspace selected</p>
              <Button size="sm" onclick={() => goto('/workspaces')}>
                Select Workspace
              </Button>
            </div>
          {/if}
        </CardContent>
      </Card>

      <!-- Performance Stats -->
      <Card>
        <CardHeader>
          <CardTitle class="flex items-center space-x-2">
            <TrendingUp class="h-5 w-5" />
            <span>Performance</span>
          </CardTitle>
        </CardHeader>
        <CardContent class="space-y-4">
          <div class="space-y-2">
            <div class="flex items-center justify-between text-sm">
              <span>Task Completion</span>
              <span>{dashboardStats.completed_tasks}/{dashboardStats.total_tasks}</span>
            </div>
            <Progress value={getTaskCompletionRate()} class="h-2" />
          </div>

          <div class="space-y-2">
            <div class="flex items-center justify-between text-sm">
              <span>Execution Success</span>
              <span>{getSuccessRate()}%</span>
            </div>
            <Progress value={getSuccessRate()} class="h-2" />
          </div>

          <div class="flex items-center justify-between text-sm">
            <span>Avg Execution Time</span>
            <span>{formatDuration(dashboardStats.avg_execution_time_ms)}</span>
          </div>

          <div class="flex items-center justify-between text-sm">
            <span>Storage Used</span>
            <span>{formatBytes(dashboardStats.storage_used_bytes)}</span>
          </div>
        </CardContent>
      </Card>

      <!-- Recent Activity -->
      <Card>
        <CardHeader>
          <CardTitle class="flex items-center space-x-2">
            <Activity class="h-5 w-5" />
            <span>Recent Activity</span>
          </CardTitle>
        </CardHeader>
        <CardContent>
          {#if loading}
            <div class="flex items-center justify-center py-4">
              <Loader2 class="h-4 w-4 animate-spin" />
            </div>
          {:else if recentActivity.length > 0}
            <div class="space-y-3">
              {#each recentActivity.slice(0, 5) as activity}
                <div class="flex items-start space-x-3">
                  <div class="flex h-6 w-6 items-center justify-center rounded-full bg-primary/10">
                    <svelte:component this={getActivityIcon(activity.type)} class="h-3 w-3 text-primary" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm">
                      <span class="font-medium">{activity.user_name}</span>
                      {activity.description}
                    </p>
                    <p class="text-xs text-muted-foreground">
                      {formatDate(activity.created_at)}
                    </p>
                  </div>
                  <svelte:component this={getResourceIcon(activity.resource_type)} class="h-4 w-4 text-muted-foreground" />
                </div>
              {/each}
            </div>
          {:else}
            <div class="text-center py-4">
              <Activity class="h-8 w-8 text-muted-foreground mx-auto mb-2" />
              <p class="text-sm text-muted-foreground">No recent activity</p>
            </div>
          {/if}
        </CardContent>
      </Card>
    </div>

    <!-- Recent Items -->
    {#if hasWorkspace}
      <div class="grid gap-6 md:grid-cols-2">
        <!-- Recent Documents -->
        <Card>
          <CardHeader class="flex flex-row items-center justify-between">
            <CardTitle class="flex items-center space-x-2">
              <FileText class="h-5 w-5" />
              <span>Recent Documents</span>
            </CardTitle>
            <Button variant="ghost" size="sm" onclick={() => goto('/documents')}>
              View All
            </Button>
          </CardHeader>
          <CardContent>
            {#if documentsData.length > 0}
              <div class="space-y-3">
                {#each documentsData.slice(0, 5) as document}
                  <div class="flex items-center justify-between">
                    <div class="flex items-center space-x-3 min-w-0">
                      <FileText class="h-4 w-4 text-muted-foreground" />
                      <div class="min-w-0">
                        <p class="font-medium truncate">{document.title}</p>
                        <p class="text-xs text-muted-foreground">
                          Updated {formatDate(document.updated_at)}
                        </p>
                      </div>
                    </div>
                    <div class="flex items-center space-x-1">
                      <Button variant="ghost" size="sm" onclick={() => goto(`/documents/${document.id}`)}>
                        <Eye class="h-4 w-4" />
                      </Button>
                      <Button variant="ghost" size="sm" onclick={() => goto(`/documents/${document.id}/edit`)}>
                        <Edit class="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                {/each}
              </div>
            {:else}
              <div class="text-center py-4">
                <FileText class="h-8 w-8 text-muted-foreground mx-auto mb-2" />
                <p class="text-sm text-muted-foreground mb-2">No documents yet</p>
                <Button size="sm" onclick={() => goto('/documents/new')}>
                  Create Document
                </Button>
              </div>
            {/if}
          </CardContent>
        </Card>

        <!-- Recent Notebooks -->
        <Card>
          <CardHeader class="flex flex-row items-center justify-between">
            <CardTitle class="flex items-center space-x-2">
              <BookOpen class="h-5 w-5" />
              <span>Recent Notebooks</span>
            </CardTitle>
            <Button variant="ghost" size="sm" onclick={() => goto('/notebooks')}>
              View All
            </Button>
          </CardHeader>
          <CardContent>
            {#if notebooksData.length > 0}
              <div class="space-y-3">
                {#each notebooksData.slice(0, 5) as notebook}
                  <div class="flex items-center justify-between">
                    <div class="flex items-center space-x-3 min-w-0">
                      <BookOpen class="h-4 w-4 text-muted-foreground" />
                      <div class="min-w-0">
                        <p class="font-medium truncate">{notebook.title}</p>
                        <div class="flex items-center space-x-2">
                          <Badge variant="outline" class="text-xs">
                            {notebook.status}
                          </Badge>
                          <span class="text-xs text-muted-foreground">
                            {notebook.language}
                          </span>
                        </div>
                      </div>
                    </div>
                    <div class="flex items-center space-x-1">
                      <Button variant="ghost" size="sm" onclick={() => goto(`/notebooks/${notebook.id}`)}>
                        <Eye class="h-4 w-4" />
                      </Button>
                      <Button variant="ghost" size="sm" onclick={() => goto(`/notebooks/${notebook.id}/edit`)}>
                        <Edit class="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                {/each}
              </div>
            {:else}
              <div class="text-center py-4">
                <BookOpen class="h-8 w-8 text-muted-foreground mx-auto mb-2" />
                <p class="text-sm text-muted-foreground mb-2">No notebooks yet</p>
                <Button size="sm" onclick={() => goto('/notebooks/new')}>
                  Create Notebook
                </Button>
              </div>
            {/if}
          </CardContent>
        </Card>
      </div>
    {/if}
  {/if}
</div>
