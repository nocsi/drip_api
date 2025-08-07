<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import type { LiveSvelteProps } from '../liveSvelte';
  import { Button } from '../ui/button';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
  import { Badge } from '../ui/badge';
  import { Input } from '../ui/input';
  import { Separator } from '../ui/separator';
  import {
    FolderOpen,
    FileText,
    BookOpen,
    Plus,
    Search,
    Grid3X3,
    List,
    SortAsc,
    SortDesc,
    MoreHorizontal,
    Edit,
    Trash2,
    Copy,
    Download,
    Upload,
    FolderPlus,
    Home,
    ChevronRight,
    Eye,
    Settings,
    Archive,
    Users,
    Calendar,
    HardDrive,
    Activity,
    Filter
  } from '@lucide/svelte';
  import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger, DropdownMenuSeparator } from '../ui/dropdown-menu';

  interface FileType {
    id: string;
    name?: string;
    file_name?: string;
    title?: string;
    description?: string;
    type?: string;
    file_size?: number;
    created_at?: string;
    updated_at?: string;
    __struct__?: string;
  }

  interface BreadcrumbType {
    path: string;
    name: string;
  }

  interface FolderType {
    name: string;
    path: string;
    children?: any[];
  }

  interface WorkspaceType {
    id: string;
    name: string;
    description?: string;
    status: string;
    storage_backend: string;
    document_count?: number;
    notebook_count?: number;
    created_at?: string;
    updated_at?: string;
    created_by_user?: string;
    storage_path?: string;
    git_repository_url?: string;
  }

  let {
    workspace = null,
    files = [],
    selected_file = null,
    current_path = '/',
    breadcrumbs = [],
    view_mode = 'grid',
    sort_by = 'name',
    sort_order = 'asc',
    search_query = '',
    file_content = null,
    editing_file = null,
    creating_file = false,
    file_tree = [],
    live
  } = $props<LiveSvelteProps<{
    workspace: WorkspaceType | null;
    files: FileType[];
    selected_file: FileType | null;
    current_path: string;
    breadcrumbs: BreadcrumbType[];
    view_mode: string;
    sort_by: string;
    sort_order: string;
    search_query: string;
    file_content: any;
    editing_file: FileType | null;
    creating_file: boolean;
    file_tree: FolderType[];
  }>>();

  let searchInput = $state(search_query);
  let showSidebar = $state(true);
  let selectedFiles = $state(new Set<string>());
  let showHidden = $state(false);

  let filteredFiles = $derived(filterFiles(files, searchInput, showHidden));
  let sortedFiles = $derived(sortFiles(filteredFiles, sort_by, sort_order));

  function filterFiles(files: FileType[], query: string, showHidden: boolean): FileType[] {
    let filtered = files;

    if (!showHidden) {
      filtered = filtered.filter(file => !getFileName(file).startsWith('.'));
    }

    if (query.trim()) {
      const queryLower = query.toLowerCase();
      filtered = filtered.filter(file =>
        getFileName(file).toLowerCase().includes(queryLower) ||
        (file.description && file.description.toLowerCase().includes(queryLower))
      );
    }

    return filtered;
  }

  function sortFiles(files: FileType[], sortBy: string, sortOrder: string): FileType[] {
    const multiplier = sortOrder === 'asc' ? 1 : -1;

    return [...files].sort((a, b) => {
      let aVal: any, bVal: any;

      switch (sortBy) {
        case 'name':
          aVal = getFileName(a).toLowerCase();
          bVal = getFileName(b).toLowerCase();
          break;
        case 'date':
          aVal = new Date(a.updated_at || a.created_at || 0);
          bVal = new Date(b.updated_at || b.created_at || 0);
          break;
        case 'size':
          aVal = a.file_size || 0;
          bVal = b.file_size || 0;
          break;
        case 'type':
          aVal = getFileType(a);
          bVal = getFileType(b);
          break;
        default:
          return 0;
      }

      if (aVal < bVal) return -1 * multiplier;
      if (aVal > bVal) return 1 * multiplier;
      return 0;
    });
  }

  function getFileName(file: FileType): string {
    return file.name || file.file_name || file.title || 'Untitled';
  }

  function getFileType(file: FileType): string {
    if (file.__struct__) {
      return file.__struct__.includes('Document') ? 'document' : 'notebook';
    }
    return file.type || 'document';
  }

  function getFileIcon(file: FileType) {
    const type = getFileType(file);
    switch (type) {
      case 'notebook': return BookOpen;
      case 'document': return FileText;
      default: return FileText;
    }
  }

  function formatFileSize(bytes: number): string {
    if (!bytes || bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
  }

  function formatDate(dateString: string): string {
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

  function handleSearch() {
    live.pushEvent('search_files', { query: searchInput });
  }

  function handleFileSelect(file: FileType) {
    live.pushEvent('select_file', { id: file.id });
  }

  function handleFileDoubleClick(file: FileType) {
    if (workspace) {
      live.pushEvent('lv:push_patch', { to: `/workspaces/${workspace.id}/dashboard/edit/${file.id}` });
    }
  }

  function handleBreadcrumbClick(breadcrumb: BreadcrumbType) {
    live.pushEvent('navigate_to', { path: breadcrumb.path });
  }

  function handleCreateFile() {
    if (workspace) {
      live.pushEvent('lv:push_patch', { to: `/workspaces/${workspace.id}/dashboard/new` });
    }
  }

  function handleEditFile(file: FileType) {
    if (workspace) {
      live.pushEvent('lv:push_patch', { to: `/workspaces/${workspace.id}/dashboard/edit/${file.id}` });
    }
  }

  function handleDeleteFile(file: FileType) {
    if (confirm(`Are you sure you want to delete "${getFileName(file)}"?`)) {
      live.pushEvent('delete_file', { id: file.id });
    }
  }

  function handleDuplicateFile(file: FileType) {
    live.pushEvent('duplicate_file', { id: file.id });
  }

  function handleDownloadFile(file: FileType) {
    // TODO: Implement file download
    console.log('Download file:', file);
  }

  function toggleViewMode() {
    const newMode = view_mode === 'grid' ? 'list' : 'grid';
    live.pushEvent('change_view_mode', { mode: newMode });
  }

  function handleSort(sortBy: string) {
    live.pushEvent('sort_files', { by: sortBy });
  }

  function toggleFileSelection(file: FileType) {
    if (selectedFiles.has(file.id)) {
      selectedFiles.delete(file.id);
    } else {
      selectedFiles.add(file.id);
    }
    selectedFiles = selectedFiles;
  }

  function selectAllFiles() {
    selectedFiles = new Set(sortedFiles.map(f => f.id));
  }

  function clearSelection() {
    selectedFiles = new Set();
  }

  function handleBulkDelete() {
    if (selectedFiles.size === 0) return;

    if (confirm(`Are you sure you want to delete ${selectedFiles.size} file(s)?`)) {
      Array.from(selectedFiles).forEach(fileId => {
        live.pushEvent('delete_file', { id: fileId });
      });
      clearSelection();
    }
  }

  function getFileTypeColor(type: string): string {
    switch (type) {
      case 'document': return 'bg-blue-100 text-blue-800';
      case 'notebook': return 'bg-purple-100 text-purple-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  }

  onMount(() => {
    // Initialize component
  });
</script>

<div class="flex h-full bg-background">
  <!-- Sidebar -->
  {#if showSidebar}
    <div class="w-64 border-r bg-muted/30 flex flex-col">
      <!-- Workspace Header -->
      <div class="p-4 border-b">
        <div class="flex items-center space-x-2">
          <FolderOpen class="w-5 h-5 text-primary" />
          <div class="flex-1 min-w-0">
            <h2 class="font-semibold truncate">{workspace?.name || 'Workspace'}</h2>
            <p class="text-xs text-muted-foreground truncate">
              {workspace?.description || 'No description'}
            </p>
          </div>
        </div>
      </div>

      <!-- Workspace Stats -->
      <div class="p-4 space-y-3">
        <div class="grid grid-cols-2 gap-2 text-sm">
          <div class="flex items-center space-x-2">
            <FileText class="w-4 h-4 text-muted-foreground" />
            <span class="text-muted-foreground">Docs:</span>
            <span class="font-medium">{workspace?.document_count || 0}</span>
          </div>
          <div class="flex items-center space-x-2">
            <BookOpen class="w-4 h-4 text-muted-foreground" />
            <span class="text-muted-foreground">Books:</span>
            <span class="font-medium">{workspace?.notebook_count || 0}</span>
          </div>
        </div>

        <div class="flex flex-wrap gap-1">
          <Badge class="text-xs {workspace?.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'}">
            {workspace?.status || 'unknown'}
          </Badge>
          <Badge variant="outline" class="text-xs">
            {workspace?.storage_backend || 'local'}
          </Badge>
        </div>
      </div>

      <Separator />

      <!-- File Tree (Simplified) -->
      <div class="flex-1 overflow-auto p-2">
        <div class="space-y-1">
          <button 
            class="flex items-center space-x-2 p-2 rounded hover:bg-muted cursor-pointer w-full text-left"
            onclick={() => handleBreadcrumbClick({path: '/', name: 'Root'})}
            type="button"
          >
            <Home class="w-4 h-4" />
            <span class="text-sm">Root</span>
          </button>

          {#each file_tree as folder}
            <button 
              class="flex items-center space-x-2 p-2 rounded hover:bg-muted cursor-pointer ml-4 w-full text-left"
              onclick={() => handleBreadcrumbClick({path: folder.path, name: folder.name})}
              type="button"
            >
              <FolderOpen class="w-4 h-4" />
              <span class="text-sm">{folder.name}</span>
              <span class="text-xs text-muted-foreground">({folder.children?.length || 0})</span>
            </button>
          {/each}
        </div>
      </div>

      <!-- Quick Actions -->
      <div class="p-4 border-t space-y-2">
        <Button class="w-full justify-start" size="sm" onclick={handleCreateFile}>
          <Plus class="w-4 h-4 mr-2" />
          New File
        </Button>
        <Button variant="outline" class="w-full justify-start" size="sm">
          <FolderPlus class="w-4 h-4 mr-2" />
          New Folder
        </Button>
        <Button variant="outline" class="w-full justify-start" size="sm">
          <Upload class="w-4 h-4 mr-2" />
          Upload
        </Button>
      </div>
    </div>
  {/if}

  <!-- Main Content -->
  <div class="flex-1 flex flex-col min-w-0">
    <!-- Header -->
    <div class="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div class="p-4 space-y-4">
        <!-- Breadcrumbs -->
        <div class="flex items-center space-x-1 text-sm">
          {#each breadcrumbs as crumb, index}
            <button
              class="text-muted-foreground hover:text-foreground"
              onclick={() => handleBreadcrumbClick(crumb)}
              type="button"
            >
              {crumb.name}
            </button>
            {#if index < breadcrumbs.length - 1}
              <ChevronRight class="w-4 h-4 text-muted-foreground" />
            {/if}
          {/each}
        </div>

        <!-- Controls -->
        <div class="flex items-center justify-between gap-4">
          <!-- Search -->
          <div class="flex-1 max-w-md">
            <div class="relative">
              <Search class="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <Input
                placeholder="Search files..."
                bind:value={searchInput}
                oninput={handleSearch}
                class="pl-10"
              />
            </div>
          </div>

          <!-- Action buttons -->
          <div class="flex items-center space-x-2">
            <!-- Selection controls -->
            {#if selectedFiles.size > 0}
              <div class="flex items-center space-x-2">
                <span class="text-sm text-muted-foreground">
                  {selectedFiles.size} selected
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

            <!-- View mode toggle -->
            <div class="flex items-center space-x-1">
              <Button
                size="sm"
                variant={view_mode === 'grid' ? 'default' : 'outline'}
                onclick={toggleViewMode}
              >
                <Grid3X3 class="w-4 h-4" />
              </Button>
              <Button
                size="sm"
                variant={view_mode === 'list' ? 'default' : 'outline'}
                onclick={toggleViewMode}
              >
                <List class="w-4 h-4" />
              </Button>
            </div>

            <!-- Sort dropdown -->
            <DropdownMenu>
              <DropdownMenuTrigger>
                <Button size="sm" variant="outline">
                  {#if sort_order === 'asc'}
                    <SortAsc class="w-4 h-4 mr-1" />
                  {:else}
                    <SortDesc class="w-4 h-4 mr-1" />
                  {/if}
                  Sort
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent>
                <DropdownMenuItem onclick={() => handleSort('name')}>
                  Name
                </DropdownMenuItem>
                <DropdownMenuItem onclick={() => handleSort('date')}>
                  Date
                </DropdownMenuItem>
                <DropdownMenuItem onclick={() => handleSort('size')}>
                  Size
                </DropdownMenuItem>
                <DropdownMenuItem onclick={() => handleSort('type')}>
                  Type
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>

            <!-- Filter dropdown -->
            <DropdownMenu>
              <DropdownMenuTrigger>
                <Button size="sm" variant="outline">
                  <Filter class="w-4 h-4 mr-1" />
                  Filter
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent>
                <DropdownMenuItem onclick={() => showHidden = !showHidden}>
                  {showHidden ? 'Hide' : 'Show'} Hidden Files
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem>All Files</DropdownMenuItem>
                <DropdownMenuItem>Documents Only</DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>

            <Button size="sm" onclick={handleCreateFile}>
              <Plus class="w-4 h-4 mr-1" />
              New
            </Button>
          </div>
        </div>
      </div>
    </div>

    <!-- File list -->
    <div class="flex-1 overflow-auto p-4">
      {#if sortedFiles.length === 0}
        <!-- Empty state -->
        <div class="flex flex-col items-center justify-center py-12 text-center">
          <FolderOpen class="w-16 h-16 text-muted-foreground mb-4" />
          <h3 class="text-lg font-semibold mb-2">
            {searchInput ? 'No files found' : 'No files yet'}
          </h3>
          <p class="text-muted-foreground mb-4 max-w-md">
            {searchInput 
              ? `No files match "${searchInput}". Try adjusting your search.`
              : 'Start by creating your first document or notebook in this workspace.'
            }
          </p>
          {#if !searchInput}
            <Button onclick={handleCreateFile}>
              <Plus class="w-4 h-4 mr-2" />
              Create First File
            </Button>
          {/if}
        </div>
      {:else if view_mode === 'grid'}
        <!-- Grid view -->
        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
          {#each sortedFiles as file (file.id)}
            {@const isSelected = selectedFiles.has(file.id)}
            <Card
              class="cursor-pointer transition-colors hover:bg-muted/50 {isSelected ? 'ring-2 ring-primary' : ''}"
              onclick={() => handleFileSelect(file)}
              ondblclick={() => handleFileDoubleClick(file)}
            >
              <CardHeader class="pb-2">
                <div class="flex items-start justify-between">
                  <div class="flex items-center space-x-2 min-w-0 flex-1">
                    {#if getFileIcon(file) === BookOpen}
                      <BookOpen class="w-8 h-8 text-primary" />
                    {:else}
                      <FileText class="w-8 h-8 text-primary" />
                    {/if}
                    <div class="min-w-0 flex-1">
                      <CardTitle class="text-sm truncate" title={getFileName(file)}>
                        {getFileName(file)}
                      </CardTitle>
                      <Badge variant="outline" class="text-xs mt-1 {getFileTypeColor(getFileType(file))}">
                        {getFileType(file)}
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
                          selectedFiles.add(file.id);
                        } else {
                          selectedFiles.delete(file.id);
                        }
                        selectedFiles = selectedFiles;
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
                        <DropdownMenuItem onclick={() => handleFileSelect(file)}>
                          <Eye class="w-4 h-4 mr-2" />
                          View
                        </DropdownMenuItem>
                        <DropdownMenuItem onclick={() => handleEditFile(file)}>
                          <Edit class="w-4 h-4 mr-2" />
                          Edit
                        </DropdownMenuItem>
                        <DropdownMenuItem onclick={() => handleDuplicateFile(file)}>
                          <Copy class="w-4 h-4 mr-2" />
                          Duplicate
                        </DropdownMenuItem>
                        <DropdownMenuItem onclick={() => handleDownloadFile(file)}>
                          <Download class="w-4 h-4 mr-2" />
                          Download
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem
                          class="text-destructive focus:text-destructive"
                          onclick={() => handleDeleteFile(file)}
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
                  <div>{formatFileSize(file.file_size || 0)}</div>
                  <div>{formatDate(file.updated_at || file.created_at || '')}</div>
                  {#if file.description}
                    <div class="line-clamp-2" title={file.description}>
                      {file.description}
                    </div>
                  {/if}
                </div>
              </CardContent>
            </Card>
          {/each}
        </div>
      {:else}
        <!-- List view -->
        <div class="space-y-1">
          <!-- Header -->
          <div class="grid grid-cols-12 gap-4 p-2 text-sm font-medium text-muted-foreground border-b">
            <div class="col-span-1">
              <input
                type="checkbox"
                checked={selectedFiles.size === sortedFiles.length && sortedFiles.length > 0}
                onchange={(e) => {
                  const target = e.target as HTMLInputElement;
                  if (target.checked) {
                    selectAllFiles();
                  } else {
                    clearSelection();
                  }
                }}
                class="rounded"
              />
            </div>
            <div class="col-span-5">Name</div>
            <div class="col-span-2">Type</div>
            <div class="col-span-2">Size</div>
            <div class="col-span-2">Modified</div>
          </div>

          <!-- File rows -->
          {#each sortedFiles as file (file.id)}
            {@const isSelected = selectedFiles.has(file.id)}
            <div
              class="grid grid-cols-12 gap-4 p-2 rounded hover:bg-muted cursor-pointer {isSelected ? 'bg-muted' : ''}"
              onclick={() => handleFileSelect(file)}
              ondblclick={() => handleFileDoubleClick(file)}
            >
              <div class="col-span-1">
                <input
                  type="checkbox"
                  checked={isSelected}
                  onchange={(e) => {
                    const target = e.target as HTMLInputElement;
                    if (target.checked) {
                      selectedFiles.add(file.id);
                    } else {
                      selectedFiles.delete(file.id);
                    }
                    selectedFiles = selectedFiles;
                  }}
                  onclick={(e) => e.stopPropagation()}
                  class="rounded"
                />
              </div>
              <div class="col-span-5 flex items-center space-x-2 min-w-0">
                {#if getFileIcon(file) === BookOpen}
                  <BookOpen class="w-4 h-4 text-primary flex-shrink-0" />
                {:else}
                  <FileText class="w-4 h-4 text-primary flex-shrink-0" />
                {/if}
                <span class="truncate" title={getFileName(file)}>{getFileName(file)}</span>
              </div>
              <div class="col-span-2">
                <Badge variant="outline" class="text-xs {getFileTypeColor(getFileType(file))}">
                  {getFileType(file)}
                </Badge>
              </div>
              <div class="col-span-2 text-sm text-muted-foreground">
                {formatFileSize(file.file_size || 0)}
              </div>
              <div class="col-span-2 flex items-center justify-between">
                <span class="text-sm text-muted-foreground">
                  {formatDate(file.updated_at || file.created_at || '')}
                </span>
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
                    <DropdownMenuItem onclick={() => handleFileSelect(file)}>
                      <Eye class="w-4 h-4 mr-2" />
                      View
                    </DropdownMenuItem>
                    <DropdownMenuItem onclick={() => handleEditFile(file)}>
                      <Edit class="w-4 h-4 mr-2" />
                      Edit
                    </DropdownMenuItem>
                    <DropdownMenuItem onclick={() => handleDuplicateFile(file)}>
                      <Copy class="w-4 h-4 mr-2" />
                      Duplicate
                    </DropdownMenuItem>
                    <DropdownMenuItem onclick={() => handleDownloadFile(file)}>
                      <Download class="w-4 h-4 mr-2" />
                      Download
                    </DropdownMenuItem>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem
                      class="text-destructive focus:text-destructive"
                      onclick={() => handleDeleteFile(file)}
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

<style>
  .line-clamp-2 {
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    line-clamp: 2;
  }
</style>