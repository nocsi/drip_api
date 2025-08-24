<script lang="ts">
  import { createFileBrowserStore } from '$lib/stores/file-browser.svelte';
  import FileList from './FileList.svelte';
  import MarkdownViewer from './MarkdownViewer.svelte';
  import { ChevronUp, RefreshCw, X } from '@lucide/svelte';
  import { onMount } from 'svelte';
  
  interface Props {
    teamId: string;
    workspaceId: string;
    initialPath?: string;
  }
  
  let { teamId, workspaceId, initialPath = '/' }: Props = $props();
  
  const store = createFileBrowserStore();
  let showVirtualContent = $state(false);
  
  onMount(() => {
    store.loadDirectory(teamId, workspaceId, initialPath);
  });
  
  function handleFileSelect(path: string, isVirtual: boolean) {
    if (isVirtual) {
      store.readVirtualFile(teamId, workspaceId, path).then(content => {
        if (content) {
          showVirtualContent = true;
        }
      });
    } else {
      // Handle regular file selection
      console.log('Selected file:', path);
    }
  }
  
  function handleDirectorySelect(path: string) {
    store.loadDirectory(teamId, workspaceId, path);
  }
  
  function navigateUp() {
    if (store.canNavigateUp) {
      store.loadDirectory(teamId, workspaceId, store.parentPath);
    }
  }
  
  function refresh() {
    if (store.listing) {
      store.loadDirectory(teamId, workspaceId, store.listing.path);
    }
  }
  
  function closeVirtualContent() {
    showVirtualContent = false;
    store.clearVirtualContent();
  }
</script>

<div class="file-browser">
  <div class="file-browser-header">
    <div class="breadcrumbs">
      {#each store.breadcrumbs as crumb, i}
        {#if i > 0}
          <span class="breadcrumb-separator">/</span>
        {/if}
        <button 
          class="breadcrumb-item"
          onclick={() => store.loadDirectory(teamId, workspaceId, crumb.path)}
        >
          {crumb.name}
        </button>
      {/each}
    </div>
    
    <div class="header-actions">
      {#if store.canNavigateUp}
        <button class="icon-button" onclick={navigateUp} title="Navigate up">
          <ChevronUp size={16} />
        </button>
      {/if}
      
      <button class="icon-button" onclick={refresh} title="Refresh">
        <RefreshCw size={16} />
      </button>
    </div>
  </div>
  
  <div class="file-browser-content">
    {#if store.loading}
      <div class="loading-state">
        <div class="spinner"></div>
        <p>Loading files...</p>
      </div>
    {:else if store.error}
      <div class="error-state">
        <p class="error-message">Failed to load files</p>
        <p class="error-detail">{store.error.message}</p>
        <button class="retry-button" onclick={refresh}>Try Again</button>
      </div>
    {:else if store.listing}
      <FileList 
        items={store.fileSystemItems}
        onSelectFile={handleFileSelect}
        onSelectDirectory={handleDirectorySelect}
      />
      
      {#if store.listing.virtual_count > 0}
        <div class="virtual-files-info">
          <span class="sparkle">✨</span>
          {store.listing.virtual_count} virtual {store.listing.virtual_count === 1 ? 'file' : 'files'} generated
        </div>
      {/if}
    {/if}
  </div>
  
  {#if showVirtualContent && store.virtualContent}
    <div class="virtual-content-overlay">
      <div class="virtual-content-container">
        <div class="virtual-content-header">
          <h3>{store.virtualContent.path.split('/').pop()}</h3>
          <button class="close-button" onclick={closeVirtualContent}>
            <X size={20} />
          </button>
        </div>
        <MarkdownViewer content={store.virtualContent} />
      </div>
    </div>
  {/if}
</div>

<style>
  .file-browser {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: var(--color-background);
  }
  
  .file-browser-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.75rem 1rem;
    background: var(--color-surface);
    border-bottom: 1px solid var(--color-border);
  }
  
  .breadcrumbs {
    display: flex;
    align-items: center;
    gap: 0.25rem;
    font-size: 0.875rem;
    overflow-x: auto;
    max-width: calc(100% - 80px);
  }
  
  .breadcrumb-separator {
    color: var(--color-text-secondary);
  }
  
  .breadcrumb-item {
    padding: 0.25rem 0.5rem;
    background: none;
    border: none;
    color: var(--color-primary);
    cursor: pointer;
    border-radius: 0.25rem;
    white-space: nowrap;
  }
  
  .breadcrumb-item:hover {
    background: var(--color-primary-alpha);
  }
  
  .header-actions {
    display: flex;
    gap: 0.5rem;
  }
  
  .icon-button {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 2rem;
    height: 2rem;
    padding: 0;
    background: none;
    border: 1px solid var(--color-border);
    border-radius: 0.375rem;
    color: var(--color-text-secondary);
    cursor: pointer;
    transition: all 0.2s;
  }
  
  .icon-button:hover {
    background: var(--color-surface-hover);
    color: var(--color-text);
  }
  
  .file-browser-content {
    flex: 1;
    overflow-y: auto;
    position: relative;
  }
  
  .loading-state,
  .error-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    padding: 2rem;
    text-align: center;
  }
  
  .spinner {
    width: 2rem;
    height: 2rem;
    border: 2px solid var(--color-border);
    border-top-color: var(--color-primary);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    margin-bottom: 1rem;
  }
  
  @keyframes spin {
    to { transform: rotate(360deg); }
  }
  
  .error-message {
    font-weight: 500;
    color: var(--color-error);
    margin-bottom: 0.5rem;
  }
  
  .error-detail {
    font-size: 0.875rem;
    color: var(--color-text-secondary);
    margin-bottom: 1rem;
  }
  
  .retry-button {
    padding: 0.5rem 1rem;
    background: var(--color-primary);
    color: white;
    border: none;
    border-radius: 0.375rem;
    cursor: pointer;
  }
  
  .retry-button:hover {
    background: var(--color-primary-hover);
  }
  
  .virtual-files-info {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1rem;
    background: var(--color-info-background);
    color: var(--color-info-text);
    font-size: 0.875rem;
    border-top: 1px solid var(--color-border);
  }
  
  .sparkle {
    font-size: 1.125rem;
  }
  
  .virtual-content-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    padding: 2rem;
  }
  
  .virtual-content-container {
    background: var(--color-background);
    border-radius: 0.5rem;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
    max-width: 48rem;
    width: 100%;
    max-height: 80vh;
    display: flex;
    flex-direction: column;
  }
  
  .virtual-content-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.5rem;
    border-bottom: 1px solid var(--color-border);
  }
  
  .virtual-content-header h3 {
    margin: 0;
    font-size: 1.125rem;
  }
  
  .close-button {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 2rem;
    height: 2rem;
    padding: 0;
    background: none;
    border: none;
    border-radius: 0.375rem;
    color: var(--color-text-secondary);
    cursor: pointer;
  }
  
  .close-button:hover {
    background: var(--color-surface-hover);
    color: var(--color-text);
  }
</style>