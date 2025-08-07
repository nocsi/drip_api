<script lang="ts">
  import { onMount } from 'svelte';
  import type { LiveSvelteProps } from '../liveSvelte';
  import { Button } from '../ui/button';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
  import { Badge } from '../ui/badge';
  import { Separator } from '../ui/separator';
  import {
    ArrowLeft,
    Settings,
    Archive,
    RotateCcw,
    Trash2,
    Plus,
    FileText,
    BookOpen,
    FolderOpen,
    Users,
    Calendar,
    HardDrive,
    Activity
  } from '@lucide/svelte';
  import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '../ui/dropdown-menu';

  let { workspace = null, documents = [], notebooks = [], live } = $props<LiveSvelteProps<{
    workspace: any;
    documents: any[];
    notebooks: any[];
  }>>();

  function handleBack() {
    live.pushEvent('lv:push_navigate', { to: '/workspaces' });
  }

  function handleEditWorkspace() {
    live.pushEvent('lv:push_patch', { to: `/workspaces/${workspace.id}/edit` });
  }

  function handleArchiveWorkspace() {
    live.pushEvent('archive_workspace', {});
  }

  function handleRestoreWorkspace() {
    live.pushEvent('restore_workspace', {});
  }

  function handleDeleteDocument(documentId: string) {
    live.pushEvent('delete_document', { id: documentId });
  }

  function handleDeleteNotebook(notebookId: string) {
    live.pushEvent('delete_notebook', { id: notebookId });
  }

  function handleCreateDocument() {
    // Navigate to document creation (would need to be implemented)
    console.log('Create document');
  }

  function handleCreateNotebook() {
    // Navigate to notebook creation (would need to be implemented)
    console.log('Create notebook');
  }

  function formatDate(dateString: string) {
    if (!dateString) return 'Never';
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function formatFileSize(bytes: number) {
    if (!bytes || bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
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

{#if workspace}
  <div class="p-6 space-y-6">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <div class="flex items-center space-x-4">
        <Button variant="ghost" size="sm" onclick={handleBack}>
          <ArrowLeft class="w-4 h-4 mr-2" />
          Back to Workspaces
        </Button>
        <div>
          <h1 class="text-3xl font-bold tracking-tight">{workspace.name}</h1>
          {#if workspace.description}
            <p class="text-muted-foreground mt-1">{workspace.description}</p>
          {/if}
        </div>
      </div>

      <div class="flex items-center space-x-2">
        <Button onclick={() => pushEvent('lv:push_navigate', { to: `/workspaces/${workspace.id}/dashboard` })}>
          <FolderOpen class="w-4 h-4 mr-2" />
          Open Dashboard
        </Button>

        <Button variant="outline" onclick={handleEditWorkspace}>
          <Settings class="w-4 h-4 mr-2" />
          Settings
        </Button>

        {#if workspace.status === 'active'}
          <Button variant="outline" onclick={handleArchiveWorkspace}>
            <Archive class="w-4 h-4 mr-2" />
            Archive
          </Button>
        {:else if workspace.status === 'archived'}
          <Button variant="outline" onclick={handleRestoreWorkspace}>
            <RotateCcw class="w-4 h-4 mr-2" />
            Restore
          </Button>
        {/if}
      </div>
    </div>

    <!-- Workspace Info -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
      <!-- Status Card -->
      <Card>
        <CardHeader class="pb-3">
          <CardTitle class="text-sm font-medium">Status</CardTitle>
        </CardHeader>
        <CardContent>
          <Badge class={getStatusColor(workspace.status)}>
            {workspace.status}
          </Badge>
        </CardContent>
      </Card>

      <!-- Storage Backend Card -->
      <Card>
        <CardHeader class="pb-3">
          <CardTitle class="text-sm font-medium flex items-center">
            <HardDrive class="w-4 h-4 mr-2" />
            Storage
          </CardTitle>
        </CardHeader>
        <CardContent>
          <Badge class={getStorageBackendColor(workspace.storage_backend)}>
            {workspace.storage_backend}
          </Badge>
        </CardContent>
      </Card>

      <!-- Files Count Card -->
      <Card>
        <CardHeader class="pb-3">
          <CardTitle class="text-sm font-medium">Files</CardTitle>
        </CardHeader>
        <CardContent>
          <div class="text-2xl font-bold">
            {(workspace.document_count || 0) + (workspace.notebook_count || 0)}
          </div>
          <p class="text-xs text-muted-foreground">
            {workspace.document_count || 0} docs, {workspace.notebook_count || 0} notebooks
          </p>
        </CardContent>
      </Card>

      <!-- Last Activity Card -->
      <Card>
        <CardHeader class="pb-3">
          <CardTitle class="text-sm font-medium flex items-center">
            <Activity class="w-4 h-4 mr-2" />
            Last Activity
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div class="text-sm">
            {formatDate(workspace.last_activity || workspace.updated_at)}
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- Tags -->
    {#if workspace.tags && workspace.tags.length > 0}
      <Card>
        <CardHeader class="pb-3">
          <CardTitle class="text-lg">Tags</CardTitle>
        </CardHeader>
        <CardContent>
          <div class="flex flex-wrap gap-2">
            {#each workspace.tags as tag}
              <Badge variant="secondary">{tag}</Badge>
            {/each}
          </div>
        </CardContent>
      </Card>
    {/if}

    <!-- Content Sections -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Documents Section -->
      <Card>
        <CardHeader class="pb-3">
          <div class="flex items-center justify-between">
            <CardTitle class="flex items-center">
              <FileText class="w-5 h-5 mr-2" />
              Documents ({documents.length})
            </CardTitle>
            <div class="flex space-x-2">
              <Button size="sm" onclick={handleCreateDocument}>
                <Plus class="w-4 h-4 mr-2" />
                New Document
              </Button>
              <Button size="sm" variant="outline" onclick={() => pushEvent('lv:push_navigate', { to: `/workspaces/${workspace.id}/dashboard` })}>
                <FolderOpen class="w-4 h-4 mr-2" />
                Browse All
              </Button>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          {#if documents.length === 0}
            <div class="text-center py-8 text-muted-foreground">
              <FileText class="w-12 h-12 mx-auto mb-4 opacity-50" />
              <p>No documents yet</p>
              <p class="text-sm">Create your first document to get started</p>
            </div>
          {:else}
            <div class="space-y-3">
              {#each documents.slice(0, 5) as document}
                <div class="flex items-center justify-between p-3 border rounded-lg">
                  <div class="flex-1 min-w-0">
                    <div class="font-medium truncate">{document.name || document.file_name}</div>
                    <div class="text-sm text-muted-foreground">
                      {formatDate(document.updated_at)}
                      {#if document.file_size}
                        • {formatFileSize(document.file_size)}
                      {/if}
                    </div>
                  </div>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild let:builder>
                      <Button builders={[builder]} variant="ghost" size="sm">
                        <Settings class="w-4 h-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem>Edit</DropdownMenuItem>
                      <DropdownMenuItem>Download</DropdownMenuItem>
                      <DropdownMenuItem
                        onclick={() => handleDeleteDocument(document.id)}
                        class="text-destructive focus:text-destructive"
                      >
                        <Trash2 class="w-4 h-4 mr-2" />
                        Delete
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
              {/each}
              {#if documents.length > 5}
                <div class="text-center">
                  <Button variant="outline" size="sm">
                    View all {documents.length} documents
                  </Button>
                </div>
              {/if}
            </div>
          {/if}
        </CardContent>
      </Card>

      <!-- Notebooks Section -->
      <Card>
        <CardHeader class="pb-3">
          <div class="flex items-center justify-between">
            <CardTitle class="flex items-center">
              <BookOpen class="w-5 h-5 mr-2" />
              Notebooks ({notebooks.length})
            </CardTitle>
            <div class="flex space-x-2">
              <Button size="sm" on:click={handleCreateNotebook}>
                <Plus class="w-4 h-4 mr-2" />
                New Notebook
              </Button>
              <Button size="sm" variant="outline" on:click={() => pushEvent('lv:push_navigate', { to: `/workspaces/${workspace.id}/dashboard` })}>
                <BookOpen class="w-4 h-4 mr-2" />
                Browse All
              </Button>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          {#if notebooks.length === 0}
            <div class="text-center py-8 text-muted-foreground">
              <BookOpen class="w-12 h-12 mx-auto mb-4 opacity-50" />
              <p>No notebooks yet</p>
              <p class="text-sm">Create your first notebook to get started</p>
            </div>
          {:else}
            <div class="space-y-3">
              {#each notebooks.slice(0, 5) as notebook}
                <div class="flex items-center justify-between p-3 border rounded-lg">
                  <div class="flex-1 min-w-0">
                    <div class="font-medium truncate">{notebook.name || notebook.title}</div>
                    <div class="text-sm text-muted-foreground">
                      {formatDate(notebook.updated_at)}
                      {#if notebook.execution_count}
                        • {notebook.execution_count} executions
                      {/if}
                    </div>
                  </div>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild let:builder>
                      <Button builders={[builder]} variant="ghost" size="sm">
                        <Settings class="w-4 h-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem>Open</DropdownMenuItem>
                      <DropdownMenuItem>Execute</DropdownMenuItem>
                      <DropdownMenuItem
                        on:click={() => handleDeleteNotebook(notebook.id)}
                        class="text-destructive focus:text-destructive"
                      >
                        <Trash2 class="w-4 h-4 mr-2" />
                        Delete
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
              {/each}
              {#if notebooks.length > 5}
                <div class="text-center">
                  <Button variant="outline" size="sm">
                    View all {notebooks.length} notebooks
                  </Button>
                </div>
              {/if}
            </div>
          {/if}
        </CardContent>
      </Card>
    </div>

    <!-- Workspace Details -->
    <Card>
      <CardHeader class="pb-3">
        <CardTitle class="flex items-center">
          <FolderOpen class="w-5 h-5 mr-2" />
          Workspace Details
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="space-y-3">
            <div>
              <label class="text-sm font-medium text-muted-foreground">Created</label>
              <div class="text-sm">{formatDate(workspace.created_at)}</div>
            </div>
            <div>
              <label class="text-sm font-medium text-muted-foreground">Last Updated</label>
              <div class="text-sm">{formatDate(workspace.updated_at)}</div>
            </div>
            {#if workspace.created_by_user}
              <div>
                <label class="text-sm font-medium text-muted-foreground">Created By</label>
                <div class="text-sm">{workspace.created_by_user}</div>
              </div>
            {/if}
          </div>
          <div class="space-y-3">
            {#if workspace.storage_path}
              <div>
                <label class="text-sm font-medium text-muted-foreground">Storage Path</label>
                <div class="text-sm font-mono bg-muted p-2 rounded text-xs">
                  {workspace.storage_path}
                </div>
              </div>
            {/if}
            {#if workspace.git_repository_url}
              <div>
                <label class="text-sm font-medium text-muted-foreground">Git Repository</label>
                <div class="text-sm font-mono bg-muted p-2 rounded text-xs">
                  {workspace.git_repository_url}
                </div>
              </div>
            {/if}
          </div>
        </div>
      </CardContent>
    </Card>
  </div>
{:else}
  <div class="p-6">
    <div class="text-center py-12">
      <h2 class="text-xl font-semibold mb-2">Workspace not found</h2>
      <p class="text-muted-foreground mb-4">The workspace you're looking for doesn't exist or you don't have access to it.</p>
      <Button on:click={handleBack}>
        <ArrowLeft class="w-4 h-4 mr-2" />
        Back to Workspaces
      </Button>
    </div>
  </div>
{/if}
