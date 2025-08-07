<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '../../utils';
  import { 
    projects, 
    currentWorkspace, 
    currentTeam,
    auth, 
    apiService,
    createTableStore 
  } from '../../stores/index';
  import type { Project, LoadEvent } from '../../types';
  import { Button } from '../../ui/button';
  import { Input } from '../../ui/input';
  import { Label } from '../../ui/label';
  import { Textarea } from '../../ui/textarea';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../../ui/card';
  import { Badge } from '../../ui/badge';
  import { Progress } from '../../ui/progress';
  import { Separator } from '../../ui/separator';
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
    Folder, 
    File,
    Code2,
    Settings, 
    Trash2, 
    MoreHorizontal,
    Calendar,
    Clock,
    User,
    FolderOpen,
    FileText,
    Loader2,
    CheckCircle,
    XCircle,
    AlertCircle,
    Play,
    Eye,
    Download,
    Upload,
    RefreshCw,
    ExternalLink,
    Search,
    Filter,
    Grid,
    List,
    GitBranch,
    Hash,
    Activity,
    Database
  } from '@lucide/svelte';

  // Component state
  let showLoadDirectoryDialog = false;
  let showLoadFileDialog = false;
  let showCreateDialog = $state(false);
  let selectedProject = $state<Project | null>(null);
  let loading = $state(false);
  let viewMode = $state<'grid' | 'list'>('grid');
  let searchQuery = $state('');
  let filterStatus = $state('all');
  let sortBy = $state('updated_at');
  let sortOrder = $state<'asc' | 'desc'>('desc');

  // Form state
  let loadDirectoryForm = {
    path: '',
    skip_gitignore: false,
    ignore_file_patterns: [] as string[],
    repository_discovery: true,
    identity: 'auto' as 'auto' | 'document' | 'cell'
  };

  let loadFileForm = {
    path: '',
    identity: 'auto' as 'auto' | 'document' | 'cell'
  };

  let ignorePatternInput = '';

  const tableStore = createTableStore<Project>();

  const projectsData = $derived($projects.data || []);
  const isLoading = $derived($projects.status === 'loading' || loading);

  // Filter and search projects
  const filteredProjects = $derived(projectsData.filter(project => {
    // Search filter
    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase();
      const matchesSearch = 
        project.name.toLowerCase().includes(query) ||
        project.path.toLowerCase().includes(query);
      if (!matchesSearch) return false;
    }
    
    // Status filter
    if (filterStatus !== 'all') {
      if (project.status !== filterStatus) return false;
    }
    
    return true;
  }).sort((a, b) => {
    let aValue, bValue;
    
    switch (sortBy) {
      case 'name':
        aValue = a.name.toLowerCase();
        bValue = b.name.toLowerCase();
        break;
      case 'path':
        aValue = a.path.toLowerCase();
        bValue = b.path.toLowerCase();
        break;
      case 'status':
        aValue = a.status;
        bValue = b.status;
        break;
      case 'type':
        aValue = a.type;
        bValue = b.type;
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
    if ($apiService) {
      await loadProjects();
    }
  });

  async function loadProjects() {
    // Projects are loaded differently - they're created by loading directories/files
    // We would need to implement a list endpoint for projects
  }

  async function loadDirectory() {
    if (!$apiService) return;

    try {
      loading = true;
      const project = await projects.loadDirectory($apiService, loadDirectoryForm.path, {
        skip_gitignore: loadDirectoryForm.skip_gitignore,
        ignore_file_patterns: loadDirectoryForm.ignore_file_patterns,
        repository_discovery: loadDirectoryForm.repository_discovery,
        identity: loadDirectoryForm.identity
      });
      
      // Reset form
      loadDirectoryForm = { 
        path: '', 
        skip_gitignore: false, 
        ignore_file_patterns: [],
        repository_discovery: true,
        identity: 'auto'
      };
      showLoadDirectoryDialog = false;
      
      // Navigate to the project
      goto(`/projects/${project.id}`);
    } catch (error) {
      console.error('Failed to load directory:', error);
    } finally {
      loading = false;
    }
  }

  async function loadFile() {
    if (!$apiService) return;

    try {
      loading = true;
      const project = await projects.loadFile($apiService, loadFileForm.path, {
        identity: loadFileForm.identity
      });
      
      // Reset form
      loadFileForm = { 
        path: '', 
        identity: 'auto'
      };
      showLoadFileDialog = false;
      
      // Navigate to the project
      goto(`/projects/${project.id}`);
    } catch (error) {
      console.error('Failed to load file:', error);
    } finally {
      loading = false;
    }
  }

  async function deleteProject(project: Project) {
    if (!$apiService) return;

    try {
      loading = true;
      // Implement project deletion API call
      await $apiService.delete(`/projects/${project.id}`);
      
      // Remove from local state
      projects.reset(); // This would need to be updated to handle individual removal
    } catch (error) {
      console.error('Failed to delete project:', error);
    } finally {
      loading = false;
    }
  }

  function addIgnorePattern() {
    if (ignorePatternInput.trim() && !loadDirectoryForm.ignore_file_patterns.includes(ignorePatternInput.trim())) {
      loadDirectoryForm.ignore_file_patterns = [...loadDirectoryForm.ignore_file_patterns, ignorePatternInput.trim()];
      ignorePatternInput = '';
    }
  }

  function removeIgnorePattern(pattern: string) {
    loadDirectoryForm.ignore_file_patterns = loadDirectoryForm.ignore_file_patterns.filter(p => p !== pattern);
  }

  function clearFilters() {
    searchQuery = '';
    filterStatus = 'all';
  }

  function getStatusIcon(status: string) {
    switch (status) {
      case 'loading':
        return Loader2;
      case 'loaded':
        return CheckCircle;
      case 'error':
        return XCircle;
      default:
        return AlertCircle;
    }
  }

  function getStatusBadgeVariant(status: string) {
    switch (status) {
      case 'loading':
        return 'default';
      case 'loaded':
        return 'secondary';
      case 'error':
        return 'destructive';
      default:
        return 'outline';
    }
  }

  function getTypeIcon(type: string) {
    switch (type) {
      case 'directory':
        return FolderOpen;
      case 'file':
        return FileText;
      default:
        return File;
    }
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
</script>

<div class="space-y-6">
  <!-- Header -->
  <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
    <div>
      <h1 class="text-2xl font-bold text-foreground">Projects</h1>
      <p class="text-muted-foreground">
        Load and manage literate programming projects from directories and files
      </p>
    </div>
    
    <div class="flex items-center gap-2">
      <Dialog bind:open={showLoadFileDialog}>
        <DialogTrigger>
          <Button variant="outline">
            <File class="mr-2 h-4 w-4" />
            Load File
          </Button>
        </DialogTrigger>
      </Dialog>
      
      <Dialog bind:open={showLoadDirectoryDialog}>
        <DialogTrigger>
          <Button>
            <Folder class="mr-2 h-4 w-4" />
            Load Directory
          </Button>
        </DialogTrigger>
      </Dialog>
    </div>
  </div>

  <!-- Filters and Search -->
  <Card>
    <CardContent class="p-4">
      <div class="flex flex-col gap-4 md:flex-row md:items-center">
        <!-- Search -->
        <div class="flex-1">
          <div class="relative">
            <Search class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              placeholder="Search projects..."
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
            <option value="loading">Loading</option>
            <option value="loaded">Loaded</option>
            <option value="error">Error</option>
          </select>
          
          <!-- Sort -->
          <select
            bind:value={sortBy}
            class="flex h-9 w-auto rounded-md border border-input bg-background px-3 py-1 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
          >
            <option value="updated_at">Last Updated</option>
            <option value="created_at">Date Created</option>
            <option value="name">Name</option>
            <option value="status">Status</option>
            <option value="type">Type</option>
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

  <!-- Projects Display -->
  {#if viewMode === 'grid'}
    <!-- Grid View -->
    <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
      {#each filteredProjects as project (project.id)}
        <Card class="cursor-pointer transition-all hover:shadow-md">
          <CardHeader class="pb-3">
            <div class="flex items-start justify-between">
              <div class="flex items-start space-x-3 min-w-0">
                <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10">
                  <svelte:component this={getTypeIcon(project.type)} class="h-5 w-5 text-primary" />
                </div>
                <div class="min-w-0">
                  <CardTitle class="text-lg truncate">{project.name}</CardTitle>
                  <div class="flex items-center space-x-2 mt-1">
                    <Badge variant={getStatusBadgeVariant(project.status)} class="text-xs">
                      <svelte:component this={getStatusIcon(project.status)} class="mr-1 h-3 w-3 {project.status === 'loading' ? 'animate-spin' : ''}" />
                      {project.status}
                    </Badge>
                    <Badge variant="outline" class="text-xs">
                      {project.type}
                    </Badge>
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
                  <DropdownMenuItem onclick={() => goto(`/projects/${project.id}/edit`)}>
                    <Eye class="mr-2 h-4 w-4" />
                    View Details
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
                          This action cannot be undone. This will permanently delete the project
                          "{project.name}" and all its parsed data.
                        </AlertDialogDescription>
                      </AlertDialogHeader>
                      <AlertDialogFooter>
                        <AlertDialogCancel>Cancel</AlertDialogCancel>
                        <AlertDialogAction onclick={() => deleteProject(project)}>
                          Delete Project
                        </AlertDialogAction>
                      </AlertDialogFooter>
                    </AlertDialogContent>
                  </AlertDialog>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          </CardHeader>
          
          <CardContent>
            <div class="space-y-3">
              <div class="text-sm text-muted-foreground">
                <div class="flex items-center mb-1">
                  <FolderOpen class="mr-1 h-4 w-4" />
                  {project.path}
                </div>
              </div>
              
              <!-- Statistics -->
              <div class="grid grid-cols-2 gap-4 text-sm">
                <div class="flex items-center">
                  <FileText class="mr-1 h-4 w-4" />
                  {project.document_count || 0} docs
                </div>
                <div class="flex items-center">
                  <Code2 class="mr-1 h-4 w-4" />
                  {project.task_count || 0} tasks
                </div>
              </div>
              
              <div class="text-sm text-muted-foreground">
                <div class="flex items-center">
                  <Calendar class="mr-1 h-4 w-4" />
                  Created {formatDate(project.created_at)}
                </div>
              </div>
              
              <Button 
                class="w-full" 
                variant="outline"
                onclick={() => goto(`/projects/${project.id}/edit`)}
              >
                <Eye class="mr-2 h-4 w-4" />
                View Project
              </Button>
            </div>
          </CardContent>
        </Card>
      {/each}

      {#if filteredProjects.length === 0 && !isLoading}
        <div class="col-span-full">
          <Card class="border-dashed">
            <CardContent class="flex flex-col items-center justify-center py-12">
              <FolderOpen class="h-12 w-12 text-muted-foreground mb-4" />
              <h3 class="text-lg font-semibold mb-2">
                {searchQuery || filterStatus !== 'all' ? 'No projects found' : 'No projects yet'}
              </h3>
              <p class="text-muted-foreground text-center mb-4">
                {searchQuery || filterStatus !== 'all'
                  ? 'Try adjusting your search or filters'
                  : 'Load your first directory or file to create a project'
                }
              </p>
              {#if !searchQuery && filterStatus === 'all'}
                <div class="flex gap-2">
                  <Button variant="outline" onclick={() => (showCreateDialog = false)}>
                    <File class="mr-2 h-4 w-4" />
                    Load File
                  </Button>
                  <Button onclick={() => (showCreateDialog = true)}>
                    <Folder class="mr-2 h-4 w-4" />
                    Load Directory
                  </Button>
                </div>
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
          {#each filteredProjects as project (project.id)}
            <div class="flex items-center justify-between p-4 hover:bg-muted/50">
              <div class="flex items-center space-x-4 min-w-0">
                <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10">
                  <svelte:component this={getTypeIcon(project.type)} class="h-4 w-4 text-primary" />
                </div>
                
                <div class="min-w-0 flex-1">
                  <div class="flex items-center space-x-2">
                    <h3 class="font-medium truncate">{project.name}</h3>
                    <Badge variant={getStatusBadgeVariant(project.status)} class="text-xs">
                      <svelte:component this={getStatusIcon(project.status)} class="mr-1 h-3 w-3 {project.status === 'loading' ? 'animate-spin' : ''}" />
                      {project.status}
                    </Badge>
                    <Badge variant="outline" class="text-xs">
                      {project.type}
                    </Badge>
                  </div>
                  <p class="text-sm text-muted-foreground truncate">{project.path}</p>
                  
                  <div class="flex items-center space-x-4 mt-1 text-xs text-muted-foreground">
                    <span>{project.document_count || 0} docs</span>
                    <span>{project.task_count || 0} tasks</span>
                  </div>
                </div>
              </div>
              
              <div class="flex items-center space-x-4 text-sm text-muted-foreground">
                <div class="text-right">
                  <div>{formatDate(project.updated_at)}</div>
                  <div class="text-xs">{project.user?.name || 'Unknown'}</div>
                </div>
                
                <div class="flex items-center space-x-1">
                  <Button
                    variant="ghost"
                    size="sm"
                    onclick={() => goto(`/projects/${project.id}`)}
                  >
                    <Eye class="h-4 w-4" />
                  </Button>
                  
                  <DropdownMenu>
                    <DropdownMenuTrigger>
                      <Button variant="ghost" size="sm">
                        <MoreHorizontal class="h-4 w-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
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
                              This action cannot be undone. This will permanently delete the project
                              "{project.name}" and all its parsed data.
                            </AlertDialogDescription>
                          </AlertDialogHeader>
                          <AlertDialogFooter>
                            <AlertDialogCancel>Cancel</AlertDialogCancel>
                            <AlertDialogAction onclick={() => deleteProject(project)}>
                              Delete Project
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
          
          {#if filteredProjects.length === 0 && !isLoading}
            <div class="flex flex-col items-center justify-center py-12">
              <FolderOpen class="h-12 w-12 text-muted-foreground mb-4" />
              <h3 class="text-lg font-semibold mb-2">
                {searchQuery || filterStatus !== 'all' ? 'No projects found' : 'No projects yet'}
              </h3>
              <p class="text-muted-foreground text-center mb-4">
                {searchQuery || filterStatus !== 'all'
                  ? 'Try adjusting your search or filters'
                  : 'Load your first directory or file to create a project'
                }
              </p>
              {#if !searchQuery && filterStatus === 'all'}
                <div class="flex gap-2">
                  <Button variant="outline" onclick={() => (showLoadFileDialog = true)}>
                    <File class="mr-2 h-4 w-4" />
                    Load File
                  </Button>
                  <Button onclick={() => (showLoadDirectoryDialog = true)}>
                    <Folder class="mr-2 h-4 w-4" />
                    Load Directory
                  </Button>
                </div>
              {/if}
            </div>
          {/if}
        </div>
      </CardContent>
    </Card>
  {/if}
</div>

<!-- Load Directory Dialog -->
<Dialog bind:open={showLoadDirectoryDialog}>
  <DialogContent class="sm:max-w-[500px]">
    <DialogHeader>
      <DialogTitle>Load Directory Project</DialogTitle>
      <DialogDescription>
        Load a literate programming project from a directory.
      </DialogDescription>
    </DialogHeader>
    <div class="space-y-4 py-4">
      <div class="space-y-2">
        <Label for="dir-path">Directory Path</Label>
        <Input
          id="dir-path"
          bind:value={loadDirectoryForm.path}
          placeholder="/path/to/project"
          required
        />
      </div>
      
      <div class="space-y-2">
        <Label for="identity-mode">Identity Mode</Label>
        <select
          id="identity-mode"
          bind:value={loadDirectoryForm.identity}
          class="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
        >
          <option value="auto">Auto</option>
          <option value="document">Document</option>
          <option value="cell">Cell</option>
        </select>
      </div>
      
      <div class="space-y-2">
        <Label>Ignore Patterns</Label>
        <div class="space-y-2">
          <div class="flex space-x-2">
            <Input
              bind:value={ignorePatternInput}
              placeholder="Add ignore pattern (e.g., *.log)"
              onkeydown={(e) => e.key === 'Enter' && (e.preventDefault(), addIgnorePattern())}
            />
            <Button type="button" variant="outline" size="sm" onclick={addIgnorePattern}>
              Add
            </Button>
          </div>
          
          {#if loadDirectoryForm.ignore_file_patterns.length > 0}
            <div class="flex flex-wrap gap-2">
              {#each loadDirectoryForm.ignore_file_patterns as pattern}
                <Badge variant="secondary" class="cursor-pointer" onclick={() => removeTag(tag)}>
                  {pattern}
                  <button class="ml-1 text-xs" onclick={(e) => { e.stopPropagation(); removeTag(tag); }}>×</button>
                </Badge>
              {/each}
            </div>
          {/if}
        </div>
      </div>
      
      <div class="space-y-3">
        <div class="flex items-center space-x-2">
          <input 
            type="checkbox" 
            id="skip-gitignore"
            bind:checked={loadDirectoryForm.skip_gitignore}
            class="rounded border-gray-300"
          />
          <Label for="skip-gitignore" class="text-sm">Skip .gitignore files</Label>
        </div>
        
        <div class="flex items-center space-x-2">
          <input 
            type="checkbox" 
            id="repository-discovery"
            bind:checked={loadDirectoryForm.repository_discovery}
            class="rounded border-gray-300"
          />
          <Label for="repository-discovery" class="text-sm">Enable repository discovery</Label>
        </div>
      </div>
    </div>
    <DialogFooter>
      <Button variant="outline" onclick={() => (showLoadDirectoryDialog = false)}>
        Cancel
      </Button>
      <Button onclick={loadDirectory} disabled={!loadDirectoryForm.path.trim() || isLoading}>
        {#if isLoading}
          <Loader2 class="mr-2 h-4 w-4 animate-spin" />
          Loading...
        {:else}
          <Folder class="mr-2 h-4 w-4" />
          Load Directory
        {/if}
      </Button>
    </DialogFooter>
  </DialogContent>
</Dialog>

<!-- Load File Dialog -->
<Dialog bind:open={showLoadFileDialog}>
  <DialogContent class="sm:max-w-[425px]">
    <DialogHeader>
      <DialogTitle>Load File Project</DialogTitle>
      <DialogDescription>
        Load a literate programming project from a single file.
      </DialogDescription>
    </DialogHeader>
    <div class="space-y-4 py-4">
      <div class="space-y-2">
        <Label for="file-path">File Path</Label>
        <Input
          id="file-path"
          bind:value={loadFileForm.path}
          placeholder="/path/to/file.md"
          required
        />
      </div>
      
      <div class="space-y-2">
        <Label for="file-identity-mode">Identity Mode</Label>
        <select
          id="file-identity-mode"
          bind:value={loadFileForm.identity}
          class="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
        >
          <option value="auto">Auto</option>
          <option value="document">Document</option>
          <option value="cell">Cell</option>
        </select>
      </div>
    </div>
    <DialogFooter>
      <Button variant="outline" onclick={() => (showLoadFileDialog = false)}>
        Cancel
      </Button>
      <Button onclick={loadFile} disabled={!loadFileForm.path.trim() || isLoading}>
        {#if isLoading}
          <Loader2 class="mr-2 h-4 w-4 animate-spin" />
          Loading...
        {:else}
          <File class="mr-2 h-4 w-4" />
          Load File
        {/if}
      </Button>
    </DialogFooter>
  </DialogContent>
</Dialog>