<script lang="ts">
  import { onMount } from 'svelte';
  import { Button } from '../ui/button';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
  import { Badge } from '../ui/badge';
  import { Input } from '../ui/input';
  import { Textarea } from '../ui/textarea';
  import { Separator } from '../ui/separator';
  import { 
    Plus, 
    Users, 
    Settings, 
    Trash2, 
    UserPlus, 
    UserMinus, 
    Crown, 
    Shield, 
    User,
    Mail,
    MoreHorizontal,
    AlertCircle,
    CheckCircle,
    Clock,
    X
  } from '@lucide/svelte';
  import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '../ui/dropdown-menu';

  // Props passed from Phoenix
  let { 
    currentUser = null, 
    teams = [], 
    apiToken = '', 
    csrfToken = '', 
    apiBaseUrl = '/api/v1' 
  } = $props();

  // App state
  let currentView = $state('index'); // 'index', 'show', 'create', 'edit'
  let selectedTeam = $state(null);
  let teamMembers = $state([]);
  let teamInvitations = $state([]);
  let teamWorkspaces = $state([]);
  let loading = $state(false);
  let error = $state(null);
  let showCreateForm = $state(false);
  let showInviteForm = $state(false);

  // Form state
  let teamForm = $state({
    name: '',
    description: ''
  });

  let inviteForm = $state({
    email: '',
    role: 'member'
  });

  // API client setup
  const apiClient = {
    async request(endpoint: string, options: RequestInit = {}) {
      const url = `${apiBaseUrl}${endpoint}`;
      const headers = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiToken}`,
        'X-CSRF-Token': csrfToken,
        ...options.headers
      };

      try {
        const response = await fetch(url, {
          ...options,
          headers
        });

        if (!response.ok) {
          const errorData = await response.json().catch(() => ({}));
          throw new Error(errorData.error?.message || `HTTP ${response.status}: ${response.statusText}`);
        }

        return await response.json();
      } catch (err) {
        console.error('API request failed:', err);
        throw err;
      }
    },

    // Teams API
    async getTeams() {
      return this.request('/teams');
    },

    async getTeam(teamId: string) {
      return this.request(`/teams/${teamId}`);
    },

    async createTeam(team: any) {
      return this.request('/teams', {
        method: 'POST',
        body: JSON.stringify({ team })
      });
    },

    async updateTeam(teamId: string, team: any) {
      return this.request(`/teams/${teamId}`, {
        method: 'PATCH',
        body: JSON.stringify({ team })
      });
    },

    async deleteTeam(teamId: string) {
      return this.request(`/teams/${teamId}`, {
        method: 'DELETE'
      });
    },

    async getTeamMembers(teamId: string) {
      return this.request(`/teams/${teamId}/members`);
    },

    async inviteMember(teamId: string, invitation: any) {
      return this.request(`/teams/${teamId}/members`, {
        method: 'POST',
        body: JSON.stringify({ invitation })
      });
    },

    async removeMember(teamId: string, memberId: string) {
      return this.request(`/teams/${teamId}/members/${memberId}`, {
        method: 'DELETE'
      });
    },

    async updateMemberRole(teamId: string, memberId: string, role: string) {
      return this.request(`/teams/${teamId}/members/${memberId}/role`, {
        method: 'PATCH',
        body: JSON.stringify({ role })
      });
    },

    async getTeamInvitations(teamId: string) {
      return this.request(`/teams/${teamId}/invitations`);
    },

    async cancelInvitation(teamId: string, invitationId: string) {
      return this.request(`/teams/${teamId}/invitations/${invitationId}`, {
        method: 'DELETE'
      });
    },

    async getTeamWorkspaces(teamId: string) {
      return this.request(`/teams/${teamId}/workspaces`);
    }
  };

  // Navigation functions
  function showTeamsList() {
    currentView = 'index';
    selectedTeam = null;
    window.history.pushState({}, '', '/teams');
  }

  function showTeamDetails(team: any) {
    currentView = 'show';
    selectedTeam = team;
    loadTeamDetails(team.id);
    window.history.pushState({}, '', `/teams/${team.id}`);
  }

  function showCreateTeamForm() {
    showCreateForm = true;
    teamForm = { name: '', description: '' };
  }

  function hideCreateTeamForm() {
    showCreateForm = false;
    teamForm = { name: '', description: '' };
  }

  function showInviteMemberForm() {
    showInviteForm = true;
    inviteForm = { email: '', role: 'member' };
  }

  function hideInviteMemberForm() {
    showInviteForm = false;
    inviteForm = { email: '', role: 'member' };
  }

  // Data loading functions
  async function loadTeams() {
    try {
      loading = true;
      error = null;
      const response = await apiClient.getTeams();
      teams = response.data || [];
    } catch (err) {
      error = 'Failed to load teams: ' + err.message;
    } finally {
      loading = false;
    }
  }

  async function loadTeamDetails(teamId: string) {
    try {
      loading = true;
      error = null;
      
      const [teamResponse, membersResponse, invitationsResponse, workspacesResponse] = await Promise.all([
        apiClient.getTeam(teamId),
        apiClient.getTeamMembers(teamId),
        apiClient.getTeamInvitations(teamId),
        apiClient.getTeamWorkspaces(teamId)
      ]);

      selectedTeam = teamResponse.data;
      teamMembers = membersResponse.data || [];
      teamInvitations = invitationsResponse.data || [];
      teamWorkspaces = workspacesResponse.data || [];
    } catch (err) {
      error = 'Failed to load team details: ' + err.message;
    } finally {
      loading = false;
    }
  }

  // Team management functions
  async function createTeam() {
    if (!teamForm.name.trim()) {
      error = 'Team name is required';
      return;
    }

    try {
      loading = true;
      error = null;
      
      const response = await apiClient.createTeam(teamForm);
      teams = [...teams, response.data];
      hideCreateTeamForm();
      
    } catch (err) {
      error = 'Failed to create team: ' + err.message;
    } finally {
      loading = false;
    }
  }

  async function deleteTeam(teamId: string) {
    if (!confirm('Are you sure you want to delete this team? This action cannot be undone.')) {
      return;
    }

    try {
      loading = true;
      error = null;
      
      await apiClient.deleteTeam(teamId);
      teams = teams.filter(t => t.id !== teamId);
      
      if (selectedTeam && selectedTeam.id === teamId) {
        showTeamsList();
      }
      
    } catch (err) {
      error = 'Failed to delete team: ' + err.message;
    } finally {
      loading = false;
    }
  }

  // Member management functions
  async function inviteMember() {
    if (!inviteForm.email.trim()) {
      error = 'Email is required';
      return;
    }

    try {
      loading = true;
      error = null;
      
      const response = await apiClient.inviteMember(selectedTeam.id, inviteForm);
      teamInvitations = [...teamInvitations, response.data];
      hideInviteMemberForm();
      
    } catch (err) {
      error = 'Failed to send invitation: ' + err.message;
    } finally {
      loading = false;
    }
  }

  async function removeMember(memberId: string) {
    if (!confirm('Are you sure you want to remove this member from the team?')) {
      return;
    }

    try {
      loading = true;
      error = null;
      
      await apiClient.removeMember(selectedTeam.id, memberId);
      teamMembers = teamMembers.filter(m => m.id !== memberId);
      
    } catch (err) {
      error = 'Failed to remove member: ' + err.message;
    } finally {
      loading = false;
    }
  }

  async function updateMemberRole(memberId: string, newRole: string) {
    try {
      loading = true;
      error = null;
      
      const response = await apiClient.updateMemberRole(selectedTeam.id, memberId, newRole);
      teamMembers = teamMembers.map(m => 
        m.id === memberId ? { ...m, role: newRole } : m
      );
      
    } catch (err) {
      error = 'Failed to update member role: ' + err.message;
    } finally {
      loading = false;
    }
  }

  async function cancelInvitation(invitationId: string) {
    try {
      loading = true;
      error = null;
      
      await apiClient.cancelInvitation(selectedTeam.id, invitationId);
      teamInvitations = teamInvitations.filter(i => i.id !== invitationId);
      
    } catch (err) {
      error = 'Failed to cancel invitation: ' + err.message;
    } finally {
      loading = false;
    }
  }

  // Utility functions
  function getRoleIcon(role: string) {
    switch (role) {
      case 'owner': return Crown;
      case 'admin': return Shield;
      case 'manager': return Settings;
      default: return User;
    }
  }

  function getRoleColor(role: string) {
    switch (role) {
      case 'owner': return 'text-yellow-600';
      case 'admin': return 'text-red-600';
      case 'manager': return 'text-blue-600';
      default: return 'text-gray-600';
    }
  }

  function getInvitationStatusIcon(status: string) {
    switch (status) {
      case 'accepted': return CheckCircle;
      case 'declined': return X;
      case 'expired': return Clock;
      default: return Mail;
    }
  }

  function getInvitationStatusColor(status: string) {
    switch (status) {
      case 'accepted': return 'text-green-600';
      case 'declined': return 'text-red-600';
      case 'expired': return 'text-gray-600';
      default: return 'text-blue-600';
    }
  }

  function formatDate(dateString: string) {
    if (!dateString) return 'Never';
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  }

  function canManageTeam(team: any) {
    if (!currentUser) return false;
    // Check if current user is owner or admin of this team
    const userMembership = teamMembers.find(m => m.user_id === currentUser.id);
    return userMembership && ['owner', 'admin'].includes(userMembership.role);
  }

  function canInviteMembers(team: any) {
    if (!currentUser) return false;
    const userMembership = teamMembers.find(m => m.user_id === currentUser.id);
    return userMembership && ['owner', 'admin', 'manager'].includes(userMembership.role);
  }

  // Initialize app
  onMount(() => {
    // Initialize view based on URL
    const path = window.location.pathname;
    const segments = path.split('/').filter(Boolean);

    if (segments.length >= 2 && segments[0] === 'teams') {
      const teamId = segments[1];
      const team = teams.find(t => t.id === teamId);
      if (team) {
        showTeamDetails(team);
      } else {
        showTeamsList();
      }
    } else {
      showTeamsList();
    }

    // Load teams if not already loaded
    if (teams.length === 0) {
      loadTeams();
    }
  });
</script>

<div class="min-h-screen bg-background">
  <!-- Header -->
  <div class="border-b">
    <div class="flex items-center justify-between p-6">
      <div>
        <h1 class="text-3xl font-bold tracking-tight">Teams</h1>
        <p class="text-muted-foreground">
          Manage your teams and collaborate with others
        </p>
      </div>
      
      {#if currentView === 'index'}
        <Button onclick={() => showCreateTeamForm()}>
          <Plus class="w-4 h-4 mr-2" />
          Create Team
        </Button>
      {:else if currentView === 'show'}
        <div class="flex items-center space-x-2">
          {#if canInviteMembers(selectedTeam)}
            <Button variant="outline" onclick={() => showInviteMemberForm()}>
              <UserPlus class="w-4 h-4 mr-2" />
              Invite Member
            </Button>
          {/if}
          <Button variant="outline" onclick={() => showTeamsList()}>
            Back to Teams
          </Button>
        </div>
      {/if}
    </div>
  </div>

  <!-- Error Display -->
  {#if error}
    <div class="p-6">
      <Card class="border-red-200 bg-red-50">
        <CardContent class="p-4">
          <div class="flex items-center space-x-2 text-red-800">
            <AlertCircle class="w-5 h-5" />
            <span>{error}</span>
            <Button variant="ghost" size="sm" onclick={() => error = null}>
              <X class="w-4 h-4" />
            </Button>
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
  <div class="p-6">
    {#if currentView === 'index'}
      <!-- Teams List -->
      {#if teams.length === 0 && !loading}
        <Card>
          <CardContent class="flex flex-col items-center justify-center py-12">
            <Users class="w-12 h-12 text-muted-foreground mb-4" />
            <h3 class="text-lg font-semibold mb-2">No teams yet</h3>
            <p class="text-muted-foreground text-center mb-4">
              Create your first team to start collaborating with others.
            </p>
            <Button onclick={() => showCreateTeamForm()}>
              <Plus class="w-4 h-4 mr-2" />
              Create Team
            </Button>
          </CardContent>
        </Card>
      {:else}
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {#each teams as team (team.id)}
            <Card class="hover:shadow-md transition-shadow cursor-pointer" onclick={() => showTeamDetails(team)}>
              <CardHeader class="pb-3">
                <div class="flex justify-between items-start">
                  <div class="flex-1 min-w-0">
                    <CardTitle class="text-lg truncate" title={team.name}>
                      {team.name}
                    </CardTitle>
                  </div>
                  
                  <DropdownMenu>
                    <DropdownMenuTrigger>
                      <Button variant="ghost" size="sm" onclick={(e) => e.stopPropagation()}>
                        <MoreHorizontal class="w-4 h-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem onclick={() => showTeamDetails(team)}>
                        <Users class="w-4 h-4 mr-2" />
                        View Details
                      </DropdownMenuItem>
                      <DropdownMenuItem onclick={() => deleteTeam(team.id)} class="text-destructive">
                        <Trash2 class="w-4 h-4 mr-2" />
                        Delete Team
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
              </CardHeader>
              
              <CardContent class="pt-0">
                <div class="space-y-3">
                  <!-- Stats -->
                  <div class="grid grid-cols-2 gap-4 text-sm text-muted-foreground">
                    <div>
                      <div class="font-medium">{team.members_count || 0}</div>
                      <div>Members</div>
                    </div>
                    <div>
                      <div class="font-medium">{team.workspaces_count || 0}</div>
                      <div>Workspaces</div>
                    </div>
                  </div>

                  <!-- Date -->
                  <div class="text-xs text-muted-foreground">
                    Created: {formatDate(team.created_at)}
                  </div>
                </div>
              </CardContent>
            </Card>
          {/each}
        </div>
      {/if}

    {:else if currentView === 'show' && selectedTeam}
      <!-- Team Details -->
      <div class="space-y-6">
        <!-- Team Info -->
        <Card>
          <CardHeader>
            <CardTitle class="flex items-center space-x-2">
              <Users class="w-6 h-6" />
              <span>{selectedTeam.name}</span>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div>
                <div class="text-sm font-medium text-muted-foreground">Members</div>
                <div class="text-2xl font-bold">{teamMembers.length}</div>
              </div>
              <div>
                <div class="text-sm font-medium text-muted-foreground">Workspaces</div>
                <div class="text-2xl font-bold">{teamWorkspaces.length}</div>
              </div>
              <div>
                <div class="text-sm font-medium text-muted-foreground">Created</div>
                <div class="text-sm">{formatDate(selectedTeam.created_at)}</div>
              </div>
            </div>
          </CardContent>
        </Card>

        <!-- Team Members -->
        <Card>
          <CardHeader>
            <div class="flex items-center justify-between">
              <CardTitle>Team Members</CardTitle>
              {#if canInviteMembers(selectedTeam)}
                <Button size="sm" onclick={() => showInviteMemberForm()}>
                  <UserPlus class="w-4 h-4 mr-2" />
                  Invite Member
                </Button>
              {/if}
            </div>
          </CardHeader>
          <CardContent>
            <div class="space-y-4">
              {#each teamMembers as member (member.id)}
                <div class="flex items-center justify-between p-3 border rounded">
                  <div class="flex items-center space-x-3">
                    <div class="w-8 h-8 bg-gray-200 rounded-full flex items-center justify-center">
                      <User class="w-4 h-4" />
                    </div>
                    <div>
                      <div class="font-medium">{member.user?.email || 'Unknown'}</div>
                      <div class="flex items-center space-x-2 text-sm text-muted-foreground">
                        <svelte:component this={getRoleIcon(member.role)} class="w-3 h-3 {getRoleColor(member.role)}" />
                        <span class="capitalize">{member.role}</span>
                      </div>
                    </div>
                  </div>
                  
                  {#if canManageTeam(selectedTeam) && member.user_id !== currentUser?.id}
                    <DropdownMenu>
                      <DropdownMenuTrigger>
                        <Button variant="ghost" size="sm">
                          <MoreHorizontal class="w-4 w-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuItem onclick={() => updateMemberRole(member.id, 'member')}>
                          Make Member
                        </DropdownMenuItem>
                        <DropdownMenuItem onclick={() => updateMemberRole(member.id, 'manager')}>
                          Make Manager
                        </DropdownMenuItem>
                        <DropdownMenuItem onclick={() => updateMemberRole(member.id, 'admin')}>
                          Make Admin
                        </DropdownMenuItem>
                        <Separator />
                        <DropdownMenuItem onclick={() => removeMember(member.id)} class="text-destructive">
                          <UserMinus class="w-4 h-4 mr-2" />
                          Remove Member
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  {/if}
                </div>
              {/each}
            </div>
          </CardContent>
        </Card>

        <!-- Pending Invitations -->
        {#if teamInvitations.length > 0}
          <Card>
            <CardHeader>
              <CardTitle>Pending Invitations</CardTitle>
            </CardHeader>
            <CardContent>
              <div class="space-y-3">
                {#each teamInvitations as invitation (invitation.id)}
                  <div class="flex items-center justify-between p-3 border rounded">
                    <div class="flex items-center space-x-3">
                      <svelte:component 
                        this={getInvitationStatusIcon(invitation.status)} 
                        class="w-5 h-5 {getInvitationStatusColor(invitation.status)}" 
                      />
                      <div>
                        <div class="font-medium">{invitation.invited_email}</div>
                        <div class="text-sm text-muted-foreground">
                          Role: {invitation.role} • Status: {invitation.status}
                        </div>
                      </div>
                    </div>
                    
                    {#if canManageTeam(selectedTeam) && invitation.status === 'pending'}
                      <Button 
                        variant="ghost" 
                        size="sm" 
                        onclick={() => cancelInvitation(invitation.id)}
                      >
                        Cancel
                      </Button>
                    {/if}
                  </div>
                {/each}
              </div>
            </CardContent>
          </Card>
        {/if}

        <!-- Team Workspaces -->
        {#if teamWorkspaces.length > 0}
          <Card>
            <CardHeader>
              <CardTitle>Team Workspaces</CardTitle>
            </CardHeader>
            <CardContent>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                {#each teamWorkspaces as workspace (workspace.id)}
                  <Card class="hover:shadow-sm transition-shadow">
                    <CardContent class="p-4">
                      <div class="flex items-center justify-between">
                        <div>
                          <h4 class="font-medium">{workspace.name}</h4>
                          <p class="text-sm text-muted-foreground">{workspace.description || 'No description'}</p>
                        </div>
                        <Badge variant="outline">{workspace.status}</Badge>
                      </div>
                    </CardContent>
                  </Card>
                {/each}
              </div>
            </CardContent>
          </Card>
        {/if}
      </div>
    {/if}
  </div>

  <!-- Create Team Modal -->
  {#if showCreateForm}
    <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
      <Card class="w-full max-w-md">
        <CardHeader>
          <CardTitle>Create New Team</CardTitle>
          <CardDescription>
            Create a team to collaborate with others
          </CardDescription>
        </CardHeader>
        <CardContent class="space-y-4">
          <div>
            <label class="text-sm font-medium">Team Name</label>
            <Input 
              bind:value={teamForm.name} 
              placeholder="Enter team name"
              class="mt-1"
            />
          </div>
          <div>
            <label class="text-sm font-medium">Description (Optional)</label>
            <Textarea 
              bind:value={teamForm.description} 
              placeholder="Enter team description"
              class="mt-1"
              rows="3"
            />
          </div>
          <div class="flex justify-end space-x-2">
            <Button variant="outline" onclick={() => hideCreateTeamForm()}>
              Cancel
            </Button>
            <Button onclick={() => createTeam()} disabled={loading || !teamForm.name.trim()}>
              Create Team
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  {/if}

  <!-- Invite Member Modal -->
  {#if showInviteForm}
    <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
      <Card class="w-full max-w-md">
        <CardHeader>
          <CardTitle>Invite Team Member</CardTitle>
          <CardDescription>
            Send an invitation to join {selectedTeam?.name}
          </CardDescription>
        </CardHeader>
        <CardContent class="space-y-4">
          <div>
            <label class="text-sm font-medium">Email Address</label>
            <Input 
              type="email"
              bind:value={inviteForm.email} 
              placeholder="Enter email address"
              class="mt-1"
            />
          </div>
          <div>
            <label class="text-sm font-medium">Role</label>
            <select bind:value={inviteForm.role} class="w-full mt-1 px-3 py-2 border rounded-md">
              <option value="member">Member</option>
              <option value="manager">Manager</option>
              <option value="admin">Admin</option>
            </select>
          </div>
          <div class="flex justify-end space-x-2">
            <Button variant="outline" onclick={() => hideInviteMemberForm()}>
              Cancel
            </Button>
            <Button onclick={() => inviteMember()} disabled={loading || !inviteForm.email.trim()}>
              Send Invitation
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  {/if}
</div>