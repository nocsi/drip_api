<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '../../utils';
  import { 
    workspaces, 
    currentWorkspace, 
    currentTeam,
    auth, 
    apiService,
    createTableStore 
  } from '../../stores/index';
  import type { Workspace, WorkspaceStatistics } from '../../types';
  import { Button } from '../../ui/button';
  import { Input } from '../../ui/input';
  import { Label } from '../../ui/label';
  import { Textarea } from '../../ui/textarea';
  import { Avatar, AvatarFallback, AvatarImage } from '../../ui/avatar';
  import { Badge } from '../../ui/badge';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../../ui/card';
  import { Separator } from '../../ui/separator';
  import { Progress } from '../../ui/progress';
  import { 
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DialogTrigger
  } from '../../ui/dialog';
  import { 
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger
  } from '../../ui/dropdown-menu';
  import { 
    AlertDialog,
    AlertDialogAction,
    AlertDialogCancel,
    AlertDialogContent,
    AlertDialogDescription,
    AlertDialogFooter,
    AlertDialogHeader,
    AlertDialogTitle,
    AlertDialogTrigger
  } from '../../ui/alert-dialog';
  import { 
    Plus, 
    FolderOpen, 
    Settings, 
    Trash2, 
    MoreHorizontal,
    FileText,
    BookOpen,
    Activity,
    Calendar,
    HardDrive,
    GitBranch,
    Copy,
    Archive,
    RefreshCw,
    ExternalLink,
    TrendingUp,
    Users,
    Clock,
    CheckCircle,
    XCircle,
    Folder,
    Database,
    Cloud,
    Github
  } from '@lucide/svelte';

  // Component state
  let showCreateDialog = false;
  let showDuplicateDialog = false;
  let selectedWorkspace: Workspace | null = null;
  let workspaceToDuplicate: Workspace | null = null;
  let loading = false;
  let workspaceStats: WorkspaceStatistics | null = null;

  // Form state
  let createForm = {
    name: '',
    description: '',
    storage_backend: 'local' as 'local' | 'git' | 's3' | 'github',
    storage_path: '',
    git_repository_url: '',
    git_branch: 'main'
  };

  let duplicateForm = {
    name: '',
    description: '',
    include_documents: true,
    include_notebooks: true
  };

  const tableStore = createTableStore<Workspace>();

  const workspacesData = $derived($workspaces.data || []);
  const isLoading = $derived($workspaces.status === 'loading' || loading);
  const hasTeam = $derived(!!$currentTeam);

  onMount(async () => {
    if ($apiService && hasTeam) {
      await loadWorkspaces();
    }
  });

  async function loadWorkspaces() {
    if (!$apiService) return;
    await workspaces.load($apiService);
  }

  async function loadWorkspaceStats(workspace: Workspace) {
    if (!$apiService) return;
    
    try {
      loading = true;
      const response = await $apiService.getWorkspaceStatistics(workspace.id);
      workspaceStats = response.data;
    } catch (error) {
      console.error('Failed to load workspace statistics:', error);
    } finally {
      loading = false;
    }
  }

  async function createWorkspace() {
    if (!$apiService || !$currentTeam) return;

    try {
      loading = true;
      const workspace = await workspaces.create($apiService, {
        ...createForm,
        team_id: $currentTeam.id
      });
      
      // Reset form
      createForm = { 
        name: '', 
        description: '', 
        storage_backend: 'local',
        storage_path: '',
        git_repository_url: '',
        git_branch: 'main'
      };
      showCreateDialog = false;
      
      // Set as current workspace if user has no current workspace
      if (!$currentWorkspace) {
        currentWorkspace.set(workspace);
        goto(`/workspaces/${workspace.id}`);
      }
    } catch (error) {
      console.error('Failed to create workspace:', error);
    } finally {
      loading = false;
    }
  }

  async function selectWorkspace(workspace: Workspace) {
    currentWorkspace.set(workspace);
    selectedWorkspace = workspace;
    await loadWorkspaceStats(workspace);
    goto(`/workspaces/${workspace.id}`);
  }

  async function duplicateWorkspace() {
    if (!$apiService || !workspaceToDuplicate) return;

    try {
      loading = true;
      const workspace = await $apiService.duplicateWorkspace(workspaceToDuplicate.id, duplicateForm);
      
      // Reset form
      duplicateForm = { 
        name: '', 
        description: '', 
        include_documents: true, 
        include_notebooks: true 
      };
      showDuplicateDialog = false;
      workspaceToDuplicate = null;
      
      // Reload workspaces
      await loadWorkspaces();
      
      // Navigate to new workspace
      goto(`/workspaces/${workspace.data.id}`);
    } catch (error) {
      console.error('Failed to duplicate workspace:', error);
    } finally {
      loading = false;
    }
  }

  async function archiveWorkspace(workspace: Workspace) {
    if (!$apiService) return;

    try {
      loading = true;
      await $apiService.archiveWorkspace(workspace.id);
      
      // If this was the current workspace, clear it
      if ($currentWorkspace?.id === workspace.id) {
        currentWorkspace.set(null);
        selectedWorkspace = null;
      }
      
      // Reload workspaces
      await loadWorkspaces();
    } catch (error) {
      console.error('Failed to archive workspace:', error);
    } finally {
      loading = false;
    }
  }

  async function restoreWorkspace(workspace: Workspace) {
    if (!$apiService) return;

    try {
      loading = true;
      await $apiService.restoreWorkspace(workspace.id);
      
      // Reload workspaces
      await loadWorkspaces();
    } catch (error) {
      console.error('Failed to restore workspace:', error);
    } finally {
      loading = false;
    }
  }

  async function deleteWorkspace(workspace: Workspace) {
    if (!$apiService) return;

    try {
      loading = true;
      await workspaces.delete($apiService, workspace.id);
      
      // If this was the current workspace, clear it
      if ($currentWorkspace?.id === workspace.id) {
        currentWorkspace.set(null);
        selectedWorkspace = null;
      }
    } catch (error) {
      console.error('Failed to delete workspace:', error);
    } finally {
      loading = false;
    }
  }

  function getStorageIcon(backend: string) {
    switch (backend) {
      case 'git':
        return GitBranch;
      case 'github':
        return Github;
      case 's3':
        return Cloud;
      case 'local':
      default:
        return HardDrive;
    }
  }

  function getStatusBadgeVariant(status: string) {
    switch (status) {
      case 'active':
        return 'default';
      case 'archived':
        return 'secondary';
      case 'deleted':
        return 'destructive';
      default:
        return 'outline';
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

  function formatDate(dateString: string): string {
    return new Date(dateString).toLocaleDateString();
  }

  function formatBytes(bytes: number): string {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

  function openDuplicateDialog(workspace: Workspace) {
    workspaceToDuplicate = workspace;
    duplicateForm.name = `${workspace.name} (Copy)`;
    duplicateForm.description = workspace.description || '';
    showDuplicateDialog = true;
  }


</script>

<div class="space-y-6">
  <!-- Header -->
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold text-foreground">Workspaces</h1>
      <p class="text-muted-foreground">
        {#if $currentTeam}
          Manage workspaces for {$currentTeam.name}
        {:else}
          Select a team to view workspaces
        {/if}
      </p>
    </div>
    
    {#if hasTeam}
      <Dialog bind:open={showCreateDialog}>
        <DialogTrigger>
          <Button>
            <Plus class="mr-2 h-4 w-4" />
            New Workspace
          </Button>
        </DialogTrigger>
        <DialogContent class="sm:max-w-[500px]">
          <DialogHeader>
            <DialogTitle>Create New Workspace</DialogTitle>
            <DialogDescription>
              Create a new workspace to organize your documents and notebooks.
            </DialogDescription>
          </DialogHeader>
          <div class="space-y-4 py-4">
            <div class="space-y-2">
              <Label for="workspace-name">Workspace Name</Label>
              <Input
                id="workspace-name"
                bind:value={createForm.name}
                placeholder="Enter workspace name"
                required
              />
            </div>
            <div class="space-y-2">
              <Label for="workspace-description">Description</Label>
              <Textarea
                id="workspace-description"
                bind:value={createForm.description}
                placeholder="Describe your workspace (optional)"
                rows={3}
              />
            </div>
            <div class="space-y-2">
              <Label for="storage-backend">Storage Backend</Label>
              <select
                id="storage-backend"
                bind:value={createForm.storage_backend}
                class="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <option value="local">Local Storage</option>
                <option value="git">Git Repository</option>
                <option value="github">GitHub Repository</option>
                <option value="s3">Amazon S3</option>
              </select>
            </div>
            {#if createForm.storage_backend === 'git' || createForm.storage_backend === 'github'}
              <div class="space-y-2">
                <Label for="git-url">Repository URL</Label>
                <Input
                  id="git-url"
                  bind:value={createForm.git_repository_url}
                  placeholder="https://github.com/user/repo.git"
                />
              </div>
              <div class="space-y-2">
                <Label for="git-branch">Branch</Label>
                <Input
                  id="git-branch"
                  bind:value={createForm.git_branch}
                  placeholder="main"
                />
              </div>
            {:else if createForm.storage_backend === 'local'}
              <div class="space-y-2">
                <Label for="storage-path">Storage Path</Label>
                <Input
                  id="storage-path"
                  bind:value={createForm.storage_path}
                  placeholder="/path/to/workspace (optional)"
                />
              </div>
            {/if}
          </div>
          <DialogFooter>
            <Button variant="outline" onclick={() => (showCreateDialog = false)}>
              Cancel
            </Button>
            <Button onclick={createWorkspace} disabled={!createForm.name.trim() || isLoading}>
              {#if isLoading}
                Creating...
              {:else}
                Create Workspace
              {/if}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    {/if}
  </div>

  {#if !hasTeam}
    <!-- No Team Selected -->
    <Card>
      <CardContent class="flex flex-col items-center justify-center py-12">
        <Users class="h-12 w-12 text-muted-foreground mb-4" />
        <h3 class="text-lg font-semibold mb-2">No Team Selected</h3>
        <p class="text-muted-foreground text-center mb-4">
          Please select a team first to view and manage workspaces.
        </p>
        <Button onclick={() => goto('/teams')}>
          Select Team
        </Button>
      </CardContent>
    </Card>
  {:else}
    <!-- Workspaces Grid -->
    <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
      {#each workspacesData as workspace (workspace.id)}
        <Card class="cursor-pointer transition-all hover:shadow-md {$currentWorkspace?.id === workspace.id ? 'ring-2 ring-primary' : ''}">
          <CardHeader class="pb-3">
            <div class="flex items-start justify-between">
              <div class="flex items-center space-x-3">
                <Avatar class="h-10 w-10">
                  <AvatarFallback class="bg-primary text-primary-foreground">
                    {getInitials(workspace.name)}
                  </AvatarFallback>
                </Avatar>
                <div>
                  <CardTitle class="text-lg">{workspace.name}</CardTitle>
                  <div class="flex items-center space-x-2 mt-1">
                    <Badge variant={getStatusBadgeVariant(workspace.status)}>
                      {workspace.status}
                    </Badge>
                    <div class="flex items-center text-xs text-muted-foreground">
                      <svelte:component this={getStorageIcon(workspace.storage_backend)} class="mr-1 h-3 w-3" />
                      {workspace.storage_backend}
                    </div>
                  </div>
                </div>
              </div>
              
              <DropdownMenu>
                <DropdownMenuTrigger>
                  <Button variant="ghost" size="sm">
                    <MoreHorizontal class="h-4 w-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem onclick={() => selectWorkspace(workspace)}>
                    <ExternalLink class="mr-2 h-4 w-4" />
                    Open Workspace
                  </DropdownMenuItem>
                  <DropdownMenuItem onclick={() => openDuplicateDialog(workspace)}>
                    <Copy class="mr-2 h-4 w-4" />
                    Duplicate
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                  {#if workspace.status === 'active'}
                    <DropdownMenuItem onclick={() => archiveWorkspace(workspace)}>
                      <Archive class="mr-2 h-4 w-4" />
                      Archive
                    </DropdownMenuItem>
                  {:else if workspace.status === 'archived'}
                    <DropdownMenuItem onclick={() => restoreWorkspace(workspace)}>
                      <RefreshCw class="mr-2 h-4 w-4" />
                      Restore
                    </DropdownMenuItem>
                  {/if}
                  <DropdownMenuSeparator />
                  <AlertDialog>
                    <AlertDialogTrigger>
                      <DropdownMenuItem class="text-destructive">
                        <Trash2 class="mr-2 h-4 w-4" />
                        Delete
                      </DropdownMenuItem>
                    </AlertDialogTrigger>
                    <AlertDialogContent>
                      <AlertDialogHeader>
                        <AlertDialogTitle>Are you sure?</AlertDialogTitle>
                        <AlertDialogDescription>
                          This action cannot be undone. This will permanently delete the workspace
                          "{workspace.name}" and all its contents.
                        </AlertDialogDescription>
                      </AlertDialogHeader>
                      <AlertDialogFooter>
                        <AlertDialogCancel>Cancel</AlertDialogCancel>
                        <AlertDialogAction onclick={() => deleteWorkspace(workspace)}>
                          Delete Workspace
                        </AlertDialogAction>
                      </AlertDialogFooter>
                    </AlertDialogContent>
                  </AlertDialog>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          </CardHeader>
          
          <CardContent>
            {#if workspace.description}
              <CardDescription class="mb-3">{workspace.description}</CardDescription>
            {/if}
            
            <div class="space-y-2 mb-4">
              <div class="flex items-center justify-between text-sm">
                <div class="flex items-center space-x-4">
                  <div class="flex items-center">
                    <FileText class="mr-1 h-4 w-4" />
                    {workspace.documents_count || 0} docs
                  </div>
                  <div class="flex items-center">
                    <BookOpen class="mr-1 h-4 w-4" />
                    {workspace.notebooks_count || 0} notebooks
                  </div>
                </div>
              </div>
              
              {#if workspace.size_bytes}
                <div class="flex items-center text-sm text-muted-foreground">
                  <Database class="mr-1 h-4 w-4" />
                  {formatBytes(workspace.size_bytes)}
                </div>
              {/if}
              
              <div class="flex items-center text-sm text-muted-foreground">
                <Calendar class="mr-1 h-4 w-4" />
                Created {formatDate(workspace.created_at)}
              </div>
              
              {#if workspace.accessed_at}
                <div class="flex items-center text-sm text-muted-foreground">
                  <Clock class="mr-1 h-4 w-4" />
                  Last accessed {formatDate(workspace.accessed_at)}
                </div>
              {/if}
            </div>
            
            <Button 
              class="w-full" 
              variant={$currentWorkspace?.id === workspace.id ? 'default' : 'outline'}
              onclick={() => selectWorkspace(workspace)}
              disabled={workspace.status === 'deleted'}
            >
              {$currentWorkspace?.id === workspace.id ? 'Current Workspace' : 'Select Workspace'}
            </Button>
          </CardContent>
        </Card>
      {/each}

      {#if workspacesData.length === 0 && !isLoading}
        <div class="col-span-full">
          <Card class="border-dashed">
            <CardContent class="flex flex-col items-center justify-center py-12">
              <FolderOpen class="h-12 w-12 text-muted-foreground mb-4" />
              <h3 class="text-lg font-semibold mb-2">No workspaces yet</h3>
              <p class="text-muted-foreground text-center mb-4">
                Create your first workspace to start organizing your content.
              </p>
              <Button onclick={() => (showCreateDialog = true)}>
                <Plus class="mr-2 h-4 w-4" />
                Create Workspace
              </Button>
            </CardContent>
          </Card>
        </div>
      {/if}
    </div>

    <!-- Workspace Statistics -->
    {#if selectedWorkspace && workspaceStats}
      <div class="mt-8">
        <Card>
          <CardHeader>
            <CardTitle class="flex items-center space-x-3">
              <Avatar class="h-8 w-8">
                <AvatarFallback class="bg-primary text-primary-foreground">
                  {getInitials(selectedWorkspace.name)}
                </AvatarFallback>
              </Avatar>
              <span>{selectedWorkspace.name} Statistics</span>
            </CardTitle>
          </CardHeader>
          
          <CardContent>
            <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
              <!-- Content Stats -->
              <div class="space-y-2">
                <div class="flex items-center text-sm font-medium">
                  <FileText class="mr-2 h-4 w-4" />
                  Documents
                </div>
                <div class="text-2xl font-bold">{workspaceStats.total_documents}</div>
              </div>
              
              <div class="space-y-2">
                <div class="flex items-center text-sm font-medium">
                  <BookOpen class="mr-2 h-4 w-4" />
                  Notebooks
                </div>
                <div class="text-2xl font-bold">{workspaceStats.total_notebooks}</div>
              </div>
              
              <div class="space-y-2">
                <div class="flex items-center text-sm font-medium">
                  <Activity class="mr-2 h-4 w-4" />
                  Total Tasks
                </div>
                <div class="text-2xl font-bold">{workspaceStats.total_tasks}</div>
              </div>
              
              <div class="space-y-2">
                <div class="flex items-center text-sm font-medium">
                  <CheckCircle class="mr-2 h-4 w-4" />
                  Completed Tasks
                </div>
                <div class="text-2xl font-bold">{workspaceStats.completed_tasks}</div>
                {#if workspaceStats.total_tasks > 0}
                  <Progress 
                    value={(workspaceStats.completed_tasks / workspaceStats.total_tasks) * 100} 
                    class="mt-2"
                  />
                {/if}
              </div>
            </div>
            
            <Separator class="my-6" />
            
            <div class="grid gap-6 md:grid-cols-3">
              <!-- Execution Stats -->
              <div class="space-y-2">
                <div class="flex items-center text-sm font-medium">
                  <TrendingUp class="mr-2 h-4 w-4" />
                  Total Executions
                </div>
                <div class="text-xl font-bold">{workspaceStats.total_executions}</div>
                <div class="text-sm text-muted-foreground">
                  {workspaceStats.successful_executions} successful
                </div>
              </div>
              
              <div class="space-y-2">
                <div class="flex items-center text-sm font-medium">
                  <Clock class="mr-2 h-4 w-4" />
                  Avg Execution Time
                </div>
                <div class="text-xl font-bold">
                  {workspaceStats.avg_execution_time_ms ? Math.round(workspaceStats.avg_execution_time_ms) : 0}ms
                </div>
              </div>
              
              <div class="space-y-2">
                <div class="flex items-center text-sm font-medium">
                  <HardDrive class="mr-2 h-4 w-4" />
                  Storage Used
                </div>
                <div class="text-xl font-bold">
                  {formatBytes(workspaceStats.storage_used_bytes)}
                </div>
              </div>
            </div>
            
            {#if workspaceStats.last_activity_at}
              <Separator class="my-6" />
              
              <div class="text-sm text-muted-foreground">
                Last activity: {formatDate(workspaceStats.last_activity_at)}
              </div>
            {/if}
          </CardContent>
        </Card>
      </div>
    {/if}
  {/if}
</div>

<!-- Duplicate Workspace Dialog -->
<Dialog bind:open={showDuplicateDialog}>
  <DialogContent class="sm:max-w-[425px]">
    <DialogHeader>
      <DialogTitle>Duplicate Workspace</DialogTitle>
      <DialogDescription>
        Create a copy of "{workspaceToDuplicate?.name || 'workspace'}".
      </DialogDescription>
    </DialogHeader>
    <div class="space-y-4 py-4">
      <div class="space-y-2">
        <Label for="duplicate-name">Workspace Name</Label>
        <Input
          id="duplicate-name"
          bind:value={duplicateForm.name}
          placeholder="Enter workspace name"
          required
        />
      </div>
      <div class="space-y-2">
        <Label for="duplicate-description">Description</Label>
        <Textarea
          id="duplicate-description"
          bind:value={duplicateForm.description}
          placeholder="Describe your workspace (optional)"
          rows={3}
        />
      </div>
      <div class="space-y-2">
        <Label>What to include:</Label>
        <div class="space-y-2">
          <label class="flex items-center space-x-2">
            <input 
              type="checkbox" 
              bind:checked={duplicateForm.include_documents}
              class="rounded border-gray-300"
            />
            <span class="text-sm">Include documents</span>
          </label>
          <label class="flex items-center space-x-2">
            <input 
              type="checkbox" 
              bind:checked={duplicateForm.include_notebooks}
              class="rounded border-gray-300"
            />
            <span class="text-sm">Include notebooks</span>
          </label>
        </div>
      </div>
    </div>
    <DialogFooter>
      <Button variant="outline" onclick={() => (showDuplicateDialog = false)}>
        Cancel
      </Button>
      <Button 
        onclick={duplicateWorkspace} 
        disabled={!duplicateForm.name.trim() || isLoading}
      >
        {#if isLoading}
          Duplicating...
        {:else}
          Duplicate Workspace
        {/if}
      </Button>
    </DialogFooter>
  </DialogContent>
</Dialog>