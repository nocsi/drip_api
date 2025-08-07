<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '../../utils';
  import { 
    documents, 
    currentWorkspace, 
    currentTeam,
    auth, 
    apiService,
    createTableStore 
  } from '../../stores/index';
  import type { Document } from '../../types';
  import { Button } from '../../ui/button';
  import { Input } from '../../ui/input';
  import { Label } from '../../ui/label';
  import { Textarea } from '../../ui/textarea';
  import { Avatar, AvatarFallback, AvatarImage } from '../../ui/avatar';
  import { Badge } from '../../ui/badge';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../../ui/card';
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
    FileText, 
    Settings, 
    Trash2, 
    MoreHorizontal,
    Calendar,
    Eye,
    Edit,
    Copy,
    Download,
    Upload,
    Search,
    Filter,
    Grid,
    List,
    Tags,
    Clock,
    User,
    Globe,
    Lock,
    Bookmark,
    Star,
    Archive,
    RefreshCw,
    ExternalLink,
    FileType,
    Hash
  } from '@lucide/svelte';

  // Component state
  let showCreateDialog = $state(false);
  let showUploadDialog = $state(false);
  let selectedDocument = $state<Document | null>(null);
  let loading = $state(false);
  let viewMode = $state<'grid' | 'list'>('grid');
  let searchQuery = $state('');
  let selectedTags = $state<string[]>([]);
  let filterStatus = $state('all');
  let sortBy = $state('updated_at');
  let sortOrder = $state<'asc' | 'desc'>('desc');

  // File upload
  let fileInput: HTMLInputElement;
  let uploadFiles = $state<FileList | null>(null);

  // Form state
  let createForm = $state({
    title: '',
    description: '',
    content: '',
    content_type: 'markdown' as 'markdown' | 'html' | 'text',
    is_public: false,
    tags: [] as string[],
    workspace_id: ''
  });

  let tagInput = $state('');

  const tableStore = createTableStore<Document>();

  const documentsData = $derived($documents.data || []);
  const isLoading = $derived($documents.status === 'loading' || loading);
  const hasWorkspace = $derived(!!$currentWorkspace);

  // Filter and search documents
  const filteredDocuments = $derived(documentsData.filter((document: Document) => {
    // Search filter
    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase();
      const matchesSearch = 
        document.title.toLowerCase().includes(query) ||
        (document.description && document.description.toLowerCase().includes(query)) ||
        (document.tags && document.tags.some((tag: string) => tag.toLowerCase().includes(query)));
      if (!matchesSearch) return false;
    }
    
    // Tag filter
    if (selectedTags.length > 0) {
      const hasSelectedTags = selectedTags.every((tag: string) => 
        document.tags?.includes(tag)
      );
      if (!hasSelectedTags) return false;
    }
    
    // Status filter
    if (filterStatus !== 'all') {
      if (filterStatus === 'public' && !document.is_public) return false;
      if (filterStatus === 'private' && document.is_public) return false;
    }
    
    return true;
  }).sort((a: Document, b: Document) => {
    let aValue: any, bValue: any;
    
    switch (sortBy) {
      case 'title':
        aValue = a.title.toLowerCase();
        bValue = b.title.toLowerCase();
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

  // Get all unique tags from documents
  const allTags = $derived(Array.from(new Set(
    documentsData.flatMap((doc: Document) => doc.tags || [])
  )).sort());

  onMount(async () => {
    if ($apiService && hasWorkspace) {
      await loadDocuments();
    }
  });

  async function loadDocuments() {
    if (!$apiService || !$currentWorkspace) return;
    await documents.load($apiService, $currentWorkspace.id);
  }

  async function createDocument() {
    if (!$apiService || !$currentWorkspace) return;

    try {
      loading = true;
      const document = await documents.create($apiService, {
        ...createForm,
        workspace_id: $currentWorkspace.id
      });
      
      // Reset form
      createForm = { 
        title: '', 
        description: '', 
        content: '',
        content_type: 'markdown',
        is_public: false,
        tags: [],
        workspace_id: ''
      };
      showCreateDialog = false;
      
      // Navigate to the new document
      goto(`/documents/${document.id}/edit`);
    } catch (error) {
      console.error('Failed to create document:', error);
    } finally {
      loading = false;
    }
  }

  async function duplicateDocument(document: Document) {
    if (!$apiService) return;

    try {
      loading = true;
      const duplicated = await $apiService.duplicateDocument(document.id, {
        title: `${document.title} (Copy)`,
        description: document.description,
        workspace_id: $currentWorkspace?.id
      });
      
      // Reload documents
      await loadDocuments();
      
      // Navigate to the duplicated document
      goto(`/documents/${duplicated.data.id}/edit`);
    } catch (error) {
      console.error('Failed to duplicate document:', error);
    } finally {
      loading = false;
    }
  }

  async function deleteDocument(document: Document) {
    if (!$apiService) return;

    try {
      loading = true;
      await documents.delete($apiService, document.id);
    } catch (error) {
      console.error('Failed to delete document:', error);
    } finally {
      loading = false;
    }
  }

  async function uploadDocuments() {
    if (!$apiService || !$currentWorkspace || !uploadFiles) return;

    try {
      loading = true;
      const formData = new FormData();
      
      for (let i = 0; i < uploadFiles.length; i++) {
        formData.append('files', uploadFiles[i]);
      }
      
      await $apiService.uploadDocuments($currentWorkspace.id, formData);
      
      // Reset upload state
      uploadFiles = null;
      if (fileInput) fileInput.value = '';
      showUploadDialog = false;
      
      // Reload documents
      await loadDocuments();
    } catch (error) {
      console.error('Failed to upload documents:', error);
    } finally {
      loading = false;
    }
  }

  function addTag() {
    if (tagInput.trim() && !createForm.tags.includes(tagInput.trim())) {
      createForm.tags = [...createForm.tags, tagInput.trim()];
      tagInput = '';
    }
  }

  function removeTag(tag: string) {
    createForm.tags = createForm.tags.filter(t => t !== tag);
  }

  function toggleTagFilter(tag: string) {
    if (selectedTags.includes(tag)) {
      selectedTags = selectedTags.filter(t => t !== tag);
    } else {
      selectedTags = [...selectedTags, tag];
    }
  }

  function clearFilters() {
    searchQuery = '';
    selectedTags = [];
    filterStatus = 'all';
  }

  function getContentTypeIcon(contentType: string) {
    switch (contentType) {
      case 'markdown':
        return Hash;
      case 'html':
        return Globe;
      case 'text':
      default:
        return FileText;
    }
  }

  function getContentTypeBadge(contentType: string) {
    switch (contentType) {
      case 'markdown':
        return 'MD';
      case 'html':
        return 'HTML';
      case 'text':
      default:
        return 'TXT';
    }
  }

  function formatDate(dateString: string): string {
    return new Date(dateString).toLocaleDateString();
  }

  function formatBytes(bytes: number): string {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
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
      <h1 class="text-2xl font-bold text-foreground">Documents</h1>
      <p class="text-muted-foreground">
        {#if $currentWorkspace}
          Manage documents in {$currentWorkspace.name}
        {:else}
          Select a workspace to view documents
        {/if}
      </p>
    </div>

    {#if hasWorkspace}
      <div class="flex items-center gap-2">
        <Dialog bind:open={showUploadDialog}>
          <DialogTrigger>
            <Button variant="outline">
              <Upload class="mr-2 h-4 w-4" />
              Upload
            </Button>
          </DialogTrigger>
        </Dialog>

        <Dialog bind:open={showCreateDialog}>
          <DialogTrigger>
            <Button>
              <Plus class="mr-2 h-4 w-4" />
              New Document
            </Button>
          </DialogTrigger>
        </Dialog>
      </div>
    {/if}
  </div>

  {#if !hasWorkspace}
    <!-- No workspace selected -->
    <Card>
      <CardContent class="flex flex-col items-center justify-center py-12">
        <FileText class="h-12 w-12 text-muted-foreground mb-4" />
        <h3 class="text-lg font-semibold mb-2">No Workspace Selected</h3>
        <p class="text-muted-foreground text-center mb-4">
          You need to select a workspace to view and manage documents.
        </p>
        <Button onclick={() => goto('/workspaces')}>
          Select Workspace
        </Button>
      </CardContent>
    </Card>
  {:else}
    <!-- Filters -->
    <Card>
      <CardContent class="p-4">
        <div class="flex flex-col gap-4 md:flex-row md:items-center">
          <!-- Search -->
          <div class="flex-1">
            <div class="relative">
              <Search class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                bind:value={searchQuery}
                placeholder="Search documents..."
                class="pl-10"
              />
            </div>
          </div>

          <div class="flex items-center gap-2">
            <!-- Status filter -->
            <select
              bind:value={filterStatus}
              class="rounded-md border border-input px-3 py-2 text-sm"
            >
              <option value="all">All Documents</option>
              <option value="public">Public Only</option>
              <option value="private">Private Only</option>
            </select>

            <!-- Sort -->
            <select
              bind:value={sortBy}
              class="rounded-md border border-input px-3 py-2 text-sm"
            >
              <option value="updated_at">Last Updated</option>
              <option value="created_at">Created Date</option>
              <option value="title">Title</option>
            </select>

            <Button
              variant="outline"
              size="sm"
              onclick={() => sortOrder = sortOrder === 'asc' ? 'desc' : 'asc'}
            >
              {sortOrder === 'asc' ? '↑' : '↓'}
            </Button>

            <!-- View mode toggle -->
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

            {#if searchQuery || selectedTags.length > 0 || filterStatus !== 'all'}
              <Button variant="outline" size="sm" onclick={clearFilters}>
                Clear Filters
              </Button>
            {/if}
          </div>
        </div>

        {#if allTags.length > 0}
          <div class="mt-4">
            <div class="text-sm font-medium mb-2">Filter by tags:</div>
            <div class="flex flex-wrap gap-2">
              {#each allTags as tag}
                <Button
                  variant={selectedTags.includes(tag) ? 'default' : 'outline'}
                  size="sm"
                  onclick={() => toggleTagFilter(tag as string)}
                  class="h-auto px-2 py-1 text-xs"
                >
                  <Tags class="mr-1 h-3 w-3" />
                  {tag}
                </Button>
              {/each}
            </div>
          </div>
        {/if}
      </CardContent>
    </Card>

    <!-- Documents Display -->
    {#if viewMode === 'grid'}
      <!-- Grid View -->
      <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        {#each filteredDocuments as document (document.id)}
          <Card class="cursor-pointer transition-all hover:shadow-md">
            <CardHeader class="pb-3">
              <div class="flex items-start justify-between">
                <div class="flex items-start space-x-3 min-w-0">
                  <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10">
                    <svelte:component this={getContentTypeIcon(document.content_type)} class="h-5 w-5 text-primary" />
                  </div>
                  <div class="min-w-0">
                    <CardTitle class="text-lg truncate">{document.title}</CardTitle>
                    <div class="flex items-center space-x-2 mt-1">
                      <Badge variant="outline" class="text-xs">
                        {getContentTypeBadge(document.content_type)}
                      </Badge>
                      {#if document.is_public}
                        <Badge variant="secondary" class="text-xs">
                          <Globe class="mr-1 h-3 w-3" />
                          Public
                        </Badge>
                      {:else}
                        <Badge variant="outline" class="text-xs">
                          <Lock class="mr-1 h-3 w-3" />
                          Private
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
                    <DropdownMenuItem onclick={() => goto(`/documents/${document.id}`)}>
                      <Eye class="mr-2 h-4 w-4" />
                      View
                    </DropdownMenuItem>
                    <DropdownMenuItem onclick={() => goto(`/documents/${document.id}/edit`)}>
                      <Edit class="mr-2 h-4 w-4" />
                      Edit
                    </DropdownMenuItem>
                    <DropdownMenuItem onclick={() => duplicateDocument(document)}>
                      <Copy class="mr-2 h-4 w-4" />
                      Duplicate
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
                          <AlertDialogTitle>Delete Document</AlertDialogTitle>
                          <AlertDialogDescription>
                            Are you sure you want to delete "{document.title}"? This action cannot be undone.
                          </AlertDialogDescription>
                        </AlertDialogHeader>
                        <AlertDialogFooter>
                          <AlertDialogCancel>Cancel</AlertDialogCancel>
                          <AlertDialogAction onclick={() => deleteDocument(document)}>
                            Delete
                          </AlertDialogAction>
                        </AlertDialogFooter>
                      </AlertDialogContent>
                    </AlertDialog>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            </CardHeader>

            <CardContent>
              {#if document.description}
                <CardDescription class="mb-3 line-clamp-2">{document.description}</CardDescription>
              {/if}

              {#if document.tags && document.tags.length > 0}
                <div class="flex flex-wrap gap-1 mb-3">
                  {#each document.tags.slice(0, 3) as tag}
                    <Badge variant="outline" class="text-xs">
                      {tag}
                    </Badge>
                  {/each}
                  {#if document.tags.length > 3}
                    <Badge variant="outline" class="text-xs">
                      +{document.tags.length - 3} more
                    </Badge>
                  {/if}
                </div>
              {/if}

              <div class="space-y-2 text-sm text-muted-foreground">
                {#if document.file_size_bytes}
                  <div class="flex items-center">
                    <FileType class="mr-1 h-4 w-4" />
                    <span>{formatBytes(document.file_size_bytes)}</span>
                  </div>
                {/if}
                <div class="flex items-center">
                  <Calendar class="mr-1 h-4 w-4" />
                  <span>Updated {formatDate(document.updated_at)}</span>
                </div>
                <div class="flex items-center">
                  <User class="mr-1 h-4 w-4" />
                  <span>{document.created_by?.name || 'Unknown'}</span>
                </div>
              </div>

              <div class="flex gap-2 mt-4">
                <Button 
                  variant="outline" 
                  size="sm" 
                  class="flex-1"
                  onclick={() => goto(`/documents/${document.id}`)}
                >
                  <Eye class="mr-2 h-4 w-4" />
                  View
                </Button>
                <Button 
                  variant="outline" 
                  size="sm" 
                  class="flex-1"
                  onclick={() => goto(`/documents/${document.id}/edit`)}
                >
                  <Edit class="mr-2 h-4 w-4" />
                  Edit
                </Button>
              </div>
            </CardContent>
          </Card>
        {/each}

        {#if filteredDocuments.length === 0 && !isLoading}
          <div class="col-span-full">
            <Card class="border-dashed">
              <CardContent class="flex flex-col items-center justify-center py-12">
                <FileText class="h-12 w-12 text-muted-foreground mb-4" />
                <h3 class="text-lg font-semibold mb-2">
                  {searchQuery || selectedTags.length > 0 ? 'No documents found' : 'No documents yet'}
                </h3>
                <p class="text-muted-foreground text-center mb-4">
                  {searchQuery || selectedTags.length > 0 
                    ? 'Try adjusting your search or filters' 
                    : 'Create your first document to get started'
                  }
                </p>
                {#if !searchQuery && selectedTags.length === 0}
                  <Button onclick={() => (showCreateDialog = true)}>
                    <Plus class="mr-2 h-4 w-4" />
                    Create Document
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
            {#each filteredDocuments as document (document.id)}
              <div class="flex items-center justify-between p-4 hover:bg-muted/50">
                <div class="flex items-center space-x-4 min-w-0">
                  <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10">
                    <svelte:component this={getContentTypeIcon(document.content_type)} class="h-4 w-4 text-primary" />
                  </div>

                  <div class="min-w-0 flex-1">
                    <div class="flex items-center space-x-2">
                      <h3 class="font-medium truncate">{document.title}</h3>
                      {#if document.is_public}
                        <Globe class="h-4 w-4 text-muted-foreground" />
                      {:else}
                        <Lock class="h-4 w-4 text-muted-foreground" />
                      {/if}
                    </div>
                    {#if document.description}
                      <p class="text-sm text-muted-foreground truncate">{document.description}</p>
                    {/if}

                    {#if document.tags && document.tags.length > 0}
                      <div class="flex space-x-1 mt-1">
                        {#each document.tags.slice(0, 3) as tag}
                          <Badge variant="outline" class="text-xs">
                            {tag}
                          </Badge>
                        {/each}
                        {#if document.tags.length > 3}
                          <Badge variant="outline" class="text-xs">
                            +{document.tags.length - 3}
                          </Badge>
                        {/if}
                      </div>
                    {/if}
                  </div>
                </div>

                <div class="flex items-center space-x-4 text-sm text-muted-foreground">
                  <div class="text-right">
                    <div>{formatDate(document.updated_at)}</div>
                    <div class="text-xs">{document.created_by?.name || 'Unknown'}</div>
                  </div>

                  <div class="flex items-center space-x-1">
                    <Button 
                      variant="ghost" 
                      size="sm"
                      onclick={() => goto(`/documents/${document.id}`)}
                    >
                      <Eye class="h-4 w-4" />
                    </Button>
                    <Button 
                      variant="ghost" 
                      size="sm"
                      onclick={() => goto(`/documents/${document.id}/edit`)}
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
                        <DropdownMenuItem onclick={() => duplicateDocument(document)}>
                          <Copy class="mr-2 h-4 w-4" />
                          Duplicate
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
                              <AlertDialogTitle>Delete Document</AlertDialogTitle>
                              <AlertDialogDescription>
                                Are you sure you want to delete "{document.title}"? This action cannot be undone.
                              </AlertDialogDescription>
                            </AlertDialogHeader>
                            <AlertDialogFooter>
                              <AlertDialogCancel>Cancel</AlertDialogCancel>
                              <AlertDialogAction onclick={() => deleteDocument(document)}>
                                Delete
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

            {#if filteredDocuments.length === 0 && !isLoading}
              <div class="flex flex-col items-center justify-center py-12">
                <FileText class="h-12 w-12 text-muted-foreground mb-4" />
                <h3 class="text-lg font-semibold mb-2">
                  {searchQuery || selectedTags.length > 0 ? 'No documents found' : 'No documents yet'}
                </h3>
                <p class="text-muted-foreground text-center mb-4">
                  {searchQuery || selectedTags.length > 0 
                    ? 'Try adjusting your search or filters' 
                    : 'Create your first document to get started'
                  }
                </p>
                {#if !searchQuery && selectedTags.length === 0}
                  <Button onclick={() => (showCreateDialog = true)}>
                    <Plus class="mr-2 h-4 w-4" />
                    Create Document
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

<!-- Create Document Dialog -->
<Dialog bind:open={showCreateDialog}>
  <DialogContent class="sm:max-w-[500px]">
    <DialogHeader>
      <DialogTitle>Create New Document</DialogTitle>
      <DialogDescription>
        Create a new document in your current workspace.
      </DialogDescription>
    </DialogHeader>
    <div class="space-y-4 py-4">
      <div class="space-y-2">
        <Label for="doc-title">Title</Label>
        <Input
          id="doc-title"
          bind:value={createForm.title}
          placeholder="Enter document title"
        />
      </div>

      <div class="space-y-2">
        <Label for="doc-description">Description (Optional)</Label>
        <Textarea
          id="doc-description"
          bind:value={createForm.description}
          placeholder="Enter document description"
          rows={3}
        />
      </div>

      <div class="space-y-2">
        <Label for="content-type">Content Type</Label>
        <select
          id="content-type"
          bind:value={createForm.content_type}
          class="w-full rounded-md border border-input px-3 py-2"
        >
          <option value="markdown">Markdown</option>
          <option value="html">HTML</option>
          <option value="text">Plain Text</option>
        </select>
      </div>

      <div class="space-y-2">
        <Label for="doc-tags">Tags</Label>
        <div class="space-y-2">
          <div class="flex space-x-2">
            <Input
              id="doc-tags"
              bind:value={tagInput}
              placeholder="Add tags"
              onkeydown={(e) => e.key === 'Enter' && (e.preventDefault(), addTag())}
            />
            <Button type="button" variant="outline" size="sm" onclick={addTag}>
              Add
            </Button>
          </div>

          {#if createForm.tags.length > 0}
            <div class="flex flex-wrap gap-2">
              {#each createForm.tags as tag}
                <Badge variant="secondary" class="cursor-pointer" onclick={() => removeTag(tag)}>
                  {tag}
                  <button class="ml-1 text-xs" onclick={(e) => { e.stopPropagation(); removeTag(tag); }}>×</button>
                </Badge>
              {/each}
            </div>
          {/if}
        </div>
      </div>

      <div class="flex items-center space-x-2">
        <input 
          id="is-public"
          type="checkbox" 
          bind:checked={createForm.is_public}
          class="rounded border-gray-300"
        />
        <Label for="is-public" class="text-sm">Make this document public</Label>
      </div>
    </div>
    <DialogFooter>
      <Button variant="outline" onclick={() => (showCreateDialog = false)}>
        Cancel
      </Button>
      <Button onclick={createDocument} disabled={!createForm.title.trim() || isLoading}>
        {#if isLoading}
          Creating...
        {:else}
          Create Document
        {/if}
      </Button>
    </DialogFooter>
  </DialogContent>
</Dialog>

<Dialog bind:open={showUploadDialog}>
  <DialogContent class="sm:max-w-[425px]">
    <DialogHeader>
      <DialogTitle>Upload Documents</DialogTitle>
      <DialogDescription>
        Upload markdown, text, or HTML files to your current workspace.
      </DialogDescription>
    </DialogHeader>
    
    <div class="space-y-4 py-4">
      <div class="space-y-2">
        <Label for="file-upload">Select Files</Label>
        <input
          id="file-upload"
          type="file"
          multiple
          accept=".md,.txt,.html,.htm"
          bind:this={fileInput}
          bind:files={uploadFiles}
          class="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
        />
      </div>
      
      {#if uploadFiles && uploadFiles.length > 0}
        <div class="space-y-2">
          <Label>Selected Files:</Label>
          <div class="space-y-1">
            {#each Array.from(uploadFiles) as file}
              <div class="flex items-center justify-between text-sm">
                <span>{file.name}</span>
                <span class="text-muted-foreground">{formatBytes(file.size)}</span>
              </div>
            {/each}
          </div>
        </div>
      {/if}
    </div>
    
    <DialogFooter>
      <Button variant="outline" onclick={() => (showUploadDialog = false)}>
        Cancel
      </Button>
      <Button 
        onclick={uploadDocuments} 
        disabled={!uploadFiles || uploadFiles.length === 0 || isLoading}
      >
        {#if isLoading}
          Uploading...
        {:else}
          Upload Documents
        {/if}
      </Button>
    </DialogFooter>
  </DialogContent>
</Dialog>