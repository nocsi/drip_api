<script lang="ts">
  import { onMount, onDestroy, createEventDispatcher } from 'svelte';
  import type { LiveSvelteProps } from '../liveSvelte';
  import Editor from '../Editor.svelte';
  import { Button } from '../ui/button';
  import { Card, CardContent, CardHeader, CardTitle } from '../ui/card';
  import { Badge } from '../ui/badge';
  import { Input } from '../ui/input';
  import { Label } from '../ui/label';
  import { Textarea } from '../ui/textarea';
  import { Separator } from '../ui/separator';
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
  import {
    FileText,
    Save,
    Download,
    Share,
    Eye,
    Edit,
    Clock,
    User,
    Calendar,
    Tag,
    MoreHorizontal,
    History,
    Settings,
    ArrowLeft,
    AlertCircle,
    CheckCircle,
    Loader2,
    Copy,
    ExternalLink,
    FileIcon
  } from '@lucide/svelte';

  // Props from LiveView
  interface Props {
    document?: any;
    currentUser: any;
    currentTeam: any;
    workspace?: any;
    isEditing?: boolean;
    canEdit?: boolean;
    canShare?: boolean;
    versions?: any[];
    collaborators?: any[];
    apiToken?: string;
    csrfToken?: string;
    apiBaseUrl?: string;
  }

  let {
    document = null,
    currentUser,
    currentTeam,
    workspace = null,
    isEditing = false,
    canEdit = true,
    canShare = true,
    versions = [],
    collaborators = [],
    apiToken = '',
    csrfToken = '',
    apiBaseUrl = '/api/v1'
  }: Props = $props();

  // Component state
  let content = $state(document?.content || '');
  let title = $state(document?.title || '');
  let description = $state(document?.description || '');
  let tags = $state(document?.tags || []);
  let loading = $state(false);
  let saving = $state(false);
  let error = $state(null);
  let hasUnsavedChanges = $state(false);
  let lastSaved = $state(document?.updated_at || null);
  let autoSaveTimeout: NodeJS.Timeout | null = null;
  let showVersionHistory = $state(false);
  let showSettings = $state(false);
  let showShareModal = $state(false);
  let editMode = $state(isEditing);
  let newTag = $state('');

  // Form state
  let shareForm = $state({
    emails: '',
    permission: 'view',
    message: ''
  });

  let settingsForm = $state({
    title: title,
    description: description,
    content_type: document?.content_type || 'markdown',
    is_public: document?.is_public || false,
    tags: tags.join(', ')
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

    async updateDocument(documentId: string, data: any) {
      return this.request(`/documents/${documentId}`, {
        method: 'PUT',
        body: JSON.stringify({ document: data })
      });
    },

    async updateContent(documentId: string, content: string, commitMessage = 'Update content') {
      return this.request(`/documents/${documentId}/content`, {
        method: 'PUT',
        body: JSON.stringify({ content, commit_message: commitMessage })
      });
    },

    async getVersions(documentId: string) {
      return this.request(`/documents/${documentId}/versions`);
    },

    async getContent(documentId: string, version?: string) {
      const endpoint = version 
        ? `/documents/${documentId}/content?version=${version}`
        : `/documents/${documentId}/content`;
      return this.request(endpoint);
    },

    async shareDocument(documentId: string, shareData: any) {
      return this.request(`/documents/${documentId}/share`, {
        method: 'POST',
        body: JSON.stringify(shareData)
      });
    },

    async renderAs(documentId: string, format: string, options = {}) {
      return this.request(`/documents/${documentId}/render/${format}`, {
        method: 'POST',
        body: JSON.stringify({ options })
      });
    }
  };

  // Auto-save functionality
  function scheduleAutoSave() {
    if (autoSaveTimeout) {
      clearTimeout(autoSaveTimeout);
    }
    
    autoSaveTimeout = setTimeout(() => {
      handleAutoSave();
    }, 2000); // Auto-save after 2 seconds of inactivity
  }

  async function handleAutoSave() {
    if (!document?.id || !hasUnsavedChanges || saving) return;

    try {
      await saveContent();
    } catch (err) {
      console.error('Auto-save failed:', err);
    }
  }

  async function saveContent(commitMessage = 'Auto-save changes') {
    if (!document?.id || saving) return;

    saving = true;
    try {
      const response = await apiClient.updateContent(document.id, content, commitMessage);
      lastSaved = new Date().toISOString();
      hasUnsavedChanges = false;
      dispatch('contentSaved', { document: response.data, content });
    } catch (err) {
      error = err.message;
      throw err;
    } finally {
      saving = false;
    }
  }

  async function saveDocument() {
    if (!document?.id || saving) return;

    saving = true;
    try {
      const response = await apiClient.updateDocument(document.id, {
        title: settingsForm.title,
        description: settingsForm.description,
        content_type: settingsForm.content_type,
        is_public: settingsForm.is_public,
        tags: settingsForm.tags.split(',').map(t => t.trim()).filter(t => t)
      });

      title = settingsForm.title;
      description = settingsForm.description;
      tags = settingsForm.tags.split(',').map(t => t.trim()).filter(t => t);
      document = response.data;
      showSettings = false;

      dispatch('documentUpdated', { document: response.data });
    } catch (err) {
      error = err.message;
    } finally {
      saving = false;
    }
  }

  async function handleShare() {
    if (!document?.id || saving) return;

    saving = true;
    try {
      const emails = shareForm.emails.split(',').map(e => e.trim()).filter(e => e);
      await apiClient.shareDocument(document.id, {
        emails,
        permission: shareForm.permission,
        message: shareForm.message
      });

      showShareModal = false;
      shareForm = { emails: '', permission: 'view', message: '' };
      dispatch('documentShared', { document, emails });
    } catch (err) {
      error = err.message;
    } finally {
      saving = false;
    }
  }

  async function loadVersions() {
    if (!document?.id) return;

    try {
      const response = await apiClient.getVersions(document.id);
      versions = response.data || [];
    } catch (err) {
      error = err.message;
    }
  }

  async function loadVersion(version: any) {
    if (!document?.id) return;

    loading = true;
    try {
      const response = await apiClient.getContent(document.id, version.id);
      content = response.data.content || '';
      hasUnsavedChanges = true;
      showVersionHistory = false;
    } catch (err) {
      error = err.message;
    } finally {
      loading = false;
    }
  }

  async function handleDownload(format = 'markdown') {
    if (!document?.id) return;

    try {
      const response = await apiClient.renderAs(document.id, format);
      
      // Create download link
      const blob = new Blob([response.data.content], { type: 'text/plain' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `${document.title}.${format === 'markdown' ? 'md' : format}`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (err) {
      error = err.message;
    }
  }

  function handleContentChange(event: CustomEvent<string>) {
    content = event.detail;
    hasUnsavedChanges = true;
    scheduleAutoSave();
  }

  function toggleEditMode() {
    editMode = !editMode;
    dispatch('editModeChanged', { isEditing: editMode });
  }

  function addTag() {
    if (newTag.trim() && !tags.includes(newTag.trim())) {
      tags = [...tags, newTag.trim()];
      newTag = '';
    }
  }

  function removeTag(tagToRemove: string) {
    tags = tags.filter(tag => tag !== tagToRemove);
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

  // Watch for changes to update forms
  $effect(() => {
    if (document) {
      settingsForm.title = document.title || '';
      settingsForm.description = document.description || '';
      settingsForm.content_type = document.content_type || 'markdown';
      settingsForm.is_public = document.is_public || false;
      settingsForm.tags = (document.tags || []).join(', ');
      
      title = document.title || '';
      description = document.description || '';
      tags = document.tags || [];
      content = document.content || '';
    }
  });

  // Cleanup on destroy
  onDestroy(() => {
    if (autoSaveTimeout) {
      clearTimeout(autoSaveTimeout);
    }
    
    // Save any pending changes before leaving
    if (hasUnsavedChanges && document?.id) {
      handleAutoSave();
    }
  });

  onMount(() => {
    if (document?.id) {
      loadVersions();
    }
  });
</script>

<div class="flex h-full bg-background">
  <!-- Main Editor -->
  <div class="flex-1 flex flex-col min-w-0">
    <!-- Header -->
    <div class="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div class="p-4 space-y-4">
        <!-- Title and Actions -->
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            {#if document}
              <Button variant="ghost" size="sm" onclick={() => dispatch('back')}>
                <ArrowLeft class="w-4 h-4 mr-2" />
                Back
              </Button>
            {/if}
            
            <div class="flex items-center space-x-2">
              {#if document}
                {@const IconComponent = getContentTypeIcon(document.content_type)}
                <IconComponent class="w-5 h-5 text-primary" />
              {:else}
                <FileText class="w-5 h-5 text-primary" />
              {/if}
              <h1 class="text-xl font-semibold truncate">
                {title || 'Untitled Document'}
              </h1>
              {#if document?.is_public}
                <Badge variant="secondary" class="text-xs">Public</Badge>
              {/if}
            </div>
          </div>

          <div class="flex items-center space-x-2">
            <!-- Save Status -->
            {#if saving}
              <div class="flex items-center text-blue-600">
                <Loader2 class="w-4 h-4 mr-2 animate-spin" />
                <span class="text-sm">Saving...</span>
              </div>
            {:else if hasUnsavedChanges}
              <div class="flex items-center text-amber-600">
                <AlertCircle class="w-4 h-4 mr-2" />
                <span class="text-sm">Unsaved changes</span>
              </div>
            {:else if lastSaved}
              <div class="flex items-center text-green-600">
                <CheckCircle class="w-4 h-4 mr-2" />
                <span class="text-sm">Saved {formatDate(lastSaved)}</span>
              </div>
            {/if}

            <!-- Actions -->
            {#if canEdit && editMode}
              <Button size="sm" onclick={() => saveContent('Manual save')} disabled={saving || !hasUnsavedChanges}>
                <Save class="w-4 h-4 mr-2" />
                Save
              </Button>
            {/if}

            <DropdownMenu>
              <DropdownMenuTrigger>
                <Button variant="outline" size="sm">
                  <MoreHorizontal class="w-4 h-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                {#if canEdit}
                  <DropdownMenuItem onclick={toggleEditMode}>
                    {#if editMode}
                      <Eye class="w-4 h-4 mr-2" />
                      Preview
                    {:else}
                      <Edit class="w-4 h-4 mr-2" />
                      Edit
                    {/if}
                  </DropdownMenuItem>
                  <DropdownMenuItem onclick={() => showSettings = true}>
                    <Settings class="w-4 h-4 mr-2" />
                    Settings
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                {/if}
                <DropdownMenuItem onclick={() => showVersionHistory = true}>
                  <History class="w-4 h-4 mr-2" />
                  Version History
                </DropdownMenuItem>
                {#if canShare}
                  <DropdownMenuItem onclick={() => showShareModal = true}>
                    <Share class="w-4 h-4 mr-2" />
                    Share
                  </DropdownMenuItem>
                {/if}
                <DropdownMenuSeparator />
                <DropdownMenuItem onclick={() => handleDownload('markdown')}>
                  <Download class="w-4 h-4 mr-2" />
                  Download
                </DropdownMenuItem>
                {#if document?.is_public}
                  <DropdownMenuItem onclick={() => dispatch('viewPublic', { document })}>
                    <ExternalLink class="w-4 h-4 mr-2" />
                    Public Link
                  </DropdownMenuItem>
                {/if}
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>

        <!-- Document Meta -->
        {#if document}
          <div class="flex items-center space-x-4 text-sm text-muted-foreground">
            <div class="flex items-center space-x-1">
              <User class="w-4 h-4" />
              <span>{document.author?.name || currentUser?.name || 'Unknown'}</span>
            </div>
            <div class="flex items-center space-x-1">
              <Calendar class="w-4 h-4" />
              <span>Modified {formatDate(document.updated_at)}</span>
            </div>
            {#if tags.length > 0}
              <div class="flex items-center space-x-1">
                <Tag class="w-4 h-4" />
                <div class="flex space-x-1">
                  {#each tags.slice(0, 3) as tag}
                    <Badge variant="secondary" class="text-xs">{tag}</Badge>
                  {/each}
                  {#if tags.length > 3}
                    <Badge variant="secondary" class="text-xs">+{tags.length - 3}</Badge>
                  {/if}
                </div>
              </div>
            {/if}
            {#if collaborators.length > 0}
              <div class="flex items-center space-x-1">
                <span>{collaborators.length} collaborator{collaborators.length !== 1 ? 's' : ''}</span>
              </div>
            {/if}
          </div>
        {/if}
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

    <!-- Editor Content -->
    <div class="flex-1 overflow-hidden">
      <Editor
        initialContent={content}
        editable={editMode && canEdit}
        placeholder={editMode ? "Start writing your document..." : "This document is empty."}
        className="h-full"
        oncontentchange={handleContentChange}
      />
    </div>
  </div>
</div>

<!-- Settings Modal -->
<Dialog open={showSettings} onOpenChange={(open) => showSettings = open}>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Document Settings</DialogTitle>
      <DialogDescription>
        Configure document properties and metadata.
      </DialogDescription>
    </DialogHeader>
    <div class="space-y-4">
      <div>
        <Label for="settings-title">Title</Label>
        <Input
          id="settings-title"
          bind:value={settingsForm.title}
          placeholder="Document title"
        />
      </div>
      <div>
        <Label for="settings-description">Description</Label>
        <Textarea
          id="settings-description"
          bind:value={settingsForm.description}
          placeholder="Brief description of the document"
        />
      </div>
      <div>
        <Label for="settings-type">Content Type</Label>
        <select
          id="settings-type"
          bind:value={settingsForm.content_type}
          class="w-full mt-1 px-3 py-2 border rounded-md"
        >
          <option value="markdown">Markdown</option>
          <option value="html">HTML</option>
          <option value="text">Plain Text</option>
        </select>
      </div>
      <div>
        <Label for="settings-tags">Tags</Label>
        <Input
          id="settings-tags"
          bind:value={settingsForm.tags}
          placeholder="tag1, tag2, tag3"
        />
      </div>
      <div class="flex items-center space-x-2">
        <input
          type="checkbox"
          id="settings-public"
          bind:checked={settingsForm.is_public}
          class="rounded"
        />
        <Label for="settings-public">Make this document public</Label>
      </div>
      <div class="flex justify-end space-x-3">
        <Button variant="outline" onclick={() => showSettings = false}>
          Cancel
        </Button>
        <Button onclick={saveDocument} disabled={saving}>
          {#if saving}
            <Loader2 class="w-4 h-4 mr-2 animate-spin" />
          {/if}
          Save Settings
        </Button>
      </div>
    </div>
  </DialogContent>
</Dialog>

<!-- Version History Modal -->
<Dialog open={showVersionHistory} onOpenChange={(open) => showVersionHistory = open}>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Version History</DialogTitle>
      <DialogDescription>
        View and restore previous versions of this document.
      </DialogDescription>
    </DialogHeader>
    <div class="space-y-4 max-h-96 overflow-y-auto">
      {#if versions.length === 0}
        <div class="text-center py-8 text-muted-foreground">
          No version history available
        </div>
      {:else}
        {#each versions as version}
          <div class="flex items-center justify-between p-3 border rounded">
            <div>
              <div class="font-medium">{version.commit_message || 'No message'}</div>
              <div class="text-sm text-muted-foreground">
                {formatDate(version.created_at)} by {version.author?.name || 'Unknown'}
              </div>
            </div>
            <div class="flex space-x-2">
              <Button size="sm" variant="outline" onclick={() => loadVersion(version)}>
                <Clock class="w-4 h-4 mr-2" />
                Restore
              </Button>
            </div>
          </div>
        {/each}
      {/if}
    </div>
  </DialogContent>
</Dialog>

<!-- Share Modal -->
<Dialog open={showShareModal} onOpenChange={(open) => showShareModal = open}>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Share Document</DialogTitle>
      <DialogDescription>
        Share this document with others via email.
      </DialogDescription>
    </DialogHeader>
    <div class="space-y-4">
      <div>
        <Label for="share-emails">Email Addresses</Label>
        <Textarea
          id="share-emails"
          bind:value={shareForm.emails}
          placeholder="user1@example.com, user2@example.com"
        />
      </div>
      <div>
        <Label for="share-permission">Permission Level</Label>
        <select
          id="share-permission"
          bind:value={shareForm.permission}
          class="w-full mt-1 px-3 py-2 border rounded-md"
        >
          <option value="view">View Only</option>
          <option value="edit">Can Edit</option>
        </select>
      </div>
      <div>
        <Label for="share-message">Message (Optional)</Label>
        <Textarea
          id="share-message"
          bind:value={shareForm.message}
          placeholder="Add a personal message..."
        />
      </div>
      <div class="flex justify-end space-x-3">
        <Button variant="outline" onclick={() => showShareModal = false}>
          Cancel
        </Button>
        <Button onclick={handleShare} disabled={saving}>
          {#if saving}
            <Loader2 class="w-4 h-4 mr-2 animate-spin" />
          {/if}
          Share Document
        </Button>
      </div>
    </div>
  </DialogContent>
</Dialog>