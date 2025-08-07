<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import type { ComponentProps } from 'svelte';
  import { Button } from '../ui/button';
  import { Card, CardContent, CardHeader, CardTitle } from '../ui/card';
  import { Badge } from '../ui/badge';
  import { Input } from '../ui/input';
  import { Textarea } from '../ui/textarea';
  import { Separator } from '../ui/separator';
  import { 
    Save, 
    X, 
    FileText, 
    BookOpen, 
    Eye, 
    EyeOff,
    Code,
    Type,
    Maximize2,
    Minimize2,
    Download,
    Copy,
    RotateCcw,
    Settings,
    Palette
  } from '@lucide/svelte';
  import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger, DropdownMenuSeparator } from '../ui/dropdown-menu';

  let { file = null, content = '', workspace = null, is_editing = false, live } = $props<{
    file: any;
    content: string;
    workspace: any;
    is_editing: boolean;
    live: any;
  }>();

  let editorContent = $state(content);
  let fileName = $state(file?.name || file?.file_name || file?.title || 'Untitled');
  let isPreviewMode = $state(false);
  let isFullscreen = $state(false);
  let isDirty = $state(false);
  let wordCount = $state(0);
  let charCount = $state(0);
  let lineCount = $state(1);
  let selectedText = $state('');
  let cursorPosition = $state(0);
  let editorTheme = $state('light');
  let fontSize = $state(14);
  let autoSave = $state(true);
  let autoSaveTimer = $state<ReturnType<typeof setTimeout> | null>(null);
  let lastSaved = $state<Date | null>(null);

  // Editor settings
  let showLineNumbers = $state(true);
  let wordWrap = $state(true);
  let showMinimap = $state(false);
  let tabSize = $state(2);

  // Push event function
  function pushEvent(event: string, data: any = {}) {
    if (live && typeof live.pushEvent === 'function') {
      live.pushEvent(event, data);
    }
  }

  $effect(() => {
    if (editorContent !== content) {
      isDirty = true;
      updateStats();
      
      if (autoSave && file) {
        if (autoSaveTimer) clearTimeout(autoSaveTimer);
        autoSaveTimer = setTimeout(() => {
          handleSave();
        }, 2000);
      }
    }
  });

  function updateStats() {
    charCount = editorContent.length;
    wordCount = editorContent.trim() ? editorContent.trim().split(/\s+/).length : 0;
    lineCount = editorContent.split('\n').length;
  }

  function handleSave() {
    if (!isDirty) return;
    
    const saveData = {
      file: {
        name: fileName,
        content: editorContent
      }
    };

    if (file) {
      pushEvent('update_file', saveData);
    } else {
      pushEvent('create_file', saveData);
    }
    
    isDirty = false;
    lastSaved = new Date();
    if (autoSaveTimer) clearTimeout(autoSaveTimer);
  }

  function handleCancel() {
    if (isDirty) {
      if (confirm('You have unsaved changes. Are you sure you want to cancel?')) {
        pushEvent('cancel_edit', {});
      }
    } else {
      pushEvent('cancel_edit', {});
    }
  }

  function togglePreview() {
    isPreviewMode = !isPreviewMode;
  }

  function toggleFullscreen() {
    isFullscreen = !isFullscreen;
    
    if (isFullscreen) {
      document.documentElement.requestFullscreen?.();
    } else {
      document.exitFullscreen?.();
    }
  }

  function handleKeyDown(event: KeyboardEvent) {
    // Ctrl+S or Cmd+S to save
    if ((event.ctrlKey || event.metaKey) && event.key === 's') {
      event.preventDefault();
      handleSave();
    }
    
    // Ctrl+/ or Cmd+/ to toggle preview
    if ((event.ctrlKey || event.metaKey) && event.key === '/') {
      event.preventDefault();
      togglePreview();
    }
    
    // Escape to exit fullscreen
    if (event.key === 'Escape' && isFullscreen) {
      toggleFullscreen();
    }
  }

  function insertText(text: string) {
    const textarea = document.querySelector('.editor-textarea') as HTMLTextAreaElement;
    if (!textarea) return;
    
    const start = textarea.selectionStart;
    const end = textarea.selectionEnd;
    
    editorContent = editorContent.substring(0, start) + text + editorContent.substring(end);
    
    // Set cursor position after inserted text
    setTimeout(() => {
      textarea.selectionStart = textarea.selectionEnd = start + text.length;
      textarea.focus();
    }, 0);
  }

  function formatSelectedText(wrapper: string) {
    const textarea = document.querySelector('.editor-textarea') as HTMLTextAreaElement;
    if (!textarea) return;
    
    const start = textarea.selectionStart;
    const end = textarea.selectionEnd;
    const selectedText = editorContent.substring(start, end);
    
    if (selectedText) {
      const formatted = `${wrapper}${selectedText}${wrapper}`;
      editorContent = editorContent.substring(0, start) + formatted + editorContent.substring(end);
      
      setTimeout(() => {
        textarea.selectionStart = start + wrapper.length;
        textarea.selectionEnd = end + wrapper.length;
        textarea.focus();
      }, 0);
    }
  }

  function handleTextSelection(event: Event) {
    const textarea = event.target as HTMLTextAreaElement;
    selectedText = textarea.value.substring(textarea.selectionStart, textarea.selectionEnd);
    cursorPosition = textarea.selectionStart;
  }

  function copyToClipboard() {
    navigator.clipboard.writeText(editorContent);
  }

  function downloadFile() {
    const blob = new Blob([editorContent], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = fileName || 'file.txt';
    a.click();
    URL.revokeObjectURL(url);
  }

  function resetContent() {
    if (confirm('Are you sure you want to reset to the original content?')) {
      editorContent = content;
      isDirty = false;
    }
  }

  function getFileIcon() {
    if (!file) return FileText;
    
    const type = file.__struct__?.includes('Notebook') ? 'notebook' : 'document';
    return type === 'notebook' ? BookOpen : FileText;
  }

  function renderMarkdown(markdown: string) {
    // Simple markdown rendering for preview
    return markdown
      .replace(/^### (.*$)/gim, '<h3>$1</h3>')
      .replace(/^## (.*$)/gim, '<h2>$1</h2>')
      .replace(/^# (.*$)/gim, '<h1>$1</h1>')
      .replace(/^\* (.*$)/gim, '<li>$1</li>')
      .replace(/\*\*(.*)\*\*/gim, '<strong>$1</strong>')
      .replace(/\*(.*)\*/gim, '<em>$1</em>')
      .replace(/`(.*)`/gim, '<code>$1</code>')
      .replace(/\n/gim, '<br>');
  }

  onMount(() => {
    updateStats();
    document.addEventListener('keydown', handleKeyDown);
    
    // Auto-save every 30 seconds if there are changes
    const autoSaveInterval = setInterval(() => {
      if (isDirty && autoSave && file) {
        handleSave();
      }
    }, 30000);
    
    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      clearInterval(autoSaveInterval);
      if (autoSaveTimer) clearTimeout(autoSaveTimer);
    };
  });

  onDestroy(() => {
    if (autoSaveTimer) clearTimeout(autoSaveTimer);
  });
</script>

<div class="flex flex-col h-full bg-background {isFullscreen ? 'fixed inset-0 z-50' : ''}">
  <!-- Header -->
  <div class="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
    <div class="flex items-center justify-between p-4">
      <div class="flex items-center space-x-3">
        <svelte:component this={getFileIcon()} class="w-5 h-5 text-primary" />
        <div>
          <Input 
            bind:value={fileName}
            class="text-lg font-semibold bg-transparent border-none p-0 h-auto focus:ring-0"
            placeholder="File name"
          />
          <div class="flex items-center space-x-4 text-xs text-muted-foreground mt-1">
            <span>{workspace?.name}</span>
            <span>•</span>
            <span>{wordCount} words</span>
            <span>•</span>
            <span>{charCount} characters</span>
            <span>•</span>
            <span>{lineCount} lines</span>
            {#if lastSaved}
              <span>•</span>
              <span>Saved {lastSaved.toLocaleTimeString()}</span>
            {/if}
            {#if isDirty}
              <Badge variant="outline" class="text-xs">Unsaved</Badge>
            {/if}
          </div>
        </div>
      </div>

      <div class="flex items-center space-x-2">
        <!-- Formatting Tools -->
        <div class="flex items-center space-x-1 mr-4">
          <Button 
            size="sm" 
            variant="outline"
            on:click={() => insertText('# ')}
            title="Heading 1"
          >
            H1
          </Button>
          <Button 
            size="sm" 
            variant="outline"
            on:click={() => insertText('## ')}
            title="Heading 2"
          >
            H2
          </Button>
          <Button 
            size="sm" 
            variant="outline"
            onclick={() => formatSelectedText('**')}
            title="Bold"
          >
            <strong>B</strong>
          </Button>
          <Button 
            size="sm" 
            variant="outline"
            onclick={() => formatSelectedText('*')}
            title="Italic"
          >
            <em>I</em>
          </Button>
          <Button 
            size="sm" 
            variant="outline"
            onclick={() => formatSelectedText('`')}
            title="Code"
          >
            <Code class="w-4 h-4" />
          </Button>
        </div>

        <!-- View Controls -->
        <Button 
          size="sm" 
          variant={isPreviewMode ? 'default' : 'outline'}
          onclick={togglePreview}
        >
          {#if isPreviewMode}
            <EyeOff class="w-4 h-4 mr-1" />
            Edit
          {:else}
            <Eye class="w-4 h-4 mr-1" />
            Preview
          {/if}
        </Button>

        <Button 
          size="sm" 
          variant="outline"
          onclick={toggleFullscreen}
        >
          {#if isFullscreen}
            <Minimize2 class="w-4 h-4" />
          {:else}
            <Maximize2 class="w-4 h-4" />
          {/if}
        </Button>

        <!-- Settings Menu -->
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            {#snippet children({ props })}
              <Button {...props} size="sm" variant="outline">
                <Settings class="w-4 h-4" />
              </Button>
            {/snippet}
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onclick={() => showLineNumbers = !showLineNumbers}>
              {showLineNumbers ? '✓' : '○'} Line Numbers
            </DropdownMenuItem>
            <DropdownMenuItem onclick={() => wordWrap = !wordWrap}>
              {wordWrap ? '✓' : '○'} Word Wrap
            </DropdownMenuItem>
            <DropdownMenuItem onclick={() => autoSave = !autoSave}>
              {autoSave ? '✓' : '○'} Auto Save
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem onclick={copyToClipboard}>
              <Copy class="w-4 h-4 mr-2" />
              Copy All
            </DropdownMenuItem>
            <DropdownMenuItem onclick={downloadFile}>
              <Download class="w-4 h-4 mr-2" />
              Download
            </DropdownMenuItem>
            <DropdownMenuItem onclick={resetContent}>
              <RotateCcw class="w-4 h-4 mr-2" />
              Reset
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>

        <Separator orientation="vertical" class="h-6" />

        <!-- Action Buttons -->
        <Button size="sm" variant="outline" onclick={handleCancel}>
          <X class="w-4 h-4 mr-1" />
          Cancel
        </Button>
        
        <Button size="sm" onclick={handleSave} disabled={!isDirty}>
          <Save class="w-4 h-4 mr-1" />
          Save
        </Button>
      </div>
    </div>
  </div>

  <!-- Editor Content -->
  <div class="flex-1 flex min-h-0">
    {#if isPreviewMode}
      <!-- Preview Mode -->
      <div class="flex-1 overflow-auto">
        <div class="max-w-4xl mx-auto p-8">
          <div class="prose prose-slate dark:prose-invert max-w-none">
            {@html renderMarkdown(editorContent)}
          </div>
        </div>
      </div>
    {:else}
      <!-- Edit Mode -->
      <div class="flex-1 flex">
        <!-- Line Numbers (optional) -->
        {#if showLineNumbers}
          <div class="w-12 bg-muted/30 border-r p-2 text-right text-xs text-muted-foreground font-mono select-none">
            {#each Array(lineCount) as _, i}
              <div class="leading-6">{i + 1}</div>
            {/each}
          </div>
        {/if}

        <!-- Editor -->
        <div class="flex-1 relative">
          <Textarea
            bind:value={editorContent}
            class="editor-textarea w-full h-full resize-none border-none focus:ring-0 font-mono text-sm leading-6 {wordWrap ? '' : 'whitespace-nowrap overflow-x-auto'}"
            placeholder={file ? "Start writing..." : "Enter your content here..."}
            style="font-size: {fontSize}px;"
            onselect={handleTextSelection}
            onkeyup={handleTextSelection}
            onclick={handleTextSelection}
          />
          
          <!-- Status Bar -->
          <div class="absolute bottom-2 right-2 bg-background/80 backdrop-blur rounded px-2 py-1 text-xs text-muted-foreground">
            Ln {cursorPosition + 1}, Col {cursorPosition + 1}
            {#if selectedText}
              • {selectedText.length} selected
            {/if}
          </div>
        </div>
      </div>
    {/if}
  </div>

  <!-- Footer -->
  <div class="border-t bg-muted/30 px-4 py-2">
    <div class="flex items-center justify-between text-xs text-muted-foreground">
      <div class="flex items-center space-x-4">
        <span>
          {file ? 'Editing' : 'Creating'} {fileName}
        </span>
        <span>•</span>
        <span>
          {getFileIcon() === BookOpen ? 'Notebook' : 'Document'}
        </span>
        {#if autoSave}
          <span>•</span>
          <span>Auto-save enabled</span>
        {/if}
      </div>
      
      <div class="flex items-center space-x-4">
        <span>
          Ctrl+S to save • Ctrl+/ to preview • Esc to exit fullscreen
        </span>
      </div>
    </div>
  </div>
</div>

<style>
  .editor-textarea {
    font-family: 'JetBrains Mono', 'Fira Code', 'Monaco', 'Cascadia Code', 'Roboto Mono', monospace;
  }
  
  .prose {
    max-width: none;
  }
  
  .prose h1 {
    @apply text-2xl font-bold mt-6 mb-4;
  }
  
  .prose h2 {
    @apply text-xl font-semibold mt-5 mb-3;
  }
  
  .prose h3 {
    @apply text-lg font-medium mt-4 mb-2;
  }
  
  .prose code {
    @apply bg-muted px-1 py-0.5 rounded text-sm;
  }
  
  .prose pre {
    @apply bg-muted p-4 rounded-lg overflow-x-auto;
  }
  
  .prose blockquote {
    @apply border-l-4 border-primary pl-4 italic;
  }
  
  .prose ul {
    @apply list-disc list-inside space-y-1;
  }
  
  .prose ol {
    @apply list-decimal list-inside space-y-1;
  }
</style>