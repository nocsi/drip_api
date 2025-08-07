<script lang="ts">
  import { onMount } from 'svelte';
  import type { LiveSvelteProps } from '../liveSvelte';
  import { Button } from '../ui/button';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
  import { Badge } from '../ui/badge';
  import { MoreHorizontal, Plus, FolderOpen, Archive, Trash2, Settings, Users } from '@lucide/svelte';
  import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '../ui/dropdown-menu';

  let { workspaces = [], teams = [], current_team = null, live } = $props<LiveSvelteProps<{
    workspaces: any[];
    teams: any[];
    current_team: any;
  }>>();

  let searchQuery = $state('');
  let filteredWorkspaces = $derived(workspaces.filter(workspace =>
    workspace.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    (workspace.description && workspace.description.toLowerCase().includes(searchQuery.toLowerCase()))
  ));

  function handleCreateWorkspace() {
    live.pushEvent('lv:push_patch', { to: '/workspaces/new' });
  }

  function handleViewWorkspace(workspaceId: string) {
    live.pushEvent('lv:push_patch', { to: `/workspaces/${workspaceId}/dashboard` });
  }

  function handleEditWorkspace(workspaceId: string) {
    live.pushEvent('lv:push_patch', { to: `/workspaces/${workspaceId}/edit` });
  }

  function handleDeleteWorkspace(workspaceId: string) {
    live.pushEvent('lv:push_patch', { to: `/workspaces/${workspaceId}/delete` });
  }

  function handleArchiveWorkspace(workspaceId: string) {
    live.pushEvent('archive_workspace', { id: workspaceId });
  }

  function handleDuplicateWorkspace(workspaceId: string) {
    live.pushEvent('duplicate_workspace', { id: workspaceId });
  }

  function formatDate(dateString: string) {
    if (!dateString) return 'Never';
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  }

  function getStorageBackendColor(backend: string) {
    switch (backend) {
      case 'hybrid': return 'bg-blue-100 text-blue-800';
      case 'git': return 'bg-green-100 text-green-800';
      case 's3': return 'bg-orange-100 text-orange-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  }

  function getStatusColor(status: string) {
    switch (status) {
      case 'active': return 'bg-green-100 text-green-800';
      case 'archived': return 'bg-yellow-100 text-yellow-800';
      case 'deleted': return 'bg-red-100 text-red-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  }
</script>

<div class="p-6 space-y-6">
  <!-- Header -->
  <div class="flex justify-between items-center">
    <div>
      <h1 class="text-3xl font-bold tracking-tight">Workspaces</h1>
      <p class="text-muted-foreground">
        {#if current_team}
          Manage workspaces for {current_team.name}
        {:else}
          Create and manage your collaborative workspaces
        {/if}
      </p>
    </div>
    
    <Button onclick={handleCreateWorkspace} disabled={!current_team}>
      <Plus class="w-4 h-4 mr-2" />
      New Workspace
    </Button>
  </div>

  <!-- Team Info -->
  {#if current_team}
    <Card>
      <CardHeader class="pb-3">
        <div class="flex items-center space-x-2">
          <Users class="w-5 h-5" />
          <CardTitle class="text-lg">{current_team.name}</CardTitle>
        </div>
      </CardHeader>
    </Card>
  {/if}

  <!-- Search -->
  <div class="relative">
    <input
      type="text"
      placeholder="Search workspaces..."
      bind:value={searchQuery}
      class="w-full px-4 py-2 border border-input rounded-md bg-background focus:outline-none focus:ring-2 focus:ring-ring"
    />
  </div>

  <!-- Empty State -->
  {#if !current_team}
    <Card>
      <CardContent class="flex flex-col items-center justify-center py-12">
        <Users class="w-12 h-12 text-muted-foreground mb-4" />
        <h3 class="text-lg font-semibold mb-2">No Team Selected</h3>
        <p class="text-muted-foreground text-center mb-4">
          You need to be part of a team to create and manage workspaces.
        </p>
        <Button variant="outline" onclick={() => live.pushEvent('lv:push_navigate', { to: '/teams' })}>
          Manage Teams
        </Button>
      </CardContent>
    </Card>
  {:else if filteredWorkspaces.length === 0}
    <Card>
      <CardContent class="flex flex-col items-center justify-center py-12">
        <FolderOpen class="w-12 h-12 text-muted-foreground mb-4" />
        <h3 class="text-lg font-semibold mb-2">
          {searchQuery ? 'No workspaces found' : 'No workspaces yet'}
        </h3>
        <p class="text-muted-foreground text-center mb-4">
          {searchQuery 
            ? `No workspaces match "${searchQuery}". Try a different search term.`
            : 'Create your first workspace to start collaborating with your team.'
          }
        </p>
        {#if !searchQuery}
          <Button onclick={handleCreateWorkspace}>
            <Plus class="w-4 h-4 mr-2" />
            Create Workspace
          </Button>
        {/if}
      </CardContent>
    </Card>
  {:else}
    <!-- Workspaces Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      {#each filteredWorkspaces as workspace (workspace.id)}
        <Card class="hover:shadow-md transition-shadow cursor-pointer">
          <CardHeader class="pb-3">
            <div class="flex justify-between items-start">
              <div class="flex-1 min-w-0">
                <CardTitle class="text-lg truncate" title={workspace.name}>
                  {workspace.name}
                </CardTitle>
                {#if workspace.description}
                  <CardDescription class="mt-1 line-clamp-2">
                    {workspace.description}
                  </CardDescription>
                {/if}
              </div>
              
              <DropdownMenu>
                <DropdownMenuTrigger asChild let:builder>
                  <Button builders={[builder]} variant="ghost" size="sm" class="ml-2">
                    <MoreHorizontal class="w-4 h-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem onclick={() => handleViewWorkspace(workspace.id)}>
                    <FolderOpen class="w-4 h-4 mr-2" />
                    Open
                  </DropdownMenuItem>
                  <DropdownMenuItem onclick={() => handleEditWorkspace(workspace.id)}>
                    <Settings class="w-4 h-4 mr-2" />
                    Edit
                  </DropdownMenuItem>
                  <DropdownMenuItem onclick={() => handleDuplicateWorkspace(workspace.id)}>
                    Duplicate
                  </DropdownMenuItem>
                  <DropdownMenuItem onclick={() => handleArchiveWorkspace(workspace.id)}>
                    <Archive class="w-4 h-4 mr-2" />
                    Archive
                  </DropdownMenuItem>
                  <DropdownMenuItem 
                    onclick={() => handleDeleteWorkspace(workspace.id)}
                    class="text-destructive focus:text-destructive"
                  >
                    <Trash2 class="w-4 h-4 mr-2" />
                    Delete
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          </CardHeader>
          
          <CardContent class="pt-0">
            <div class="space-y-3">
              <!-- Status and Storage Backend -->
              <div class="flex flex-wrap gap-2">
                <Badge variant="outline" class={getStatusColor(workspace.status)}>
                  {workspace.status}
                </Badge>
                <Badge variant="outline" class={getStorageBackendColor(workspace.storage_backend)}>
                  {workspace.storage_backend}
                </Badge>
              </div>

              <!-- Tags -->
              {#if workspace.tags && workspace.tags.length > 0}
                <div class="flex flex-wrap gap-1">
                  {#each workspace.tags.slice(0, 3) as tag}
                    <Badge variant="secondary" class="text-xs">
                      {tag}
                    </Badge>
                  {/each}
                  {#if workspace.tags.length > 3}
                    <Badge variant="secondary" class="text-xs">
                      +{workspace.tags.length - 3}
                    </Badge>
                  {/if}
                </div>
              {/if}

              <!-- Stats -->
              <div class="grid grid-cols-2 gap-4 text-sm text-muted-foreground">
                <div>
                  <div class="font-medium">{workspace.document_count || 0}</div>
                  <div>Documents</div>
                </div>
                <div>
                  <div class="font-medium">{workspace.notebook_count || 0}</div>
                  <div>Notebooks</div>
                </div>
              </div>

              <!-- Dates -->
              <div class="text-xs text-muted-foreground space-y-1">
                <div>Created: {formatDate(workspace.created_at)}</div>
                {#if workspace.last_activity}
                  <div>Last activity: {formatDate(workspace.last_activity)}</div>
                {/if}
              </div>

              <!-- Actions -->
              <div class="flex gap-2 pt-2">
                <Button 
                  size="sm" 
                  class="flex-1"
                  onclick={() => handleViewWorkspace(workspace.id)}
                >
                  <FolderOpen class="w-4 h-4 mr-2" />
                  Dashboard
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      {/each}
    </div>
  {/if}
</div>

<style>
  .line-clamp-2 {
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
</style>