import { storageAPI } from '$lib/api/storage';
import type { VFSListing, VFSContent, FileSystemItem } from '$lib/types/storage';
import { createFileSystemItem } from '$lib/types/storage';

interface FileBrowserState {
  listing: VFSListing | null;
  loading: boolean;
  error: Error | null;
  selectedPath: string | null;
  virtualContent: VFSContent | null;
}

export function createFileBrowserStore() {
  let state = $state<FileBrowserState>({
    listing: null,
    loading: false,
    error: null,
    selectedPath: null,
    virtualContent: null
  });

  async function loadDirectory(teamId: string, workspaceId: string, path: string = '/') {
    state.loading = true;
    state.error = null;
    
    try {
      const listing = await storageAPI.listVFS(teamId, workspaceId, path);
      state.listing = listing;
    } catch (error) {
      state.error = error as Error;
      console.error('Failed to load directory:', error);
    } finally {
      state.loading = false;
    }
  }

  async function readVirtualFile(teamId: string, workspaceId: string, path: string) {
    try {
      const content = await storageAPI.readVirtualFile(teamId, workspaceId, path);
      state.virtualContent = content;
      state.selectedPath = path;
      return content;
    } catch (error) {
      state.error = error as Error;
      console.error('Failed to read virtual file:', error);
      return null;
    }
  }

  function clearVirtualContent() {
    state.virtualContent = null;
    state.selectedPath = null;
  }

  const fileSystemItems = $derived<FileSystemItem[]>(() => {
    if (!state.listing) return [];
    return state.listing.files.map(createFileSystemItem);
  });

  const breadcrumbs = $derived<Array<{ name: string; path: string }>>(() => {
    if (!state.listing) return [];
    
    const path = state.listing.path;
    if (path === '/' || !path) {
      return [{ name: 'Root', path: '/' }];
    }
    
    const crumbs = [{ name: 'Root', path: '/' }];
    const parts = path.split('/').filter(Boolean);
    let accumulatedPath = '';
    
    for (const part of parts) {
      accumulatedPath += `/${part}`;
      crumbs.push({ name: part, path: accumulatedPath });
    }
    
    return crumbs;
  });

  const canNavigateUp = $derived(() => {
    return state.listing && state.listing.path !== '/' && state.listing.path !== '';
  });

  const parentPath = $derived(() => {
    if (!state.listing || !canNavigateUp) return '/';
    
    const path = state.listing.path;
    const lastSlash = path.lastIndexOf('/');
    return lastSlash > 0 ? path.substring(0, lastSlash) : '/';
  });

  return {
    get listing() { return state.listing; },
    get loading() { return state.loading; },
    get error() { return state.error; },
    get selectedPath() { return state.selectedPath; },
    get virtualContent() { return state.virtualContent; },
    get fileSystemItems() { return fileSystemItems; },
    get breadcrumbs() { return breadcrumbs; },
    get canNavigateUp() { return canNavigateUp; },
    get parentPath() { return parentPath; },
    
    loadDirectory,
    readVirtualFile,
    clearVirtualContent
  };
}

export type FileBrowserStore = ReturnType<typeof createFileBrowserStore>;