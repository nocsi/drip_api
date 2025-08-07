<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '../../utils';
  import { 
    notebooks, 
    currentWorkspace, 
    currentTeam,
    auth, 
    apiService,
    createTableStore 
  } from '../../stores/index';
  import type { Notebook, NotebookTask } from '../../types';
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
    BookOpen, 
    Settings, 
    Trash2, 
    MoreHorizontal,
    Calendar,
    Play,
    Square,
    RotateCcw,
    Copy,
    Clock,
    User,
    Code,
    CheckCircle,
    XCircle,
    Loader2,
    Zap,
    FileText,
    Activity,
    Timer,
    Database,
    Search,
    Filter,
    Grid,
    List,
    Edit,
    Eye,
    Share,
    Download,
    Upload,
    RefreshCw,
    ExternalLink,
    TrendingUp,
    Users,
    AlertCircle,
    PlayCircle,
    PauseCircle,
    StopCircle,
    X
  } from '@lucide/svelte';

  // Component state
  let showCreateDialog = $state(false);
  let showExecuteDialog = $state(false);
  let selectedNotebook = $state<Notebook | null>(null);
  let notebookTasks = $state<NotebookTask[]>([]);
  let loading = $state(false);
  let viewMode = $state<'grid' | 'list'>('grid');
  let searchQuery = $state('');
  let filterStatus = $state('all');
  let sortBy = $state('updated_at');
  let sortOrder: 'asc' | 'desc' = 'desc';

  // Form state
  let createForm = {
    title: '',
    description: '',
    content: '',
    language: 'python',
    execution_timeout_seconds: 300,
    collaborative_mode: false,
    auto_save_enabled: true,
    workspace_id: '',
    document_id: ''
  };

  let executeForm = {
    environment: {} as Record<string, string>,
    timeout_seconds: 300,
    save_output: true
  };

  const tableStore = createTableStore<Notebook>();

  const notebooksData = $derived($notebooks.data || []);
  const isLoading = $derived($notebooks.status === 'loading' || loading);
  const hasWorkspace = $derived(!!$currentWorkspace);

  // Filter and search notebooks
  const filteredNotebooks = $derived(notebooksData.filter(notebook => {
    // Search filter
    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase();
      const matchesSearch = 
        notebook.title.toLowerCase().includes(query) ||
        (notebook.description && notebook.description.toLowerCase().includes(query)) ||
        (notebook.language && notebook.language.toLowerCase().includes(query));
      if (!matchesSearch) return false;
    }
    
    // Status filter
    if (filterStatus !== 'all') {
      if (notebook.status !== filterStatus) return false;
    }
    
    return true;
  }).sort((a, b) => {
    let aValue, bValue;
    
    switch (sortBy) {
      case 'title':
        aValue = a.title.toLowerCase();
        bValue = b.title.toLowerCase();
        break;
      case 'status':
        aValue = a.status;
        bValue = b.status;
        break;
      case 'language':
        aValue = a.language || '';
        bValue = b.language || '';
        break;
      case 'created_at':
        aValue = new Date(a.created_at).getTime();
        bValue = new Date(b.created_at).getTime();
        break;
      case 'updated_at':
      default:
        aValue = new Date(a.updated_at).getTime();
        bValue = new Date(b.updated_at).getTime();
        break;
    }
    
    if (sortOrder === 'asc') {
      return aValue < bValue ? -1 : aValue > bValue ? 1 : 0;
    } else {
      return aValue > bValue ? -1 : aValue < bValue ? 1 : 0;
    }
  }));

  onMount(async () => {
    if ($apiService && hasWorkspace) {
      await loadNotebooks();
    }
  });

  async function loadNotebooks() {
    if (!$apiService || !$currentWorkspace) return;
    await notebooks.load($apiService, $currentWorkspace.id);
  }

  async function loadNotebookTasks(notebook: Notebook) {
    if (!$apiService) return;
    
    try {
      loading = true;
      const response = await $apiService.getNotebookTasks(notebook.id);
      notebookTasks = response.data;
    } catch (error) {
      console.error('Failed to load notebook tasks:', error);
    } finally {
      loading = false;
    }
  }

  async function createNotebook() {
    if (!$apiService || !$currentWorkspace) return;

    try {
      loading = true;
      const notebook = await notebooks.create($apiService, '', {
        ...createForm,
        workspace_id: $currentWorkspace.id
      });
      
      // Reset form
      createForm = { 
        title: '', 
        description: '', 
        content: '',
        language: 'python',
        execution_timeout_seconds: 300,
        collaborative_mode: false,
        auto_save_enabled: true,
        workspace_id: '',
        document_id: ''
      };
      showCreateDialog = false;
      
      // Navigate to the new notebook
      goto(`/notebooks/${notebook.id}/edit`);
    } catch (error) {
      console.error('Failed to create notebook:', error);
    } finally {
      loading = false;
    }
  }

  async function executeNotebook(notebook: Notebook) {
    if (!$apiService) return;

    try {
      loading = true;
      await notebooks.execute($apiService, notebook.id, executeForm);
      
      // Reset form
      executeForm = {
        environment: {},
        timeout_seconds: 300,
        save_output: true
      };
      showExecuteDialog = false;
      
      // Reload notebooks to get updated status
      await loadNotebooks();
    } catch (error) {
      console.error('Failed to execute notebook:', error);
    } finally {
      loading = false;
    }
  }

  async function stopExecution(notebook: Notebook) {
    if (!$apiService) return;

    try {
      loading = true;
      await $apiService.stopNotebookExecution(notebook.id);
      
      // Reload notebooks to get updated status
      await loadNotebooks();
    } catch (error) {
      console.error('Failed to stop execution:', error);
    } finally {
      loading = false;
    }
  }

  async function resetExecution(notebook: Notebook) {
    if (!$apiService) return;

    try {
      loading = true;
      await $apiService.resetNotebookExecution(notebook.id);
      
      // Reload notebooks to get updated status
      await loadNotebooks();
    } catch (error) {
      console.error('Failed to reset execution:', error);
    } finally {
      loading = false;
    }
  }

  async function duplicateNotebook(notebook: Notebook) {
    if (!$apiService) return;

    try {
      loading = true;
      const duplicated = await $apiService.duplicateNotebook(notebook.id, {
        title: `${notebook.title} (Copy)`,
        description: notebook.description,
        workspace_id: $currentWorkspace?.id
      });
      
      // Reload notebooks
      await loadNotebooks();
      
      // Navigate to the duplicated notebook
      goto(`/notebooks/${duplicated.data.id}/edit`);
    } catch (error) {
      console.error('Failed to duplicate notebook:', error);
    } finally {
      loading = false;
    }
  }

  async function deleteNotebook(notebook: Notebook) {
    if (!$apiService) return;

    try {
      loading = true;
      await notebooks.delete($apiService, notebook.id);
    } catch (error) {
      console.error('Failed to delete notebook:', error);
    } finally {
      loading = false;
    }
  }

  async function toggleCollaborativeMode(notebook: Notebook) {
    if (!$apiService) return;

    try {
      loading = true;
      await $apiService.toggleCollaborativeMode(notebook.id);
      
      // Reload notebooks to get updated status
      await loadNotebooks();
    } catch (error) {
      console.error('Failed to toggle collaborative mode:', error);
    } finally {
      loading = false;
    }
  }

  function clearFilters() {
    searchQuery = '';
    filterStatus = 'all';
  }

  function getStatusIcon(status: string) {
    switch (status) {
      case 'running':
        return PlayCircle;
      case 'completed':
        return CheckCircle;
      case 'error':
        return XCircle;
      case 'cancelled':
        return StopCircle;
      case 'idle':
      default:
        return PauseCircle;
    }
  }

  function getStatusBadgeVariant(status: string) {
    switch (status) {
      case 'running':
        return 'default';
      case 'completed':
        return 'secondary';
      case 'error':
        return 'destructive';
      case 'cancelled':
        return 'outline';
      case 'idle':
      default:
        return 'outline';
    }
  }

  function getLanguageIcon(language: string) {
    switch (language?.toLowerCase()) {
      case 'python':
        return Code;
      case 'javascript':
      case 'typescript':
        return Code;
      case 'sql':
        return Database;
      default:
        return Code;
    }
  }

  function formatDate(dateString: string): string {
    return new Date(dateString).toLocaleDateString();
  }

  function formatDuration(ms: number): string {
    if (ms < 1000) return `${ms}ms`;
    if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`;
    return `${(ms / 60000).toFixed(1)}m`;
  }

  function getInitials(name: string): string {
    return name
      .split(' ')
      .map(word => word.charAt(0))
      .join('')
      .toUpperCase()
      .slice(0, 2);
  }

  function getCompletionPercentage(notebook: Notebook): number {
    if (!notebook.task_count || notebook.task_count === 0) return 0;
    return Math.round(((notebook.completed_task_count || 0) / notebook.task_count) * 100);
  }

  function openExecuteDialog(notebook: Notebook) {
    selectedNotebook = notebook;
    executeForm.timeout_seconds = notebook.execution_timeout_seconds || 300;
    showExecuteDialog = true;
  }
</script>

<div class="space-y-6">
  <!-- Header -->
  <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
    <div>
      <h1 class="text-2xl font-bold text-foreground">Notebooks</h1>
      <p class="text-muted-foreground">
        {#if $currentWorkspace}
          Execute and manage notebooks in {$currentWorkspace.name}
        {:else}
          Select a workspace to view notebooks
        {/if}
      </p>
    </div>
    
    {#if hasWorkspace}
      <Dialog bind:open={showCreateDialog}>
        <DialogTrigger>
          <Button>
            <Plus class="mr-2 h-4 w-4" />
            New Notebook
          </Button>
        </DialogTrigger>
      </Dialog>
    {/if}
  </div>

  {#if !hasWorkspace}
    <!-- No Workspace Selected -->
    <Card>
      <CardContent class="flex flex-col items-center justify-center py-12">
        <BookOpen class="h-12 w-12 text-muted-foreground mb-4" />
        <h3 class="text-lg font-semibold mb-2">No Workspace Selected</h3>
        <p class="text-muted-foreground text-center mb-4">
          Please select a workspace first to view and manage notebooks.
        </p>
        <Button onclick={() => goto('/workspaces')}>
          Select Workspace
        </Button>
      </CardContent>
    </Card>
  {:else}
    <!-- Filters and Search -->
    <Card>
      <CardContent class="p-4">
        <div class="flex flex-col gap-4 md:flex-row md:items-center">
          <!-- Search -->
          <div class="flex-1">
            <div class="relative">
              <Search class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search notebooks..."
                bind:value={searchQuery}
                class="pl-9"
              />
            </div>
          </div>
          
          <!-- Filters -->
          <div class="flex items-center gap-2">
            <!-- Status Filter -->
            <select
              bind:value={filterStatus}
              class="flex h-9 w-auto rounded-md border border-input bg-background px-3 py-1 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <option value="all">All Status</option>
              <option value="idle">Idle</option>
              <option value="running">Running</option>
              <option value="completed">Completed</option>
              <option value="error">Error</option>
              <option value="cancelled">Cancelled</option>
            </select>
            
            <!-- Sort -->
            <select
              bind:value={sortBy}
              class="flex h-9 w-auto rounded-md border border-input bg-background px-3 py-1 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <option value="updated_at">Last Updated</option>
              <option value="created_at">Date Created</option>
              <option value="title">Title</option>
              <option value="status">Status</option>
              <option value="language">Language</option>
            </select>
            
            <Button
              variant="outline"
              size="sm"
              onclick={() => sortOrder = sortOrder === 'asc' ? 'desc' : 'asc'}
            >
              {sortOrder === 'asc' ? '↑' : '↓'}
            </Button>
            
            <!-- View Mode -->
            <div class="flex rounded-md border border-input">
              <Button
                variant={viewMode === 'grid' ? 'default' : 'ghost'}
                size="sm"
                class="rounded-r-none"
                onclick={() => viewMode = 'grid'}
              >
                <Grid class="h-4 w-4" />
              </Button>
              <Button
                variant={viewMode === 'list' ? 'default' : 'ghost'}
                size="sm"
                class="rounded-l-none"
                onclick={() => viewMode = 'list'}
              >
                <List class="h-4 w-4" />
              </Button>
            </div>
            
            {#if searchQuery || filterStatus !== 'all'}
              <Button variant="outline" size="sm" onclick={clearFilters}>
                Clear
              </Button>
            {/if}
          </div>
        </div>
      </CardContent>
    </Card>

    <!-- Notebooks Display -->
    {#if viewMode === 'grid'}
      <!-- Grid View -->
      <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        {#each filteredNotebooks as notebook (notebook.id)}
          <Card class="cursor-pointer transition-all hover:shadow-md">
            <CardHeader class="pb-3">
              <div class="flex items-start justify-between">
                <div class="flex items-start space-x-3 min-w-0">
                  <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10">
                    <svelte:component this={getLanguageIcon(notebook.language)} class="h-5 w-5 text-primary" />
                  </div>
                  <div class="min-w-0">
                    <CardTitle class="text-lg truncate">{notebook.title}</CardTitle>
                    <div class="flex items-center space-x-2 mt-1">
                      <Badge variant={getStatusBadgeVariant(notebook.status)} class="text-xs">
                        <svelte:component this={getStatusIcon(notebook.status)} class="mr-1 h-3 w-3" />
                        {notebook.status}
                      </Badge>
                      {#if notebook.language}
                        <Badge variant="outline" class="text-xs">
                          {notebook.language}
                        </Badge>
                      {/if}
                      {#if notebook.collaborative_mode}
                        <Badge variant="secondary" class="text-xs">
                          <Users class="mr-1 h-3 w-3" />
                          Collaborative
                        </Badge>
                      {/if}
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
                    <DropdownMenuItem onclick={() => goto(`/notebooks/${notebook.id}`)}>
                      <Eye class="mr-2 h-4 w-4" />
                      View
                    </DropdownMenuItem>
                    <DropdownMenuItem onclick={() => goto(`/notebooks/${notebook.id}/edit`)}>
                      <Edit class="mr-2 h-4 w-4" />
                      Edit
                    </DropdownMenuItem>
                    <DropdownMenuSeparator />
                    {#if notebook.status === 'idle' || notebook.status === 'completed' || notebook.status === 'error'}
                      <DropdownMenuItem onclick={() => openExecuteDialog(notebook)}>
                        <Play class="mr-2 h-4 w-4" />
                        Execute
                      </DropdownMenuItem>
                    {/if}
                    {#if notebook.status === 'running'}
                      <DropdownMenuItem onclick={() => stopExecution(notebook)}>
                        <Square class="mr-2 h-4 w-4" />
                        Stop
                      </DropdownMenuItem>
                    {/if}
                    <DropdownMenuItem onclick={() => resetExecution(notebook)}>
                      <RotateCcw class="mr-2 h-4 w-4" />
                      Reset
                    </DropdownMenuItem>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem onclick={() => duplicateNotebook(notebook)}>
                      <Copy class="mr-2 h-4 w-4" />
                      Duplicate
                    </DropdownMenuItem>
                    <DropdownMenuItem onclick={() => toggleCollaborativeMode(notebook)}>
                      <Share class="mr-2 h-4 w-4" />
                      {notebook.collaborative_mode ? 'Disable' : 'Enable'} Collaboration
                    </DropdownMenuItem>
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
                            This action cannot be undone. This will permanently delete the notebook
                            "{notebook.title}" and all its execution history.
                          </AlertDialogDescription>
                        </AlertDialogHeader>
                        <AlertDialogFooter>
                          <AlertDialogCancel>Cancel</AlertDialogCancel>
                          <AlertDialogAction onclick={() => deleteNotebook(notebook)}>
                            Delete Notebook
                          </AlertDialogAction>
                        </AlertDialogFooter>
                      </AlertDialogContent>
                    </AlertDialog>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            </CardHeader>
            
            <CardContent>
              {#if notebook.description}
                <CardDescription class="mb-3 line-clamp-2">{notebook.description}</CardDescription>
              {/if}
              
              <!-- Progress -->
              {#if notebook.task_count && notebook.task_count > 0}
                <div class="mb-3">
                  <div class="flex items-center justify-between text-sm mb-1">
                    <span>Progress</span>
                    <span>{notebook.completed_task_count || 0}/{notebook.task_count} tasks</span>
                  </div>
                  <Progress value={getCompletionPercentage(notebook)} class="h-2" />
                </div>
              {/if}
              
              <div class="space-y-2 text-sm text-muted-foreground">
                {#if notebook.avg_execution_time_ms}
                  <div class="flex items-center">
                    <Timer class="mr-1 h-4 w-4" />
                    Avg: {formatDuration(notebook.avg_execution_time_ms)}
                  </div>
                {/if}
                
                {#if notebook.last_execution_at}
                  <div class="flex items-center">
                    <Clock class="mr-1 h-4 w-4" />
                    Last run: {formatDate(notebook.last_execution_at)}
                  </div>
                {/if}
                
                <div class="flex items-center">
                  <Calendar class="mr-1 h-4 w-4" />
                  Updated {formatDate(notebook.updated_at)}
                </div>
                
                <div class="flex items-center">
                  <User class="mr-1 h-4 w-4" />
                  {notebook.created_by?.name || 'Unknown'}
                </div>
              </div>
              
              <div class="flex gap-2 mt-4">
                {#if notebook.status === 'idle' || notebook.status === 'completed' || notebook.status === 'error'}
                  <Button 
                    class="flex-1" 
                    size="sm"
                    onclick={() => openExecuteDialog(notebook)}
                  >
                    <Play class="mr-2 h-4 w-4" />
                    Execute
                  </Button>
                {:else if notebook.status === 'running'}
                  <Button 
                    class="flex-1" 
                    variant="destructive"
                    size="sm"
                    onclick={() => stopExecution(notebook)}
                  >
                    <Square class="mr-2 h-4 w-4" />
                    Stop
                  </Button>
                {/if}
                <Button 
                  class="flex-1" 
                  variant="default"
                  size="sm"
                  onclick={() => goto(`/notebooks/${notebook.id}/edit`)}
                >
                  <Edit class="mr-2 h-4 w-4" />
                  Edit
                </Button>
              </div>
            </CardContent>
          </Card>
        {/each}

        {#if filteredNotebooks.length === 0 && !isLoading}
          <div class="col-span-full">
            <Card class="border-dashed">
              <CardContent class="flex flex-col items-center justify-center py-12">
                <BookOpen class="h-12 w-12 text-muted-foreground mb-4" />
                <h3 class="text-lg font-semibold mb-2">
                  {searchQuery || filterStatus !== 'all' ? 'No notebooks found' : 'No notebooks yet'}
                </h3>
                <p class="text-muted-foreground text-center mb-4">
                  {searchQuery || filterStatus !== 'all'
                    ? 'Try adjusting your search or filters'
                    : 'Create your first notebook to start executing code'
                  }
                </p>
                {#if !searchQuery && filterStatus === 'all'}
                  <Button onclick={() => (showCreateDialog = true)}>
                    <Plus class="mr-2 h-4 w-4" />
                    Create Notebook
                  </Button>
                {/if}
              </CardContent>
            </Card>
          </div>
        {/if}
      </div>
    {:else}
      <!-- List View -->
      <Card>
        <CardContent class="p-0">
          <div class="divide-y">
            {#each filteredNotebooks as notebook (notebook.id)}
              <div class="flex items-center justify-between p-4 hover:bg-muted/50">
                <div class="flex items-center space-x-4 min-w-0">
                  <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10">
                    <svelte:component this={getLanguageIcon(notebook.language)} class="h-4 w-4 text-primary" />
                  </div>
                  
                  <div class="min-w-0 flex-1">
                    <div class="flex items-center space-x-2">
                      <h3 class="font-medium truncate">{notebook.title}</h3>
                      <Badge variant={getStatusBadgeVariant(notebook.status)} class="text-xs">
                        <svelte:component this={getStatusIcon(notebook.status)} class="mr-1 h-3 w-3" />
                        {notebook.status}
                      </Badge>
                      {#if notebook.language}
                        <Badge variant="outline" class="text-xs">
                          {notebook.language}
                        </Badge>
                      {/if}
                    </div>
                    {#if notebook.description}
                      <p class="text-sm text-muted-foreground truncate">{notebook.description}</p>
                    {/if}
                    
                    <!-- Progress bar for list view -->
                    {#if notebook.task_count && notebook.task_count > 0}
                      <div class="flex items-center space-x-2 mt-1">
                        <Progress value={getCompletionPercentage(notebook)} class="h-1 flex-1" />
                        <span class="text-xs text-muted-foreground">
                          {notebook.completed_task_count || 0}/{notebook.task_count}
                        </span>
                      </div>
                    {/if}
                  </div>
                </div>
                
                <div class="flex items-center space-x-4 text-sm text-muted-foreground">
                  <div class="text-right">
                    <div>{formatDate(notebook.updated_at)}</div>
                    <div class="text-xs">{notebook.created_by?.name || 'Unknown'}</div>
                  </div>
                  
                  <div class="flex items-center space-x-1">
                    {#if notebook.status === 'idle' || notebook.status === 'completed' || notebook.status === 'error'}
                      <Button
                        variant="ghost"
                        size="sm"
                        onclick={() => openExecuteDialog(notebook)}
                      >
                        <Play class="h-4 w-4" />
                      </Button>
                    {:else if notebook.status === 'running'}
                      <Button
                        variant="ghost"
                        size="sm"
                        onclick={() => stopExecution(notebook)}
                      >
                        <Square class="h-4 w-4" />
                      </Button>
                    {/if}
                    <Button
                      variant="ghost"
                      size="sm"
                      onclick={() => goto(`/notebooks/${notebook.id}/edit`)}
                    >
                      <Edit class="h-4 w-4" />
                    </Button>
                    
                    <DropdownMenu>
                      <DropdownMenuTrigger>
                        <Button variant="ghost" size="sm">
                          <MoreHorizontal class="h-4 w-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuItem onclick={() => goto(`/notebooks/${notebook.id}`)}>
                          <Eye class="mr-2 h-4 w-4" />
                          View
                        </DropdownMenuItem>
                        <DropdownMenuItem onclick={() => goto(`/notebooks/${notebook.id}/edit`)}>
                          <Edit class="mr-2 h-4 w-4" />
                          Edit
                        </DropdownMenuItem>
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
                                This action cannot be undone. This will permanently delete the notebook
                                "{notebook.title}" and all its execution history.
                              </AlertDialogDescription>
                            </AlertDialogHeader>
                            <AlertDialogFooter>
                              <AlertDialogCancel>Cancel</AlertDialogCancel>
                              <AlertDialogAction onclick={() => deleteNotebook(notebook)}>
                                Delete Notebook
                              </AlertDialogAction>
                            </AlertDialogFooter>
                          </AlertDialogContent>
                        </AlertDialog>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </div>
                </div>
              </div>
            {/each}
            
            {#if filteredNotebooks.length === 0 && !isLoading}
              <div class="flex flex-col items-center justify-center py-12">
                <BookOpen class="h-12 w-12 text-muted-foreground mb-4" />
                <h3 class="text-lg font-semibold mb-2">
                  {searchQuery || filterStatus !== 'all' ? 'No notebooks found' : 'No notebooks yet'}
                </h3>
                <p class="text-muted-foreground text-center mb-4">
                  {searchQuery || filterStatus !== 'all'
                    ? 'Try adjusting your search or filters'
                    : 'Create your first notebook to start executing code'
                  }
                </p>
                {#if !searchQuery && filterStatus === 'all'}
                  <Button onclick={() => (showCreateDialog = true)}>
                    <Plus class="mr-2 h-4 w-4" />
                    Create Notebook
                  </Button>
                {/if}
              </div>
            {/if}
          </div>
        </CardContent>
      </Card>
    {/if}
  {/if}
</div>

<!-- Create Notebook Dialog -->
<Dialog bind:open={showCreateDialog}>
  <DialogContent class="sm:max-w-[500px]">
    <DialogHeader>
      <DialogTitle>Create New Notebook</DialogTitle>
      <DialogDescription>
        Create a new executable notebook in {$currentWorkspace?.name || 'your workspace'}.
      </DialogDescription>
    </DialogHeader>
    <div class="space-y-4 py-4">
      <div class="space-y-2">
        <Label for="notebook-title">Title</Label>
        <Input
          id="notebook-title"
          bind:value={createForm.title}
          placeholder="Enter notebook title"
          required
        />
      </div>
      
      <div class="space-y-2">
        <Label for="notebook-description">Description</Label>
        <Textarea
          id="notebook-description"
          bind:value={createForm.description}
          placeholder="Describe your notebook (optional)"
          rows={3}
        />
      </div>
      
      <div class="space-y-2">
        <Label for="language">Programming Language</Label>
        <select
          id="language"
          bind:value={createForm.language}
          class="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
        >
          <option value="python">Python</option>
          <option value="javascript">JavaScript</option>
          <option value="typescript">TypeScript</option>
          <option value="sql">SQL</option>
          <option value="shell">Shell</option>
          <option value="r">R</option>
          <option value="julia">Julia</option>
        </select>
      </div>
      
      <div class="space-y-2">
        <Label for="timeout">Execution Timeout (seconds)</Label>
        <Input
          id="timeout"
          type="number"
          bind:value={createForm.execution_timeout_seconds}
          min="30"
          max="3600"
          placeholder="300"
        />
      </div>
      
      <div class="flex items-center space-x-2">
        <input 
          type="checkbox" 
          id="collaborative"
          bind:checked={createForm.collaborative_mode}
          class="rounded border-gray-300"
        />
        <Label for="collaborative" class="text-sm">Enable collaborative mode</Label>
      </div>
      
      <div class="flex items-center space-x-2">
        <input 
          type="checkbox" 
          id="auto-save"
          bind:checked={createForm.auto_save_enabled}
          class="rounded border-gray-300"
        />
        <Label for="auto-save" class="text-sm">Enable auto-save</Label>
      </div>
    </div>
    <DialogFooter>
      <Button variant="outline" onclick={() => (showCreateDialog = false)}>
        Cancel
      </Button>
      <Button onclick={createNotebook} disabled={!createForm.title.trim() || isLoading}>
        {#if isLoading}
          Creating...
        {:else}
          Create Notebook
        {/if}
      </Button>
    </DialogFooter>
  </DialogContent>
</Dialog>

<!-- Execute Notebook Dialog -->
<Dialog bind:open={showExecuteDialog}>
  <DialogContent class="sm:max-w-[425px]">
    <DialogHeader>
      <DialogTitle>Execute Notebook</DialogTitle>
      <DialogDescription>
        Execute "{selectedNotebook?.title || 'notebook'}" with custom parameters.
      </DialogDescription>
    </DialogHeader>
    
    <div class="space-y-4 py-4">
      <div class="space-y-2">
        <Label for="exec-timeout">Timeout (seconds)</Label>
        <Input
          id="exec-timeout"
          type="number"
          bind:value={executeForm.timeout_seconds}
          min="30"
          max="3600"
          placeholder="300"
        />
      </div>
      
      <div class="space-y-2">
        <Label>Environment Variables</Label>
        <div class="space-y-2">
          {#each Object.keys(executeForm.environment) as key, i}
            <div class="flex space-x-2">
              <Input 
                placeholder="Variable name" 
                value={key}
                oninput={(e) => {
                  const newKey = e.target.value;
                  const oldValue = executeForm.environment[key];
                  delete executeForm.environment[key];
                  executeForm.environment[newKey] = oldValue;
                  executeForm.environment = executeForm.environment;
                }}
                class="flex-1" 
              />
              <Input 
                placeholder="Value" 
                value={executeForm.environment[key]}
                oninput={(e) => {
                  executeForm.environment[key] = e.target.value;
                }}
                class="flex-1" 
              />
              <Button 
                variant="outline" 
                size="sm"
                onclick={() => {
                  delete executeForm.environment[key];
                  executeForm.environment = executeForm.environment;
                }}
              >
                <X class="h-4 w-4" />
              </Button>
            </div>
          {/each}
        </div>
        <Button 
          variant="outline" 
          size="sm"
          onclick={() => {
            executeForm.environment[`VAR_${Object.keys(executeForm.environment).length + 1}`] = '';
            executeForm.environment = executeForm.environment;
          }}
        >
          Add Variable
        </Button>
      </div>
      
      <div class="flex items-center space-x-2">
        <input 
          type="checkbox" 
          id="save-output"
          bind:checked={executeForm.save_output}
          class="rounded border-gray-300"
        />
        <Label for="save-output" class="text-sm">Save execution output</Label>
      </div>
    </div>
    
    <DialogFooter>
      <Button variant="outline" onclick={() => (showExecuteDialog = false)}>
        Cancel
      </Button>
      <Button 
        onclick={() => selectedNotebook && executeNotebook(selectedNotebook)} 
        disabled={isLoading}
      >
        {#if isLoading}
          <Loader2 class="mr-2 h-4 w-4 animate-spin" />
          Executing...
        {:else}
          <Play class="mr-2 h-4 w-4" />
          Execute Notebook
        {/if}
      </Button>
    </DialogFooter>
  </DialogContent>
</Dialog>