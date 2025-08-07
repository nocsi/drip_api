<script lang="ts">
  import { onMount } from 'svelte';
  import WorkspaceIndex from '../workspace/index.svelte';
  import WorkspaceDashboard from '../workspace/dashboard.svelte';
  import WorkspaceShow from '../workspace/show.svelte';
  import WorkspaceFileEditor from '../workspace/file-editor.svelte';
  import { Button } from '../ui/button';
  import { Card, CardContent, CardHeader, CardTitle } from '../ui/card';
  import { AlertCircle, Home, ArrowLeft } from '@lucide/svelte';

  // Props passed from Phoenix
  let { 
    currentUser = null, 
    teams = [], 
    apiToken = '', 
    csrfToken = '', 
    apiBaseUrl = '/api/v1' 
  } = $props();

  // App state
  let currentView = $state('index');
  let currentWorkspace = $state(null);
  let currentTeam = $state(null);
  let workspaces = $state([]);
  let selectedFile = $state(null);
  let fileContent = $state('');
  let editingFile = $state(null);
  let creatingFile = $state(false);
  let breadcrumbs = $state([]);
  let currentPath = $state('/');
  let viewMode = $state('grid');
  let sortBy = $state('name');
  let sortOrder = $state('asc');
  let searchQuery = $state('');
  let loading = $state(false);
  let error = $state(null);

  // API client setup
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

      try {
        const response = await fetch(url, {
          ...options,
          headers
        });

        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        return await response.json();
      } catch (err) {
        console.error('API request failed:', err);
        throw err;
      }
    },

    // Workspaces API
    async getWorkspaces(teamId: string) {
      return this.request(`/teams/${teamId}/workspaces`);
    },

    async getWorkspace(teamId: string, workspaceId: string) {
      return this.request(`/teams/${teamId}/workspaces/${workspaceId}`);
    },

    async createWorkspace(teamId: string, workspace: any) {
      return this.request(`/teams/${teamId}/workspaces`, {
        method: 'POST',
        body: JSON.stringify({ workspace })
      });
    },

    async updateWorkspace(teamId: string, workspaceId: string, workspace: any) {
      return this.request(`/teams/${teamId}/workspaces/${workspaceId}`, {
        method: 'PATCH',
        body: JSON.stringify({ workspace })
      });
    },

    async deleteWorkspace(teamId: string, workspaceId: string) {
      return this.request(`/teams/${teamId}/workspaces/${workspaceId}`, {
        method: 'DELETE'
      });
    },

    async duplicateWorkspace(teamId: string, workspaceId: string, options: any) {
      return this.request(`/teams/${teamId}/workspaces/${workspaceId}/duplicate`, {
        method: 'POST',
        body: JSON.stringify({ options })
      });
    },

    async archiveWorkspace(teamId: string, workspaceId: string) {
      return this.request(`/teams/${teamId}/workspaces/${workspaceId}/archive`, {
        method: 'POST'
      });
    },

    // Documents API
    async getDocuments(teamId: string, workspaceId: string) {
      return this.request(`/teams/${teamId}/workspaces/${workspaceId}/documents`);
    },

    async getDocument(teamId: string, documentId: string) {
      return this.request(`/teams/${teamId}/documents/${documentId}`);
    },

    async createDocument(teamId: string, document: any) {
      return this.request(`/teams/${teamId}/documents`, {
        method: 'POST',
        body: JSON.stringify({ document })
      });
    },

    async updateDocument(teamId: string, documentId: string, document: any) {
      return this.request(`/teams/${teamId}/documents/${documentId}`, {
        method: 'PATCH',
        body: JSON.stringify({ document })
      });
    },

    async deleteDocument(teamId: string, documentId: string) {
      return this.request(`/teams/${teamId}/documents/${documentId}`, {
        method: 'DELETE'
      });
    },

    async duplicateDocument(teamId: string, documentId: string, options: any) {
      return this.request(`/teams/${teamId}/documents/${documentId}/duplicate`, {
        method: 'POST',
        body: JSON.stringify({ options })
      });
    },

    // Set current team
    async setCurrentTeam(teamId: string) {
      return fetch('/set-team/' + teamId, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrfToken
        }
      });
    }
  };

  // Navigation functions
  function navigateToWorkspaces() {
    currentView = 'index';
    currentWorkspace = null;
    selectedFile = null;
    editingFile = null;
    window.history.pushState({}, '', '/workspaces');
  }

  function navigateToWorkspace(workspace: any) {
    currentView = 'show';
    currentWorkspace = workspace;
    selectedFile = null;
    editingFile = null;
    window.history.pushState({}, '', `/workspaces/${workspace.id}`);
  }

  function navigateToWorkspaceDashboard(workspace: any) {
    currentView = 'dashboard';
    currentWorkspace = workspace;
    selectedFile = null;
    editingFile = null;
    window.history.pushState({}, '', `/workspaces/${workspace.id}/dashboard`);
  }

  function navigateToFileEditor(workspace: any, file: any, content: string = '') {
    currentView = 'file-editor';
    currentWorkspace = workspace;
    selectedFile = file;
    editingFile = file;
    fileContent = content;
    const fileId = file ? file.id : 'new';
    window.history.pushState({}, '', `/workspaces/${workspace.id}/dashboard/edit/${fileId}`);
  }

  // Team selection
  async function selectTeam(team: any) {
    try {
      loading = true;
      error = null;
      
      await apiClient.setCurrentTeam(team.id);
      currentTeam = team;
      
      // Load workspaces for the selected team
      const response = await apiClient.getWorkspaces(team.id);
      workspaces = response.data || [];
      
    } catch (err) {
      error = 'Failed to select team: ' + err.message;
    } finally {
      loading = false;
    }
  }

  // Initialize app based on current URL
  function initializeFromURL() {
    const path = window.location.pathname;
    const segments = path.split('/').filter(Boolean);

    if (segments.length >= 2 && segments[0] === 'workspaces') {
      const workspaceId = segments[1];
      
      if (segments.length >= 3) {
        if (segments[2] === 'dashboard') {
          currentView = 'dashboard';
          if (segments.length >= 5 && segments[3] === 'edit') {
            currentView = 'file-editor';
          }
        } else {
          currentView = 'show';
        }
      } else {
        currentView = 'show';
      }
      
      // Load workspace data if we have a team selected
      if (currentTeam && workspaceId !== 'new') {
        loadWorkspace(workspaceId);
      }
    } else {
      currentView = 'index';
    }
  }

  async function loadWorkspace(workspaceId: string) {
    if (!currentTeam) return;
    
    try {
      loading = true;
      const response = await apiClient.getWorkspace(currentTeam.id, workspaceId);
      currentWorkspace = response.data;
    } catch (err) {
      error = 'Failed to load workspace: ' + err.message;
    } finally {
      loading = false;
    }
  }

  // Handle browser back/forward
  function handlePopState() {
    initializeFromURL();
  }

  onMount(() => {
    // Set the first team as default if available
    if (teams.length > 0 && !currentTeam) {
      selectTeam(teams[0]);
    }

    // Initialize view based on URL
    initializeFromURL();

    // Listen for browser navigation
    window.addEventListener('popstate', handlePopState);

    return () => {
      window.removeEventListener('popstate', handlePopState);
    };
  });

  // Create a mock live object for compatibility with existing components
  const mockLive = {
    pushEvent: (event: string, data: any) => {
      console.log('Event:', event, data);
      
      // Handle events by calling appropriate API functions
      switch (event) {
        case 'lv:push_patch':
          const url = data.to;
          window.history.pushState({}, '', url);
          initializeFromURL();
          break;
          
        case 'lv:push_navigate':
          window.location.href = data.to;
          break;
          
        case 'duplicate_workspace':
          handleDuplicateWorkspace(data.id);
          break;
          
        case 'archive_workspace':
          handleArchiveWorkspace(data.id);
          break;
          
        case 'delete_workspace':
          handleDeleteWorkspace(data.id);
          break;
          
        default:
          console.warn('Unhandled event:', event, data);
      }
    }
  };

  async function handleDuplicateWorkspace(workspaceId: string) {
    if (!currentTeam) return;
    
    try {
      loading = true;
      await apiClient.duplicateWorkspace(currentTeam.id, workspaceId, {
        include_documents: true,
        include_notebooks: true
      });
      
      // Reload workspaces
      const response = await apiClient.getWorkspaces(currentTeam.id);
      workspaces = response.data || [];
      
    } catch (err) {
      error = 'Failed to duplicate workspace: ' + err.message;
    } finally {
      loading = false;
    }
  }

  async function handleArchiveWorkspace(workspaceId: string) {
    if (!currentTeam) return;
    
    try {
      loading = true;
      await apiClient.archiveWorkspace(currentTeam.id, workspaceId);
      
      // Reload workspaces
      const response = await apiClient.getWorkspaces(currentTeam.id);
      workspaces = response.data || [];
      
    } catch (err) {
      error = 'Failed to archive workspace: ' + err.message;
    } finally {
      loading = false;
    }
  }

  async function handleDeleteWorkspace(workspaceId: string) {
    if (!currentTeam) return;
    
    try {
      loading = true;
      await apiClient.deleteWorkspace(currentTeam.id, workspaceId);
      
      // Reload workspaces
      const response = await apiClient.getWorkspaces(currentTeam.id);
      workspaces = response.data || [];
      
      // Navigate back to index if we deleted the current workspace
      if (currentWorkspace && currentWorkspace.id === workspaceId) {
        navigateToWorkspaces();
      }
      
    } catch (err) {
      error = 'Failed to delete workspace: ' + err.message;
    } finally {
      loading = false;
    }
  }
</script>

<div class="min-h-screen bg-background">
  <!-- Team Selection Header -->
  {#if teams.length > 1}
    <div class="border-b">
      <div class="flex items-center justify-between p-4">
        <div class="flex items-center space-x-4">
          <span class="text-sm font-medium">Team:</span>
          <select 
            bind:value={currentTeam} 
            onchange={(e) => {
              const selectedTeam = teams.find(t => t.id === e.target.value);
              if (selectedTeam) selectTeam(selectedTeam);
            }}
            class="px-3 py-1 border rounded-md"
          >
            <option value="">Select a team...</option>
            {#each teams as team}
              <option value={team.id}>{team.name}</option>
            {/each}
          </select>
        </div>
        
        {#if currentView !== 'index'}
          <Button variant="outline" onclick={() => navigateToWorkspaces()}>
            <ArrowLeft class="w-4 h-4 mr-2" />
            Back to Workspaces
          </Button>
        {/if}
      </div>
    </div>
  {/if}

  <!-- Error Display -->
  {#if error}
    <div class="p-4">
      <Card class="border-red-200 bg-red-50">
        <CardContent class="p-4">
          <div class="flex items-center space-x-2 text-red-800">
            <AlertCircle class="w-5 h-5" />
            <span>{error}</span>
          </div>
        </CardContent>
      </Card>
    </div>
  {/if}

  <!-- Loading State -->
  {#if loading}
    <div class="flex items-center justify-center p-8">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900"></div>
    </div>
  {/if}

  <!-- Main Content -->
  <div class="flex-1">
    {#if currentView === 'index'}
      <WorkspaceIndex 
        {workspaces} 
        {teams} 
        current_team={currentTeam} 
        live={mockLive} 
      />
    {:else if currentView === 'show' && currentWorkspace}
      <WorkspaceShow 
        workspace={currentWorkspace} 
        documents={currentWorkspace.documents || []} 
        notebooks={currentWorkspace.notebooks || []} 
        live={mockLive} 
      />
    {:else if currentView === 'dashboard' && currentWorkspace}
      <WorkspaceDashboard 
        workspace={currentWorkspace}
        files={[...(currentWorkspace.documents || []), ...(currentWorkspace.notebooks || [])]}
        {selectedFile}
        {currentPath}
        {breadcrumbs}
        {viewMode}
        {sortBy}
        {sortOrder}
        {searchQuery}
        {fileContent}
        {editingFile}
        {creatingFile}
        file_tree={[]}
        live={mockLive}
      />
    {:else if currentView === 'file-editor' && currentWorkspace}
      <WorkspaceFileEditor 
        file={selectedFile}
        content={fileContent}
        workspace={currentWorkspace}
        is_editing={true}
        live={mockLive}
      />
    {:else}
      <div class="flex items-center justify-center min-h-screen">
        <Card>
          <CardContent class="p-8 text-center">
            <Home class="w-12 h-12 mx-auto mb-4 text-muted-foreground" />
            <h3 class="text-lg font-semibold mb-2">Welcome to Kyozo</h3>
            <p class="text-muted-foreground mb-4">
              {currentTeam ? 'Loading workspace...' : 'Please select a team to get started'}
            </p>
            {#if !currentTeam && teams.length > 0}
              <Button onclick={() => selectTeam(teams[0])}>
                Select {teams[0].name}
              </Button>
            {/if}
          </CardContent>
        </Card>
      </div>
    {/if}
  </div>
</div>