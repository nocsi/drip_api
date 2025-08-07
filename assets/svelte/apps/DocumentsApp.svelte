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
  import { Avatar, AvatarFallback, AvatarImage } from '../ui/avatar';
  import {
    FileText,
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
    Upload,
    Eye,
    Clock,
    User,
    Calendar,
    FileIcon,
    FolderOpen,
    SortAsc,
    SortDesc,
    ChevronDown,
    AlertCircle
  } from '@lucide/svelte';

  // Props from LiveView
  interface Props {
    currentUser: any;
    currentTeam: any;
    workspace?: any;
    documents?: any[];
    selectedDocument?: any;
    viewMode?: string;
    sortBy?: string;
    sortOrder?: string;
    searchQuery?: string;
    contentTypes?: string[];
    apiToken?: string;
    csrfToken?: string;
    apiBaseUrl?: string;
  }

  let {
    currentUser,
    currentTeam,
    workspace = null,
    documents = [],
    selectedDocument = null,
    viewMode = 'grid',
    sortBy = 'updated_at',
    sortOrder = 'desc',
    searchQuery = '',
    contentTypes = ['markdown', 'text', 'html'],
    apiToken = '',
    csrfToken = '',
    apiBaseUrl = '/api/v1'
  }: Props = $props();

  // Component state
  let searchInput = $state(searchQuery);
  let showSidebar = $state(true);
  let loading = $state(false);
  let error = $state(null);
  let selectedDocuments = $state(new Set<string>());
  let showCreateModal = $state(false);
  let showUploadModal = $state(false);
  let showFilters = $state(false);
  let filteredDocuments = $state(documents);
  let currentFilter = $state('all');
  let fileInput: HTMLInputElement;

  // Form state
  let createForm = $state({
    title: '',
    content_type: 'markdown',
    description: '',
    workspace_id: workspace?.id || ''
  });

  let uploadForm = $state({
    files: [] as FileList | null,
    workspace_id: workspace?.id || '',
    commit_message: 'Upload documents'
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

    // Document operations
    async listDocuments(params = {}) {
      const queryParams = new URLSearchParams(params);
      const endpoint = workspace 
        ? `/workspaces/${workspace.id}/documents?${queryParams}`
        : `/documents?${queryParams}`;
      return this.request(endpoint);
    },

    async getDocument(id: string) {
      return this.request(`/documents/${id}`);
    },

    async createDocument(documentData: any) {
      return this.request('/documents', {
        method: 'POST',
        body: JSON.stringify({ document: documentData })
      });
    },

    async updateDocument(id: string, documentData: any) {
      return this.request(`/documents/${id}`, {
        method: 'PUT',
        body: JSON.stringify({ document: documentData })
      });
    },

    async deleteDocument(id: string) {
      return this.request(`/documents/${id}`, {
        method: 'DELETE'
      });
    },

    async duplicateDocument(id: string, options = {}) {
      return this.request(`/documents/${id}/duplicate`, {
        method: 'POST',
        body: JSON.stringify({ options })
      });
    },

    async uploadDocuments(formData: FormData) {
      const endpoint = workspace 
        ? `/workspaces/${workspace.id}/documents/upload`
        : '/documents/upload';
      
      return fetch(`${apiBaseUrl}${endpoint}`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiToken}`,
          'X-CSRF-Token': csrfToken,
          'X-Team-ID': currentTeam?.id || ''
        },
        body: formData
      }).then(res => {
        if (!res.ok) throw new Error(`Upload failed: ${res.statusText}`);
        return res.json();
      });
    }
  };

  // Reactive filtering and sorting
  $effect(() => {
    filterAndSortDocuments();
  });

  function filterAndSortDocuments() {
    let filtered = [...documents];

    // Apply search filter
    if (searchInput.trim()) {
      const query = searchInput.toLowerCase();
      filtered = filtered.filter(doc => 
        doc.title?.toLowerCase().includes(query) ||
        doc.description?.toLowerCase().includes(query) ||
        doc.content_type?.toLowerCase().includes(query)
      );
    }

    // Apply content type filter
    if (currentFilter !== 'all') {
      filtered = filtered.filter(doc => doc.content_type === currentFilter);
    }

    // Sort documents
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
        case 'content_type':
          aVal = a.content_type || '';
          bVal = b.content_type || '';
          break;
        default:
          return 0;
      }

      const multiplier = sortOrder === 'asc' ? 1 : -1;
      if (aVal < bVal) return -1 * multiplier;
      if (aVal > bVal) return 1 * multiplier;
      return 0;
    });

    filteredDocuments = filtered;
  }

  // Event handlers
  async function handleSearch() {
    searchQuery = searchInput;
    dispatch('search', { query: searchQuery });
    await refreshDocuments();
  }

  async function handleCreateDocument() {
    if (!createForm.title.trim()) {
      error = 'Document title is required';
      return;
    }

    loading = true;
    try {
      const response = await apiClient.createDocument(createForm);
      documents = [response.data, ...documents];
      showCreateModal = false;
      createForm = {
        title: '',
        content_type: 'markdown',
        description: '',
        workspace_id: workspace?.id || ''
      };
      dispatch('documentCreated', { document: response.data });
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  async function handleUploadDocuments() {
    if (!uploadForm.files || uploadForm.files.length === 0) {
      error = 'Please select files to upload';
      return;
    }

    loading = true;
    try {
      const formData = new FormData();
      Array.from(uploadForm.files).forEach(file => {
        formData.append('files[]', file);
      });
      formData.append('workspace_id', uploadForm.workspace_id);
      formData.append('commit_message', uploadForm.commit_message);

      const response = await apiClient.uploadDocuments(formData);
      
      // Refresh documents list
      await refreshDocuments();
      
      showUploadModal = false;
      uploadForm = {
        files: null,
        workspace_id: workspace?.id || '',
        commit_message: 'Upload documents'
      };
      dispatch('documentsUploaded', { documents: response.data });
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  async function handleDeleteDocument(document: any) {
    if (!confirm(`Are you sure you want to delete "${document.title}"?`)) {
      return;
    }

    loading = true;
    try {
      await apiClient.deleteDocument(document.id);
      documents = documents.filter(d => d.id !== document.id);
      dispatch('documentDeleted', { document });
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  async function handleDuplicateDocument(document: any) {
    loading = true;
    try {
      const response = await apiClient.duplicateDocument(document.id);
      documents = [response.data, ...documents];
      dispatch('documentDuplicated', { original: document, duplicate: response.data });
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  function handleViewDocument(document: any) {
    dispatch('viewDocument', { document });
  }

  function handleEditDocument(document: any) {
    dispatch('editDocument', { document });
  }

  function handleDownloadDocument(document: any) {
    dispatch('downloadDocument', { document });
  }

  function toggleDocumentSelection(document: any) {
    if (selectedDocuments.has(document.id)) {
      selectedDocuments.delete(document.id);
    } else {
      selectedDocuments.add(document.id);
    }
    selectedDocuments = selectedDocuments;
  }

  function selectAllDocuments() {
    selectedDocuments = new Set(filteredDocuments.map(d => d.id));
  }

  function clearSelection() {
    selectedDocuments = new Set();
  }

  async function handleBulkDelete() {
    if (selectedDocuments.size === 0) return;

    if (!confirm(`Are you sure you want to delete ${selectedDocuments.size} document(s)?`)) {
      return;
    }

    loading = true;
    try {
      await Promise.all(
        Array.from(selectedDocuments).map(id => apiClient.deleteDocument(id))
      );
      documents = documents.filter(d => !selectedDocuments.has(d.id));
      clearSelection();
      dispatch('documentsDeleted', { count: selectedDocuments.size });
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

  async function refreshDocuments() {
    loading = true;
    try {
      const response = await apiClient.listDocuments({
        search: searchQuery,
        sort_by: sortBy,
        sort_order: sortOrder,
        content_type: currentFilter !== 'all' ? currentFilter : undefined
      });
      documents = response.data || [];
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

  function getContentTypeIcon(contentType: string) {
    switch (contentType) {
      case 'markdown': return FileText;
      case 'html': return FileIcon;
      case 'text': return FileText;
      default: return FileIcon;
    }
  }

  function getContentTypeColor(contentType: string): string {
    switch (contentType) {
      case 'markdown': return 'bg-blue-100 text-blue-800';
      case 'html': return 'bg-green-100 text-green-800';
      case 'text': return 'bg-gray-100 text-gray-800';
      default: return 'bg-purple-100 text-purple-800';
    }
  }

  onMount(() => {
    refreshDocuments();
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
                {documents.length} documents
              </p>
            </div>
          </div>
        </div>
      {/if}

      <!-- Filters -->
      <div class="p-4 space-y-4">
        <div>
          <h3 class="text-sm font-medium text-gray-900 mb-2">Content Type</h3>
          <div class="space-y-1">
            <button
              class="w-full text-left px-2 py-1 text-sm rounded hover:bg-muted {currentFilter === 'all' ? 'bg-primary text-primary-foreground' : ''}"
              onclick={() => currentFilter = 'all'}
            >
              All Documents ({documents.length})
            </button>
            {#each contentTypes as contentType}
              {@const count = documents.filter(d => d.content_type === contentType).length}
              <button
                class="w-full text-left px-2 py-1 text-sm rounded hover:bg-muted {currentFilter === contentType ? 'bg-primary text-primary-foreground' : ''}"
                onclick={() => currentFilter = contentType}
              >
                <span class="capitalize">{contentType}</span> ({count})
              </button>
            {/each}
          </div>
        </div>
      </div>

      <Separator />

      <!-- Quick Actions -->
      <div class="p-4 space-y-2">
        <Button class="w-full justify-start" size="sm" onclick={() => showCreateModal = true}>
          <Plus class="w-4 h-4 mr-2" />
          New Document
        </Button>
        <Button variant="outline" class="w-full justify-start" size="sm" onclick={() => showUploadModal = true}>
          <Upload class="w-4 h-4 mr-2" />
          Upload Files
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
              placeholder="Search documents..."
              bind:value={searchInput}
              oninput={handleSearch}
              class="pl-10"
            />
          </div>
        </div>

        <!-- Controls -->
        <div class="flex items-center justify-between gap-4">
          <div class="flex items-center space-x-2">
            {#if selectedDocuments.size > 0}
              <div class="flex items-center space-x-2">
                <span class="text-sm text-muted-foreground">
                  {selectedDocuments.size} selected
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
                <DropdownMenuItem onclick={() => handleSortChange('content_type')}>
                  Type
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
      {#if loading && filteredDocuments.length === 0}
        <div class="flex items-center justify-center py-12">
          <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-primary"></div>
          <span class="ml-2 text-sm text-muted-foreground">Loading documents...</span>
        </div>
      {:else if filteredDocuments.length === 0}
        <!-- Empty State -->
        <div class="flex flex-col items-center justify-center py-12 text-center">
          <FileText class="w-16 h-16 text-muted-foreground mb-4" />
          <h3 class="text-lg font-semibold mb-2">
            {searchInput ? 'No documents found' : 'No documents yet'}
          </h3>
          <p class="text-muted-foreground mb-4 max-w-md">
            {searchInput
              ? `No documents match "${searchInput}". Try adjusting your search.`
              : 'Start by creating your first document or uploading files.'
            }
          </p>
          {#if !searchInput}
            <div class="flex space-x-2">
              <Button onclick={() => showCreateModal = true}>
                <Plus class="w-4 h-4 mr-2" />
                Create Document
              </Button>
              <Button variant="outline" onclick={() => showUploadModal = true}>
                <Upload class="w-4 h-4 mr-2" />
                Upload Files
              </Button>
            </div>
          {/if}
        </div>
      {:else if viewMode === 'grid'}
        <!-- Grid View -->
        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
          {#each filteredDocuments as document (document.id)}
            {@const isSelected = selectedDocuments.has(document.id)}
            {@const IconComponent = getContentTypeIcon(document.content_type)}
            <Card
              class="cursor-pointer transition-colors hover:bg-muted/50 {isSelected ? 'ring-2 ring-primary' : ''}"
              onclick={() => handleViewDocument(document)}
            >
              <CardHeader class="pb-2">
                <div class="flex items-start justify-between">
                  <div class="flex items-center space-x-2 min-w-0 flex-1">
                    <IconComponent class="w-8 h-8 text-primary" />
                    <div class="min-w-0 flex-1">
                      <CardTitle class="text-sm truncate" title={document.title}>
                        {document.title}
                      </CardTitle>
                      <Badge variant="outline" class="text-xs mt-1 {getContentTypeColor(document.content_type)}">
                        {document.content_type}
                      </Badge>
                    </div>
                  </div>

                  <div class="flex items-center space-x-1">
                    <input
                      type="checkbox"
                      checked={isSelected}
                      onchange={(e) => {
                        const target = e.target as HTMLInputElement;
                        if (target.checked) {
                          selectedDocuments.add(document.id);
                        } else {
                          selectedDocuments.delete(document.id);
                        }
                        selectedDocuments = selectedDocuments;
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
                        <DropdownMenuItem onclick={() => handleViewDocument(document)}>
                          <Eye class="w-4 h-4 mr-2" />
                          View
                        </DropdownMenuItem>
                        <DropdownMenuItem onclick={() => handleEditDocument(document)}>
                          <Edit class="w-4 h-4 mr-2" />
                          Edit
                        </DropdownMenuItem>
                        <DropdownMenuItem onclick={() => handleDuplicateDocument(document)}>
                          <Copy class="w-4 h-4 mr-2" />
                          Duplicate
                        </DropdownMenuItem>
                        <DropdownMenuItem onclick={() => handleDownloadDocument(document)}>
                          <Download class="w-4 h-4 mr-2" />
                          Download
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem
                          class="text-destructive focus:text-destructive"
                          onclick={() => handleDeleteDocument(document)}
                        >
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
                    <span>{formatDate(document.updated_at)}</span>
                  </div>
                  {#if document.description}
                    <div class="line-clamp-2" title={document.description}>
                      {document.description}
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
                checked={selectedDocuments.size === filteredDocuments.length && filteredDocuments.length > 0}
                onchange={(e) => {
                  const target = e.target as HTMLInputElement;
                  if (target.checked) {
                    selectAllDocuments();
                  } else {
                    clearSelection();
                  }
                }}
                class="rounded"
              />
            </div>
            <div class="col-span-5">Title</div>
            <div class="col-span-2">Type</div>
            <div class="col-span-2">Modified</div>
            <div class="col-span-2">Actions</div>
          </div>

          <!-- Document rows -->
          {#each filteredDocuments as document (document.id)}
            {@const isSelected = selectedDocuments.has(document.id)}
            {@const IconComponent = getContentTypeIcon(document.content_type)}
            <div
              class="grid grid-cols-12 gap-4 p-2 rounded hover:bg-muted cursor-pointer {isSelected ? 'bg-muted' : ''}"
              onclick={() => handleViewDocument(document)}
            >
              <div class="col-span-1">
                <input
                  type="checkbox"
                  checked={isSelected}
                  onchange={(e) => {
                    const target = e.target as HTMLInputElement;
                    if (target.checked) {
                      selectedDocuments.add(document.id);
                    } else {
                      selectedDocuments.delete(document.id);
                    }
                    selectedDocuments = selectedDocuments;
                  }}
                  onclick={(e) => e.stopPropagation()}
                  class="rounded"
                />
              </div>
              <div class="col-span-5 flex items-center space-x-2 min-w-0">
                <IconComponent class="w-4 h-4 text-primary flex-shrink-0" />
                <span class="truncate" title={document.title}>{document.title}</span>
              </div>
              <div class="col-span-2">
                <Badge variant="outline" class="text-xs {getContentTypeColor(document.content_type)}">
                  {document.content_type}
                </Badge>
              </div>
              <div class="col-span-2 text-sm text-muted-foreground">
                {formatDate(document.updated_at)}
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
                    <DropdownMenuItem onclick={() => handleViewDocument(document)}>
                      <Eye class="w-4 h-4 mr-2" />
                      View
                    </DropdownMenuItem>
                    <DropdownMenuItem onclick={() => handleEditDocument(document)}>
                      <Edit class="w-4 h-4 mr-2" />
                      Edit
                    </DropdownMenuItem>
                    <DropdownMenuItem onclick={() => handleDuplicateDocument(document)}>
                      <Copy class="w-4 h-4 mr-2" />
                      Duplicate
                    </DropdownMenuItem>
                    <DropdownMenuItem onclick={() => handleDownloadDocument(document)}>
                      <Download class="w-4 h-4 mr-2" />
                      Download
                    </DropdownMenuItem>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem
                      class="text-destructive focus:text-destructive"
                      onclick={() => handleDeleteDocument(document)}
                    >
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

<!-- Create Document Modal -->
<Dialog open={showCreateModal} onOpenChange={(open) => showCreateModal = open}>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Create New Document</DialogTitle>
      <DialogDescription>
        Create a new document in your workspace.
      </DialogDescription>
    </DialogHeader>
    <div class="space-y-4">
      <div>
        <Label for="document-title">Title</Label>
        <Input
          id="document-title"
          bind:value={createForm.title}
          placeholder="My New Document"
        />
      </div>
      <div>
        <Label for="document-type">Content Type</Label>
        <select
          id="document-type"
          bind:value={createForm.content_type}
          class="w-full mt-1 px-3 py-2 border rounded-md"
        >
          {#each contentTypes as type}
            <option value={type}>{type.charAt(0).toUpperCase() + type.slice(1)}</option>
          {/each}
        </select>
      </div>
      <div>
        <Label for="document-description">Description (Optional)</Label>
        <Textarea
          id="document-description"
          bind:value={createForm.description}
          placeholder="Brief description of the document"
        />
      </div>
      <div class="flex justify-end space-x-3">
        <Button variant="outline" onclick={() => showCreateModal = false}>
          Cancel
        </Button>
        <Button onclick={handleCreateDocument} disabled={loading}>
          {#if loading}
            <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
          {/if}
          Create Document
        </Button>
      </div>
    </div>
  </DialogContent>
</Dialog>

<!-- Upload Documents Modal -->
<Dialog open={showUploadModal} onOpenChange={(open) => showUploadModal = open}>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Upload Documents</DialogTitle>
      <DialogDescription>
        Upload multiple files to your workspace.
      </DialogDescription>
    </DialogHeader>
    <div class="space-y-4">
      <div>
        <Label for="file-upload">Select Files</Label>
        <input
          id="file-upload"
          type="file"
          multiple
          accept=".md,.txt,.html,.json"
          bind:this={fileInput}
          onchange={(e) => {
            const target = e.target as HTMLInputElement;
            uploadForm.files = target.files;
          }}
          class="w-full mt-1 px-3 py-2 border rounded-md"
        />
        <p class="text-sm text-muted-foreground mt-1">
          Supported formats: Markdown (.md), Text (.txt), HTML (.html), JSON (.json)
        </p>
      </div>
      <div>
        <Label for="commit-message">Commit Message</Label>
        <Input
          id="commit-message"
          bind:value={uploadForm.commit_message}
          placeholder="Upload documents"
        />
      </div>
      <div class="flex justify-end space-x-3">
        <Button variant="outline" onclick={() => showUploadModal = false}>
          Cancel
        </Button>
        <Button onclick={handleUploadDocuments} disabled={loading}>
          {#if loading}
            <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
          {/if}
          Upload Files
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