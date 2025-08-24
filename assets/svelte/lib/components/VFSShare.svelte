<script lang="ts">
  import { Share2, Copy, ExternalLink, Download, Check } from '@lucide/svelte';
  import { storageAPI } from '$lib/api/storage';
  import type { VFSFile } from '$lib/types/storage';
  
  interface Props {
    file: VFSFile;
    teamId: string;
    workspaceId: string;
  }
  
  let { file, teamId, workspaceId }: Props = $props();
  
  let showShareDialog = $state(false);
  let shareUrl = $state('');
  let isSharing = $state(false);
  let copied = $state(false);
  let shareExpiry = $state('24h');
  
  const expiryOptions = [
    { value: '1h', label: '1 hour', seconds: 3600 },
    { value: '24h', label: '24 hours', seconds: 86400 },
    { value: '7d', label: '7 days', seconds: 604800 },
    { value: '30d', label: '30 days', seconds: 2592000 }
  ];
  
  async function createShare() {
    isSharing = true;
    
    try {
      const ttl = expiryOptions.find(opt => opt.value === shareExpiry)?.seconds || 86400;
      
      const response = await storageAPI.createShare(teamId, workspaceId, {
        path: file.path,
        ttl
      });
      
      shareUrl = response.url;
    } catch (error) {
      console.error('Failed to create share:', error);
    } finally {
      isSharing = false;
    }
  }
  
  async function copyToClipboard() {
    try {
      await navigator.clipboard.writeText(shareUrl);
      copied = true;
      setTimeout(() => copied = false, 2000);
    } catch (error) {
      console.error('Failed to copy:', error);
    }
  }
  
  async function exportFile(format: 'pdf' | 'html') {
    try {
      const url = `/api/v1/teams/${teamId}/workspaces/${workspaceId}/storage/vfs/export?path=${encodeURIComponent(file.path)}&format=${format}`;
      window.open(url, '_blank');
    } catch (error) {
      console.error('Failed to export:', error);
    }
  }
</script>

<div class="vfs-share-actions">
  <button 
    class="action-button"
    onclick={() => showShareDialog = true}
    title="Share virtual file"
  >
    <Share2 size={16} />
  </button>
  
  <button
    class="action-button"
    onclick={() => exportFile('html')}
    title="Export as HTML"
  >
    <Download size={16} />
  </button>
</div>

{#if showShareDialog}
  <div class="share-dialog-overlay" onclick={() => showShareDialog = false}>
    <div class="share-dialog" onclick={(e) => e.stopPropagation()}>
      <h3>Share "{file.name}"</h3>
      
      {#if !shareUrl}
        <div class="share-options">
          <label>
            Link expires after:
            <select bind:value={shareExpiry}>
              {#each expiryOptions as option}
                <option value={option.value}>{option.label}</option>
              {/each}
            </select>
          </label>
          
          <button 
            class="primary-button"
            onclick={createShare}
            disabled={isSharing}
          >
            {isSharing ? 'Creating...' : 'Create Share Link'}
          </button>
        </div>
      {:else}
        <div class="share-result">
          <div class="share-url">
            <input 
              type="text" 
              value={shareUrl} 
              readonly
              onclick={(e) => e.currentTarget.select()}
            />
            <button 
              class="copy-button"
              onclick={copyToClipboard}
              title="Copy to clipboard"
            >
              {#if copied}
                <Check size={16} />
              {:else}
                <Copy size={16} />
              {/if}
            </button>
          </div>
          
          <div class="share-actions">
            <a 
              href={shareUrl}
              target="_blank"
              rel="noopener noreferrer"
              class="open-link"
            >
              <ExternalLink size={16} />
              Open in new tab
            </a>
          </div>
          
          <p class="share-note">
            This link will expire in {shareExpiry}.
          </p>
        </div>
      {/if}
      
      <button 
        class="close-button"
        onclick={() => showShareDialog = false}
      >
        Close
      </button>
    </div>
  </div>
{/if}

<style>
  .vfs-share-actions {
    display: flex;
    gap: 0.5rem;
  }
  
  .action-button {
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
  
  .action-button:hover {
    background: var(--color-surface-hover);
    color: var(--color-text);
  }
  
  .share-dialog-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }
  
  .share-dialog {
    background: var(--color-background);
    border-radius: 0.5rem;
    padding: 1.5rem;
    max-width: 24rem;
    width: 90%;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
  }
  
  .share-dialog h3 {
    margin: 0 0 1rem;
    font-size: 1.125rem;
  }
  
  .share-options {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  
  .share-options label {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    font-size: 0.875rem;
    font-weight: 500;
  }
  
  .share-options select {
    padding: 0.5rem;
    border: 1px solid var(--color-border);
    border-radius: 0.375rem;
    background: var(--color-surface);
  }
  
  .primary-button {
    padding: 0.5rem 1rem;
    background: var(--color-primary);
    color: white;
    border: none;
    border-radius: 0.375rem;
    font-weight: 500;
    cursor: pointer;
  }
  
  .primary-button:hover {
    background: var(--color-primary-hover);
  }
  
  .primary-button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  .share-result {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  
  .share-url {
    display: flex;
    gap: 0.5rem;
  }
  
  .share-url input {
    flex: 1;
    padding: 0.5rem;
    border: 1px solid var(--color-border);
    border-radius: 0.375rem;
    font-family: monospace;
    font-size: 0.875rem;
  }
  
  .copy-button {
    padding: 0.5rem;
    background: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.375rem;
    cursor: pointer;
    display: flex;
    align-items: center;
    color: var(--color-text-secondary);
  }
  
  .copy-button:hover {
    background: var(--color-surface-hover);
  }
  
  .open-link {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    color: var(--color-primary);
    text-decoration: none;
    font-size: 0.875rem;
  }
  
  .open-link:hover {
    text-decoration: underline;
  }
  
  .share-note {
    margin: 0;
    font-size: 0.75rem;
    color: var(--color-text-secondary);
  }
  
  .close-button {
    margin-top: 1rem;
    padding: 0.5rem 1rem;
    background: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.375rem;
    cursor: pointer;
    width: 100%;
  }
  
  .close-button:hover {
    background: var(--color-surface-hover);
  }
</style>