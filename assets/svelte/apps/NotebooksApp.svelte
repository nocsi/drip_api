<script lang="ts">
  import { onMount, createEventDispatcher } from 'svelte';
  import type { LiveSvelteProps } from '../liveSvelte';
  import { Button } from '../ui/button';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
  import { Badge } from '../ui/badge';
  import { Input } from '../ui/input';
  import { Label } from '../ui/label';
  import { Textarea } from '../ui/textarea';
  import { 
    Dialog, 
    DialogContent, 
    DialogDescription, 
    DialogHeader, 
    DialogTitle 
  } from '../ui/dialog';
  import { 
    DropdownMenu, 
    DropdownMenuContent, 
    DropdownMenuItem, 
    DropdownMenuTrigger,
    DropdownMenuSeparator 
  } from '../ui/dropdown-menu';
  import { Separator } from '../ui/separator';
  import { Progress } from '../ui/progress';
  import {
    BookOpen,
    Plus,
    Search,
    Filter,
    Grid3X3,
    List,
    MoreHorizontal,
    Edit,
    Trash2,
    Copy,
    Download,
    Play,
    Square,
    RotateCcw,
    Eye,
    Clock,
    User,
    Calendar,
    FolderOpen,
    SortAsc,
    SortDesc,
    ChevronDown,
    AlertCircle,
    CheckCircle,
    XCircle,
    Loader2,
    Code,
    Terminal,
    Users,
    Zap
  } from '@lucide/svelte';

  // Props from LiveView
  interface Props {
    currentUser: any;
    currentTeam: any;
    workspace?: any;
    notebooks?: any[];
    selectedNotebook?: any;
    viewMode?: string;
    sortBy?: string;
    sortOrder?: string;
    searchQuery?: string;
    apiToken?: string;
    csrfToken?: string;
    apiBaseUrl?: string;
  }

  let {
    currentUser,
    currentTeam,
    workspace = null,
    notebooks = [],
    selectedNotebook = null,
    viewMode = 'grid',
    sortBy = 'updated_at',
    sortOrder = 'desc',
    searchQuery = '',
    apiToken = '',
    csrfToken = '',
    apiBaseUrl = '/api/v1'
  }: Props = $props();

  // Component state
  let searchInput = $state(searchQuery);
  let showSidebar = $state(true);
  let loading = $state(false);
  let error = $state(null);
  let selectedNotebooks = $state(new Set<string>());
  let showCreateModal = $state(false);
  let showExecutionModal = $state(false);
  let filteredNotebooks = $state(notebooks);
  let currentFilter = $state('all');
  let executingNotebooks = $state(new Set<string>());
  let executionProgress = $state(new Map<string, number>());

  // Form state
  let createForm = $state({
    title: '',
    description: '',
    workspace_id: workspace?.id || '',
    document_id: '',
    initial_content: ''
  });

  let executionForm = $state({
    notebook_id: '',
    environment_variables: {} as Record<string, string>,
    timeout_seconds: 300
  });

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

    // Notebook operations
    async listNotebooks(params = {}) {
      const queryParams = new URLSearchParams(params);
      const endpoint = workspace 
        ? `/workspaces/${workspace.id}/notebooks?${queryParams}`
        : `/notebooks?${queryParams}`;
      return this.request(endpoint);
    },

    async getNotebook(id: string) {
      return this.request(`/notebooks/${id}`);
    },

    async createFromDocument(documentId: string, notebookData: any) {
      return this.request(`/documents/${documentId}/notebooks`, {
        method: 'POST',
        body: JSON.stringify({ notebook: notebookData })
      });
    },

    async updateNotebook(id: string, notebookData: any) {
      return this.request(`/notebooks/${id}`, {
        method: 'PUT',
        body: JSON.stringify({ notebook: notebookData })
      });
    },

    async deleteNotebook(id: string) {
      return this.request(`/notebooks/${id}`, {
        method: 'DELETE'
      });
    },

    async duplicateNotebook(id: string, options = {}) {
      return this.request(`/notebooks/${id}/duplicate`, {
        method: 'POST',
        body: JSON.stringify({ options })
      });
    },

    async executeNotebook(id: string, options = {}) {
      return this.request(`/notebooks/${id}/execute`, {
        method: 'POST',
        body: JSON.stringify(options)
      });
    },

    async stopExecution(id: string) {
      return this.request(`/notebooks/${id}/stop_execution`, {
        method: 'POST'
      });
    },

    async resetExecution(id: string) {
      return this.request(`/notebooks/${id}/reset_execution`, {
        method: 'POST'
      });
    },

    async executeTask(notebookId: string, taskId: string, options = {}) {
      return this.request(`/notebooks/${notebookId}/tasks/${taskId}/execute`, {
        method: 'POST',
        body: JSON.stringify(options)
      });
    },

    async toggleCollaborativeMode(id: string) {
      return this.request(`/notebooks/${id}/toggle_collaborative_mode`, {
        method: 'POST'
      });
    }
  };

  // Reactive filtering and sorting
  $effect(() => {
    filterAndSortNotebooks();
  });

  function filterAndSortNotebooks() {
    let filtered = [...notebooks];

    // Apply search filter
    if (searchInput.trim()) {
      const query = searchInput.toLowerCase();
      filtered = filtered.filter(notebook => 
        notebook.title?.toLowerCase().includes(query) ||
        notebook.description?.toLowerCase().includes(query) ||
        notebook.language?.toLowerCase().includes(query)
      );
    }

    // Apply status filter
    if (currentFilter !== 'all') {
      filtered = filtered.filter(notebook => {
        switch (currentFilter) {
          case 'running':
            return notebook.status === 'running' || executingNotebooks.has(notebook.id);
          case 'completed':
            return notebook.status === 'completed';
          case 'error':
            return notebook.status === 'error';
          case 'idle':
            return notebook.status === 'idle' || !notebook.status;
          default:
            return true;
        }
      });
    }

    // Sort notebooks
    filtered.sort((a, b) => {
      let aVal, bVal;

      switch (sortBy) {
        case 'title':
          aVal = a.title?.toLowerCase() || '';
          bVal = b.title?.toLowerCase() || '';
          break;
        case 'updated_at':
          aVal = new Date(a.updated_at || 0);
          bVal = new Date(b.updated_at || 0);
          break;
        case 'created_at':
          aVal = new Date(a.created_at || 0);
          bVal = new Date(b.created_at || 0);
          break;
        case 'status':
          aVal = a.status || 'idle';
          bVal = b.status || 'idle';
          break;
        default:
          return 0;
      }

      const multiplier = sortOrder === 'asc' ? 1 : -1;
      if (aVal < bVal) return -1 * multiplier;
      if (aVal > bVal) return 1 * multiplier;
      return 0;
    });

    filteredNotebooks = filtered;
  }

  // Event handlers
  async function handleSearch() {
    searchQuery = searchInput;
    dispatch('search', { query: searchQuery });
    await refreshNotebooks();
  }

  async function handleCreateNotebook() {
    if (!createForm.title.trim()) {
      error = 'Notebook title is required';
      return;
    }

    loading = true;
    try {
      let response;
      if (createForm.document_id) {
        response = await apiClient.createFromDocument(createForm.document_id, createForm);
      } else {
        // Create standalone notebook - this would need a dedicated endpoint
        response = await apiClient.request('/notebooks', {
          method: 'POST',
          body: JSON.stringify({ notebook: createForm })
        });
      }
      
      notebooks = [response.data, ...notebooks];
      showCreateModal = false;
      createForm = {
        title: '',
        description: '',
        workspace_id: workspace?.id || '',
        document_id: '',
        initial_content: ''
      };
      dispatch('notebookCreated', { notebook: response.data });
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  async function handleExecuteNotebook(notebook: any) {
    executingNotebooks.add(notebook.id);
    executingNotebooks = executingNotebooks;
    
    try {
      const response = await apiClient.executeNotebook(notebook.id, {
        environment_variables: executionForm.environment_variables,
        timeout_seconds: executionForm.timeout_seconds
      });
      
      // Update notebook status
      const index = notebooks.findIndex(n => n.id === notebook.id);
      if (index !== -1) {
        notebooks[index] = response.data;
        notebooks = notebooks;
      }
      
      dispatch('notebookExecuted', { notebook: response.data });
    } catch (err) {
      error = err.message;
    } finally {
      executingNotebooks.delete(notebook.id);
      executingNotebooks = executingNotebooks;
    }
  }

  async function handleStopExecution(notebook: any) {
    try {
      const response = await apiClient.stopExecution(notebook.id);
      
      const index = notebooks.findIndex(n => n.id === notebook.id);
      if (index !== -1) {
        notebooks[index] = response.data;
        notebooks = notebooks;
      }
      
      executingNotebooks.delete(notebook.id);
      executingNotebooks = executingNotebooks;
      
      dispatch('executionStopped', { notebook: response.data });
    } catch (err) {
      error = err.message;
    }
  }

  async function handleResetExecution(notebook: any) {
    try {
      const response = await apiClient.resetExecution(notebook.id);
      
      const index = notebooks.findIndex(n => n.id === notebook.id);
      if (index !== -1) {
        notebooks[index] = response.data;
        notebooks = notebooks;
      }
      
      dispatch('executionReset', { notebook: response.data });
    } catch (err) {
      error = err.message;
    }
  }

  async function handleDeleteNotebook(notebook: any) {
    if (!confirm(`Are you sure you want to delete "${notebook.title}"?`)) {
      return;
    }

    loading = true;
    try {
      await apiClient.deleteNotebook(notebook.id);
      notebooks = notebooks.filter(n => n.id !== notebook.id);
      dispatch('notebookDeleted', { notebook });
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  async function handleDuplicateNotebook(notebook: any) {
    loading = true;
    try {
      const response = await apiClient.duplicateNotebook(notebook.id);
      notebooks = [response.data, ...notebooks];
      dispatch('notebookDuplicated', { original: notebook, duplicate: response.data });
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  function handleViewNotebook(notebook: any) {
    dispatch('viewNotebook', { notebook });
  }

  function handleEditNotebook(notebook: any) {
    dispatch('editNotebook', { notebook });
  }

  function toggleNotebookSelection(notebook: any) {
    if (selectedNotebooks.has(notebook.id)) {
      selectedNotebooks.delete(notebook.id);
    } else {
      selectedNotebooks.add(notebook.id);
    }
    selectedNotebooks = selectedNotebooks;
  }

  function selectAllNotebooks() {
    selectedNotebooks = new Set(filteredNotebooks.map(n => n.id));
  }

  function clearSelection() {
    selectedNotebooks = new Set();
  }

  async function handleBulkDelete() {
    if (selectedNotebooks.size === 0) return;

    if (!confirm(`Are you sure you want to delete ${selectedNotebooks.size} notebook(s)?`)) {
      return;
    }

    loading = true;
    try {
      await Promise.all(
        Array.from(selectedNotebooks).map(id => apiClient.deleteNotebook(id))
      );
      notebooks = notebooks.filter(n => !selectedNotebooks.has(n.id));
      clearSelection();
      dispatch('notebooksDeleted', { count: selectedNotebooks.size });
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  function handleSortChange(field: string) {
    if (sortBy === field) {
      sortOrder = sortOrder === 'asc' ? 'desc' : 'asc';
    } else {
      sortBy = field;
      sortOrder = 'desc';
    }
    dispatch('sortChanged', { sortBy, sortOrder });
  }

  function toggleViewMode() {
    viewMode = viewMode === 'grid' ? 'list' : 'grid';
    dispatch('viewModeChanged', { viewMode });
  }

  async function refreshNotebooks() {
    loading = true;
    try {
      const response = await apiClient.listNotebooks({
        search: searchQuery,
        sort_by: sortBy,
        sort_order: sortOrder,
        status: currentFilter !== 'all' ? currentFilter : undefined
      });
      notebooks = response.data || [];
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  function formatDate(dateString: string): string {
    if (!dateString) return 'Never';
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function getStatusIcon(status: string) {
    switch (status) {
      case 'running': return Loader2;
      case 'completed': return CheckCircle;
      case 'error': return XCircle;
      default: return BookOpen;
    }
  }

  function getStatusColor(status: string): string {
    switch (status) {
      case 'running': return 'bg-blue-100 text-blue-800';
      case 'completed': return 'bg-green-100 text-green-800';
      case 'error': return 'bg-red-100 text-red-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  }

  function isNotebookExecuting(notebook: any): boolean {
    return executingNotebooks.has(notebook.id) || notebook.status === 'running';
  }

  onMount(() => {
    refreshNotebooks();
  });
</script>

<div class="flex h-full bg-background">
  {#if showSidebar}
    <div class="w-64 border-r bg-muted/30 flex flex-col">
      <!-- Workspace Info -->
      {#if workspace}
        <div class="p-4 border-b">
          <div class="flex items-center space-x-2">
            <FolderOpen class="w-5 h-5 text-primary" />
            <div class="flex-1 min-w-0">
              <h2 class="font-semibold truncate">{workspace.name}</h2>
              <p class="text-xs text-muted-foreground truncate">
                {notebooks.length} notebooks
              </p>
            </div>
          </div>
        </div>
      {/if}

      <!-- Filters -->
      <div class="p-4 space-y-4">
        <div>
          <h3 class="text-sm font-medium text-gray-900 mb-2">Status</h3>
          <div class="space-y-1">
            {#each [
              { key: 'all', label: 'All Notebooks', count: notebooks.length },
              { key: 'idle', label: 'Idle', count: notebooks.filter(n => !n.status || n.status === 'idle').length },
              { key: 'running', label: 'Running', count: notebooks.filter(n => n.status === 'running').length },
              { key: 'completed', label: 'Completed', count: notebooks.filter(n => n.status === 'completed').length },
              { key: 'error', label: 'Error', count: notebooks.filter(n => n.status === 'error').length }
            ] as statusFilter}
              <button
                class="w-full text-left px-2 py-1 text-sm rounded hover:bg-muted {currentFilter === statusFilter.key ? 'bg-primary text-primary-foreground' : ''}"
                onclick={() => currentFilter = statusFilter.key}
              >
                {statusFilter.label} ({statusFilter.count})
              </button>
            {/each}
          </div>
        </div>

        <!-- Execution Stats -->
        {#if notebooks.length > 0}
          <Separator />
          <div>
            <h3 class="text-sm font-medium text-gray-900 mb-2">Quick Stats</h3>
            <div class="space-y-2 text-xs text-muted-foreground">
              <div class="flex justify-between">
                <span>Total Tasks:</span>
                <span>{notebooks.reduce((sum, n) => sum + (n.task_count || 0), 0)}</span>
              </div>
              <div class="flex justify-between">
                <span>Avg Execution Time:</span>
                <span>
                  {notebooks.filter(n => n.avg_execution_time).length > 0 
                    ? Math.round(notebooks.reduce((sum, n) => sum + (n.avg_execution_time || 0), 0) / notebooks.filter(n => n.avg_execution_time).length) + 's'
                    : 'N/A'
                  }
                </span>
              </div>
            </div>
          </div>
        {/if}
      </div>

      <Separator />

      <!-- Quick Actions -->
      <div class="p-4 space-y-2">
        <Button class="w-full justify-start" size="sm" onclick={() => showCreateModal = true}>
          <Plus class="w-4 h-4 mr-2" />
          New Notebook
        </Button>
        <Button variant="outline" class="w-full justify-start" size="sm" onclick={() => showExecutionModal = true}>
          <Play class="w-4 h-4 mr-2" />
          Batch Execute
        </Button>
      </div>
    </div>
  {/if}

  <!-- Main Content -->
  <div class="flex-1 flex flex-col min-w-0">
    <!-- Header -->
    <div class="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div class="p-4 space-y-4">
        <!-- Search -->
        <div class="flex-1 max-w-md">
          <div class="relative">
            <Search class="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <Input
              placeholder="Search notebooks..."
              bind:value={searchInput}
              oninput={handleSearch}
              class="pl-10"
            />
          </div>
        </div>

        <!-- Controls -->
        <div class="flex items-center justify-between gap-4">
          <div class="flex items-center space-x-2">
            {#if selectedNotebooks.size > 0}
              <div class="flex items-center space-x-2">
                <span class="text-sm text-muted-foreground">
                  {selectedNotebooks.size} selected
                </span>
                <Button size="sm" variant="outline" onclick={clearSelection}>
                  Clear
                </Button>
                <Button size="sm" variant="destructive" onclick={handleBulkDelete}>
                  <Trash2 class="w-4 h-4 mr-1" />
                  Delete
                </Button>
              </div>
              <Separator orientation="vertical" class="h-6" />
            {/if}
          </div>

          <div class="flex items-center space-x-2">
            <!-- View Mode -->
            <div class="flex items-center space-x-1">
              <Button
                size="sm"
                variant={viewMode === 'grid' ? 'default' : 'outline'}
                onclick={toggleViewMode}
              >
                <Grid3X3 class="w-4 h-4" />
              </Button>
              <Button
                size="sm"
                variant={viewMode === 'list' ? 'default' : 'outline'}
                onclick={toggleViewMode}
              >
                <List class="w-4 h-4" />
              </Button>
            </div>

            <!-- Sort -->
            <DropdownMenu>
              <DropdownMenuTrigger>
                <Button size="sm" variant="outline">
                  {#if sortOrder === 'asc'}
                    <SortAsc class="w-4 h-4 mr-1" />
                  {:else}
                    <SortDesc class="w-4 h-4 mr-1" />
                  {/if}
                  Sort
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent>
                <DropdownMenuItem onclick={() => handleSortChange('title')}>
                  Title
                </DropdownMenuItem>
                <DropdownMenuItem onclick={() => handleSortChange('updated_at')}>
                  Last Modified
                </DropdownMenuItem>
                <DropdownMenuItem onclick={() => handleSortChange('created_at')}>
                  Created
                </DropdownMenuItem>
                <DropdownMenuItem onclick={() => handleSortChange('status')}>
                  Status
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>

            <Button size="sm" onclick={() => showCreateModal = true}>
              <Plus class="w-4 h-4 mr-1" />
              New
            </Button>
          </div>
        </div>
      </div>
    </div>

    <!-- Error Display -->
    {#if error}
      <div class="p-4">
        <div class="flex items-center space-x-2 text-red-600 bg-red-50 border border-red-200 rounded p-3">
          <AlertCircle class="w-4 h-4" />
          <span class="text-sm">{error}</span>
          <Button size="sm" variant="ghost" onclick={() => error = null}>×</Button>
        </div>
      </div>
    {/if}

    <!-- Content -->
    <div class="flex-1 overflow-auto p-4">
      {#if loading && filteredNotebooks.length === 0}
        <div class="flex items-center justify-center py-12">
          <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-primary"></div>
          <span class="ml-2 text-sm text-muted-foreground">Loading notebooks...</span>
        </div>
      {:else if filteredNotebooks.length === 0}
        <!-- Empty State -->
        <div class="flex flex-col items-center justify-center py-12 text-center">
          <BookOpen class="w-16 h-16 text-muted-foreground mb-4" />
          <h3 class="text-lg font-semibold mb-2">
            {searchInput ? 'No notebooks found' : 'No notebooks yet'}
          </h3>
          <p class="text-muted-foreground mb-4 max-w-md">
            {searchInput
              ? `No notebooks match "${searchInput}". Try adjusting your search.`
              : 'Start by creating your first notebook for executable code and documentation.'
            }
          </p>
          {#if !searchInput}
            <Button onclick={() => showCreateModal = true}>
              <Plus class="w-4 h-4 mr-2" />
              Create Notebook
            </Button>
          {/if}
        </div>
      {:else if viewMode === 'grid'}
        <!-- Grid View -->
        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
          {#each filteredNotebooks as notebook (notebook.id)}
            {@const isSelected = selectedNotebooks.has(notebook.id)}
            {@const StatusIcon = getStatusIcon(notebook.status)}
            {@const isExecuting = isNotebookExecuting(notebook)}
            <Card
              class="cursor-pointer transition-colors hover:bg-muted/50 {isSelected ? 'ring-2 ring-primary' : ''}"
              onclick={() => handleViewNotebook(notebook)}
            >
              <CardHeader class="pb-2">
                <div class="flex items-start justify-between">
                  <div class="flex items-center space-x-2 min-w-0 flex-1">
                    <BookOpen class="w-8 h-8 text-primary" />
                    <div class="min-w-0 flex-1">
                      <CardTitle class="text-sm truncate" title={notebook.title}>
                        {notebook.title}
                      </CardTitle>
                      <div class="flex items-center space-x-2 mt-1">
                        <Badge variant="outline" class="text-xs {getStatusColor(notebook.status || 'idle')}">
                          <StatusIcon class="w-3 h-3 mr-1 {isExecuting ? 'animate-spin' : ''}" />
                          {notebook.status || 'idle'}
                        </Badge>
                        {#if notebook.task_count}
                          <Badge variant="secondary" class="text-xs">
                            {notebook.task_count} tasks
                          </Badge>
                        {/if}
                      </div>
                    </div>
                  </div>

                  <div class="flex items-center space-x-1">
                    <input
                      type="checkbox"
                      checked={isSelected}
                      onchange={(e) => {
                        const target = e.target as HTMLInputElement;
                        if (target.checked) {
                          selectedNotebooks.add(notebook.id);
                        } else {
                          selectedNotebooks.delete(notebook.id);
                        }
                        selectedNotebooks = selectedNotebooks;
                      }}
                      onclick={(e) => e.stopPropagation()}
                      class="rounded"
                    />
                    <DropdownMenu>
                      <DropdownMenuTrigger>
                        <Button
                          variant="ghost"
                          size="sm"
                          class="h-8 w-8 p-0"
                          onclick={(e) => e.stopPropagation()}
                        >
                          <MoreHorizontal class="w-4 h-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuItem onclick={() => handleViewNotebook(notebook)}>
                          <Eye class="w-4 h-4 mr-2" />
                          View
                        </DropdownMenuItem>
                        <DropdownMenuItem onclick={() => handleEditNotebook(notebook)}>
                          <Edit class="w-4 h-4 mr-2" />
                          Edit
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        {#if isExecuting}
                          <DropdownMenuItem onclick={() => handleStopExecution(notebook)}>
                            <Square class="w-4 h-4 mr-2" />
                            Stop
                          </DropdownMenuItem>
                        {:else}
                          <DropdownMenuItem onclick={() => handleExecuteNotebook(notebook)}>
                            <Play class="w-4 h-4 mr-2" />
                            Execute
                          </DropdownMenuItem>
                        {/if}
                        <DropdownMenuItem onclick={() => handleResetExecution(notebook)}>
                          <RotateCcw class="w-4 h-4 mr-2" />
                          Reset
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem onclick={() => handleDuplicateNotebook(notebook)}>
                          <Copy class="w-4 h-4 mr-2" />
                          Duplicate
                        </DropdownMenuItem>
                        <DropdownMenuItem onclick={() => handleDeleteNotebook(notebook)}>
                          <Trash2 class="w-4 h-4 mr-2" />
                          Delete
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </div>
                </div>
              </CardHeader>

              <CardContent class="pt-0">
                <div class="space-y-2 text-xs text-muted-foreground">
                  <div class="flex items-center space-x-1">
                    <Calendar class="w-3 h-3" />
                    <span>{formatDate(notebook.updated_at)}</span>
                  </div>
                  {#if notebook.description}
                    <div class="line-clamp-2" title={notebook.description}>
                      {notebook.description}
                    </div>
                  {/if}
                  {#if notebook.language}
                    <div class="flex items-center space-x-1">
                      <Code class="w-3 h-3" />
                      <span class="capitalize">{notebook.language}</span>
                    </div>
                  {/if}
                  {#if notebook.collaborative_mode}
                    <div class="flex items-center space-x-1 text-blue-600">
                      <Users class="w-3 h-3" />
                      <span>Collaborative</span>
                    </div>
                  {/if}
                </div>
              </CardContent>
            </Card>
          {/each}
        </div>
      {:else}
        <!-- List View -->
        <div class="space-y-1">
          <!-- Header -->
          <div class="grid grid-cols-12 gap-4 p-2 text-sm font-medium text-muted-foreground border-b">
            <div class="col-span-1">
              <input
                type="checkbox"
                checked={selectedNotebooks.size === filteredNotebooks.length && filteredNotebooks.length > 0}
                onchange={(e) => {
                  const target = e.target as HTMLInputElement;
                  if (target.checked) {
                    selectAllNotebooks();
                  } else {
                    clearSelection();
                  }
                }}
                class="rounded"
              />
            </div>
            <div class="col-span-5">Title</div>
            <div class="col-span-2">Status</div>
            <div class="col-span-2">Modified</div>
            <div class="col-span-2">Actions</div>
          </div>

          <!-- Notebook rows -->
          {#each filteredNotebooks as notebook (notebook.id)}
            {@const isSelected = selectedNotebooks.has(notebook.id)}
            {@const StatusIcon = getStatusIcon(notebook.status)}
            {@const isExecuting = isNotebookExecuting(notebook)}
            <div
              class="grid grid-cols-12 gap-4 p-2 rounded hover:bg-muted cursor-pointer {isSelected ? 'bg-muted' : ''}"
              onclick={() => handleViewNotebook(notebook)}
            >
              <div class="col-span-1">
                <input
                  type="checkbox"
                  checked={isSelected}
                  onchange={(e) => {
                    const target = e.target as HTMLInputElement;
                    if (target.checked) {
                      selectedNotebooks.add(notebook.id);
                    } else {
                      selectedNotebooks.delete(notebook.id);
                    }
                    selectedNotebooks = selectedNotebooks;
                  }}
                  onclick={(e) => e.stopPropagation()}
                  class="rounded"
                />
              </div>
              <div class="col-span-5 flex items-center space-x-2 min-w-0">
                <BookOpen class="w-4 h-4 text-primary flex-shrink-0" />
                <span class="truncate" title={notebook.title}>{notebook.title}</span>
              </div>
              <div class="col-span-2">
                <Badge variant="outline" class="text-xs {getStatusColor(notebook.status || 'idle')}">
                  <StatusIcon class="w-3 h-3 mr-1 {isExecuting ? 'animate-spin' : ''}" />
                  {notebook.status || 'idle'}
                </Badge>
              </div>
              <div class="col-span-2 text-sm text-muted-foreground">
                {formatDate(notebook.updated_at)}
              </div>
              <div class="col-span-2 flex items-center justify-between">
                <DropdownMenu>
                  <DropdownMenuTrigger>
                    <Button
                      variant="ghost"
                      size="sm"
                      class="h-8 w-8 p-0"
                      onclick={(e) => e.stopPropagation()}
                    >
                      <MoreHorizontal class="w-4 h-4" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem onclick={() => handleViewNotebook(notebook)}>
                      <Eye class="w-4 h-4 mr-2" />
                      View
                    </DropdownMenuItem>
                    <DropdownMenuItem onclick={() => handleEditNotebook(notebook)}>
                      <Edit class="w-4 h-4 mr-2" />
                      Edit
                    </DropdownMenuItem>
                    <DropdownMenuSeparator />
                    {#if isExecuting}
                      <DropdownMenuItem onclick={() => handleStopExecution(notebook)}>
                        <Square class="w-4 h-4 mr-2" />
                        Stop
                      </DropdownMenuItem>
                    {:else}
                      <DropdownMenuItem onclick={() => handleExecuteNotebook(notebook)}>
                        <Play class="w-4 h-4 mr-2" />
                        Execute
                      </DropdownMenuItem>
                    {/if}
                    <DropdownMenuItem onclick={() => handleResetExecution(notebook)}>
                      <RotateCcw class="w-4 h-4 mr-2" />
                      Reset
                    </DropdownMenuItem>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem onclick={() => handleDuplicateNotebook(notebook)}>
                      <Copy class="w-4 h-4 mr-2" />
                      Duplicate
                    </DropdownMenuItem>
                    <DropdownMenuItem onclick={() => handleDeleteNotebook(notebook)}>
                      <Trash2 class="w-4 h-4 mr-2" />
                      Delete
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            </div>
          {/each}
        </div>
      {/if}
    </div>
  </div>
</div>

<!-- Create Notebook Modal -->
<Dialog open={showCreateModal} onOpenChange={(open) => showCreateModal = open}>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Create New Notebook</DialogTitle>
      <DialogDescription>
        Create a new executable notebook for your code and documentation.
      </DialogDescription>
    </DialogHeader>
    <div class="space-y-4">
      <div>
        <Label for="notebook-title">Title</Label>
        <Input
          id="notebook-title"
          bind:value={createForm.title}
          placeholder="My New Notebook"
        />
      </div>
      <div>
        <Label for="notebook-description">Description (Optional)</Label>
        <Textarea
          id="notebook-description"
          bind:value={createForm.description}
          placeholder="Brief description of the notebook"
        />
      </div>
      <div>
        <Label for="document-id">Create from Document (Optional)</Label>
        <Input
          id="document-id"
          bind:value={createForm.document_id}
          placeholder="Document ID to convert to notebook"
        />
      </div>
      <div class="flex justify-end space-x-3">
        <Button variant="outline" onclick={() => showCreateModal = false}>
          Cancel
        </Button>
        <Button onclick={handleCreateNotebook} disabled={loading}>
          {#if loading}
            <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
          {/if}
          Create Notebook
        </Button>
      </div>
    </div>
  </DialogContent>
</Dialog>

<!-- Execution Modal -->
<Dialog open={showExecutionModal} onOpenChange={(open) => showExecutionModal = open}>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Batch Execution</DialogTitle>
      <DialogDescription>
        Configure execution settings for selected notebooks.
      </DialogDescription>
    </DialogHeader>
    <div class="space-y-4">
      <div>
        <Label for="timeout">Timeout (seconds)</Label>
        <Input
          id="timeout"
          type="number"
          bind:value={executionForm.timeout_seconds}
          placeholder="300"
        />
      </div>
      <div>
        <Label>Environment Variables</Label>
        <div class="space-y-2">
          <Input
            placeholder="KEY=value"
            onkeydown={(e) => {
              if (e.key === 'Enter') {
                const input = e.target as HTMLInputElement;
                const [key, value] = input.value.split('=');
                if (key && value) {
                  executionForm.environment_variables[key.trim()] = value.trim();
                  input.value = '';
                }
              }
            }}
          />
          <div class="text-sm text-muted-foreground">
            Press Enter to add environment variables
          </div>
          {#if Object.keys(executionForm.environment_variables).length > 0}
            <div class="space-y-1">
              {#each Object.entries(executionForm.environment_variables) as [key, value]}
                <div class="flex items-center justify-between p-2 bg-muted rounded">
                  <span class="text-sm font-mono">{key}={value}</span>
                  <Button
                    size="sm"
                    variant="ghost"
                    onclick={() => {
                      delete executionForm.environment_variables[key];
                      executionForm.environment_variables = executionForm.environment_variables;
                    }}
                  >
                    ×
                  </Button>
                </div>
              {/each}
            </div>
          {/if}
        </div>
      </div>
      <div class="flex justify-end space-x-3">
        <Button variant="outline" onclick={() => showExecutionModal = false}>
          Cancel
        </Button>
        <Button onclick={() => showExecutionModal = false} disabled={loading}>
          Start Execution
        </Button>
      </div>
    </div>
  </DialogContent>
</Dialog>

<style>
  .line-clamp-2 {
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    line-clamp: 2;
  }
</style>