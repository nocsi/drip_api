<script lang="ts">
  import type { FileSystemItem } from '$lib/types/storage';
  import { getFileIcon, formatFileSize } from '$lib/types/storage';
  import { Folder, File, Sparkles } from '@lucide/svelte';
  
  interface Props {
    items: FileSystemItem[];
    onSelectFile: (path: string, isVirtual: boolean) => void;
    onSelectDirectory: (path: string) => void;
  }
  
  let { items, onSelectFile, onSelectDirectory }: Props = $props();
  
  function handleItemClick(item: FileSystemItem) {
    if (item.type === 'directory') {
      onSelectDirectory(item.file.path);
    } else {
      onSelectFile(item.file.path, item.type === 'virtual');
    }
  }
  
  function getItemClass(item: FileSystemItem): string {
    const classes = ['file-item'];
    if (item.type === 'directory') classes.push('directory');
    if (item.type === 'virtual') classes.push('virtual');
    return classes.join(' ');
  }
</script>

<div class="file-list">
  {#each items as item}
    <button 
      class={getItemClass(item)}
      onclick={() => handleItemClick(item)}
    >
      <div class="file-icon">
        {getFileIcon(item)}
      </div>
      
      <div class="file-info">
        <div class="file-name">
          {item.file.name}
        </div>
        
        {#if item.type === 'virtual'}
          <div class="file-meta">
            <Sparkles size={12} />
            <span>Virtual • {item.file.generator || 'Generated'}</span>
          </div>
        {:else if item.type !== 'directory'}
          <div class="file-meta">
            {formatFileSize(item.file.size)}
          </div>
        {/if}
      </div>
      
      {#if item.type === 'directory'}
        <div class="chevron">›</div>
      {/if}
    </button>
  {/each}
  
  {#if items.length === 0}
    <div class="empty-state">
      <File size={48} />
      <p>No files in this directory</p>
    </div>
  {/if}
</div>

<style>
  .file-list {
    display: flex;
    flex-direction: column;
  }
  
  .file-item {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.75rem 1rem;
    background: none;
    border: none;
    border-bottom: 1px solid var(--color-border);
    text-align: left;
    cursor: pointer;
    transition: background-color 0.2s;
    width: 100%;
  }
  
  .file-item:hover {
    background: var(--color-surface-hover);
  }
  
  .file-item:active {
    background: var(--color-surface-active);
  }
  
  .file-item.virtual {
    background: var(--color-info-background-subtle);
  }
  
  .file-item.virtual:hover {
    background: var(--color-info-background);
  }
  
  .file-icon {
    font-size: 1.5rem;
    line-height: 1;
    flex-shrink: 0;
  }
  
  .file-info {
    flex: 1;
    min-width: 0;
  }
  
  .file-name {
    font-size: 0.875rem;
    font-weight: 500;
    color: var(--color-text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  
  .file-meta {
    display: flex;
    align-items: center;
    gap: 0.25rem;
    font-size: 0.75rem;
    color: var(--color-text-secondary);
    margin-top: 0.125rem;
  }
  
  .chevron {
    font-size: 1.25rem;
    color: var(--color-text-secondary);
    flex-shrink: 0;
  }
  
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 3rem;
    color: var(--color-text-secondary);
    gap: 1rem;
  }
  
  .empty-state p {
    margin: 0;
    font-size: 0.875rem;
  }
  
  /* Define color variables for light/dark mode */
  :root {
    --color-background: #ffffff;
    --color-surface: #f9fafb;
    --color-surface-hover: #f3f4f6;
    --color-surface-active: #e5e7eb;
    --color-border: #e5e7eb;
    --color-text: #111827;
    --color-text-secondary: #6b7280;
    --color-primary: #3b82f6;
    --color-primary-hover: #2563eb;
    --color-primary-alpha: rgba(59, 130, 246, 0.1);
    --color-error: #ef4444;
    --color-info-background: #dbeafe;
    --color-info-background-subtle: #eff6ff;
    --color-info-text: #1e40af;
  }
  
  @media (prefers-color-scheme: dark) {
    :root {
      --color-background: #0f172a;
      --color-surface: #1e293b;
      --color-surface-hover: #334155;
      --color-surface-active: #475569;
      --color-border: #334155;
      --color-text: #f1f5f9;
      --color-text-secondary: #94a3b8;
      --color-primary: #3b82f6;
      --color-primary-hover: #60a5fa;
      --color-primary-alpha: rgba(59, 130, 246, 0.2);
      --color-error: #f87171;
      --color-info-background: #1e3a8a;
      --color-info-background-subtle: #1e293b;
      --color-info-text: #93bbfc;
    }
  }
</style>