<script lang="ts">
  import type { VFSContent } from '$lib/types/storage';
  import { marked } from 'marked';
  import { onMount } from 'svelte';
  
  interface Props {
    content: VFSContent;
  }
  
  let { content }: Props = $props();
  let renderedHTML = $state('');
  
  onMount(() => {
    // Configure marked for better code highlighting
    marked.setOptions({
      breaks: true,
      gfm: true,
      headerIds: true,
      mangle: false
    });
    
    // Render the markdown content
    renderedHTML = marked(content.content);
  });
  
  // Extract metadata from HTML comments if present
  const metadata = $derived(() => {
    const metaMatch = content.content.match(/<!-- ({.*?}) -->/);
    if (metaMatch) {
      try {
        return JSON.parse(metaMatch[1]);
      } catch {
        return null;
      }
    }
    return null;
  });
</script>

<div class="markdown-viewer">
  {#if metadata}
    <div class="metadata">
      <span class="metadata-type">{metadata.kyozo?.type || 'Document'}</span>
      {#if metadata.kyozo?.generated_at}
        <span class="metadata-date">
          Generated {new Date(metadata.kyozo.generated_at).toLocaleDateString()}
        </span>
      {/if}
    </div>
  {/if}
  
  <div class="markdown-content" bind:innerHTML={renderedHTML}></div>
</div>

<style>
  .markdown-viewer {
    flex: 1;
    overflow-y: auto;
    padding: 1.5rem;
  }
  
  .metadata {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 0.5rem 0.75rem;
    background: var(--color-info-background-subtle);
    border-radius: 0.375rem;
    margin-bottom: 1.5rem;
    font-size: 0.875rem;
  }
  
  .metadata-type {
    font-weight: 500;
    color: var(--color-info-text);
  }
  
  .metadata-date {
    color: var(--color-text-secondary);
  }
  
  /* Markdown content styling */
  .markdown-content {
    line-height: 1.6;
    color: var(--color-text);
  }
  
  .markdown-content :global(h1) {
    font-size: 2rem;
    font-weight: 700;
    margin: 2rem 0 1rem;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid var(--color-border);
  }
  
  .markdown-content :global(h2) {
    font-size: 1.5rem;
    font-weight: 600;
    margin: 1.5rem 0 0.75rem;
  }
  
  .markdown-content :global(h3) {
    font-size: 1.25rem;
    font-weight: 600;
    margin: 1.25rem 0 0.5rem;
  }
  
  .markdown-content :global(p) {
    margin: 0.75rem 0;
  }
  
  .markdown-content :global(ul),
  .markdown-content :global(ol) {
    margin: 0.75rem 0;
    padding-left: 1.5rem;
  }
  
  .markdown-content :global(li) {
    margin: 0.25rem 0;
  }
  
  .markdown-content :global(code) {
    background: var(--color-surface);
    padding: 0.125rem 0.375rem;
    border-radius: 0.25rem;
    font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
    font-size: 0.875em;
  }
  
  .markdown-content :global(pre) {
    background: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.375rem;
    padding: 1rem;
    overflow-x: auto;
    margin: 1rem 0;
  }
  
  .markdown-content :global(pre code) {
    background: none;
    padding: 0;
    font-size: 0.875rem;
  }
  
  .markdown-content :global(blockquote) {
    border-left: 4px solid var(--color-primary);
    margin: 1rem 0;
    padding-left: 1rem;
    color: var(--color-text-secondary);
  }
  
  .markdown-content :global(a) {
    color: var(--color-primary);
    text-decoration: none;
  }
  
  .markdown-content :global(a:hover) {
    text-decoration: underline;
  }
  
  .markdown-content :global(table) {
    border-collapse: collapse;
    width: 100%;
    margin: 1rem 0;
  }
  
  .markdown-content :global(th),
  .markdown-content :global(td) {
    border: 1px solid var(--color-border);
    padding: 0.5rem;
    text-align: left;
  }
  
  .markdown-content :global(th) {
    background: var(--color-surface);
    font-weight: 600;
  }
  
  .markdown-content :global(hr) {
    border: none;
    border-top: 1px solid var(--color-border);
    margin: 2rem 0;
  }
  
  /* Code block language labels */
  .markdown-content :global(pre[class*="language-"])::before {
    content: attr(class);
    display: block;
    background: var(--color-surface-hover);
    padding: 0.25rem 0.5rem;
    margin: -1rem -1rem 0.5rem;
    border-radius: 0.375rem 0.375rem 0 0;
    font-size: 0.75rem;
    color: var(--color-text-secondary);
    text-transform: uppercase;
  }
  
  .markdown-content :global(pre.language-bash)::before { content: 'bash'; }
  .markdown-content :global(pre.language-elixir)::before { content: 'elixir'; }
  .markdown-content :global(pre.language-javascript)::before { content: 'javascript'; }
  .markdown-content :global(pre.language-typescript)::before { content: 'typescript'; }
  .markdown-content :global(pre.language-python)::before { content: 'python'; }
  .markdown-content :global(pre.language-dockerfile)::before { content: 'dockerfile'; }
  .markdown-content :global(pre.language-yaml)::before { content: 'yaml'; }
  .markdown-content :global(pre.language-json)::before { content: 'json'; }
</style>