<script lang="ts">
  import { onMount } from 'svelte';
  import { Button } from '../ui/button';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
  import { Badge } from '../ui/badge';
  import {
    Users,
    Mail,
    Settings,
    Plus,
    ExternalLink,
    Clock,
    CheckCircle,
    X,
    AlertCircle
  } from '@lucide/svelte';

  // Props passed from Phoenix
  let {
    currentUser = null,
    teams = [],
    invitations = [],
    apiToken = '',
    csrfToken = '',
    apiBaseUrl = '/api/v1'
  } = $props();

  // App state
  let loading = $state(false);
  let error = $state(null);

  // API client setup
  const apiClient = {
    async request(endpoint, options = {}) {
      try {
        const response = await fetch(`${apiBaseUrl}${endpoint}`, {
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${apiToken}`,
            'X-CSRF-Token': csrfToken,
            ...options.headers
          },
          ...options
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

    async acceptInvitation(invitationId) {
      return this.request(`/invitations/${invitationId}/accept`, {
        method: 'POST'
      });
    },

    async declineInvitation(invitationId) {
      return this.request(`/invitations/${invitationId}/decline`, {
        method: 'POST'
      });
    }
  };

  function navigateToTeam(teamId) {
    window.location.href = `/teams/${teamId}`;
  }

  function createNewTeam() {
    window.location.href = '/teams/new';
  }

  async function acceptInvitation(invitationId) {
    loading = true;
    error = null;

    try {
      await apiClient.acceptInvitation(invitationId);
      // Remove the accepted invitation from the list
      invitations = invitations.filter(inv => inv.id !== invitationId);
    } catch (err) {
      error = `Failed to accept invitation: ${err.message}`;
    } finally {
      loading = false;
    }
  }

  async function declineInvitation(invitationId) {
    loading = true;
    error = null;

    try {
      await apiClient.declineInvitation(invitationId);
      // Remove the declined invitation from the list
      invitations = invitations.filter(inv => inv.id !== invitationId);
    } catch (err) {
      error = `Failed to decline invitation: ${err.message}`;
    } finally {
      loading = false;
    }
  }

  function formatDate(dateString) {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  }

  function getStatusIcon(status) {
    switch (status) {
      case 'pending': return Clock;
      case 'accepted': return CheckCircle;
      case 'declined': return X;
      default: return AlertCircle;
    }
  }

  function getStatusColor(status) {
    switch (status) {
      case 'pending': return 'text-yellow-600';
      case 'accepted': return 'text-green-600';
      case 'declined': return 'text-red-600';
      default: return 'text-gray-600';
    }
  }

  onMount(() => {
    // Any initialization logic here
  });
</script>

<div class="min-h-screen bg-background">
  <!-- Header -->
  <div class="border-b">
    <div class="flex items-center justify-between p-6">
      <div>
        <h1 class="text-3xl font-bold tracking-tight">Portal</h1>
        <p class="text-muted-foreground">Manage your teams and invitations</p>
      </div>
      <Button onclick={() => createNewTeam()}>
        <Plus class="w-4 h-4 mr-2" />
        Create Team
      </Button>
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

  <div class="p-6 space-y-8">
    <!-- Pending Invitations Section -->
    {#if invitations.length > 0}
      <div class="space-y-4">
        <h2 class="text-2xl font-semibold">Pending Invitations</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {#each invitations as invitation (invitation.id)}
            <Card class="border-yellow-200 bg-yellow-50">
              <CardHeader class="pb-3">
                <div class="flex items-start justify-between">
                  <div class="flex-1 min-w-0">
                    <CardTitle class="text-lg flex items-center space-x-2">
                      <Mail class="w-5 h-5" />
                      <span class="truncate">Team Invitation</span>
                    </CardTitle>
                    <CardDescription class="mt-1">
                      You've been invited to join <strong>{invitation.team_name}</strong>
                    </CardDescription>
                  </div>
                  <div class="flex items-center space-x-1">
                    <svelte:component
                      this={getStatusIcon(invitation.status)}
                      class="w-4 h-4 {getStatusColor(invitation.status)}"
                    />
                  </div>
                </div>
              </CardHeader>
              <CardContent class="pt-0">
                <div class="space-y-3">
                  <div class="text-sm text-muted-foreground">
                    <div>Invited by: <span class="font-medium">{invitation.inviter_email}</span></div>
                    <div>Role: <Badge variant="outline" class="capitalize">{invitation.role}</Badge></div>
                    <div>Received: {formatDate(invitation.created_at)}</div>
                  </div>

                  {#if invitation.status === 'pending'}
                    <div class="flex space-x-2">
                      <Button
                        size="sm"
                        onclick={() => acceptInvitation(invitation.id)}
                        disabled={loading}
                        class="flex-1"
                      >
                        <CheckCircle class="w-4 h-4 mr-1" />
                        Accept
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        onclick={() => declineInvitation(invitation.id)}
                        disabled={loading}
                        class="flex-1"
                      >
                        <X class="w-4 h-4 mr-1" />
                        Decline
                      </Button>
                    </div>
                  {/if}
                </div>
              </CardContent>
            </Card>
          {/each}
        </div>
      </div>
    {/if}

    <!-- Teams Section -->
    <div class="space-y-4">
      <h2 class="text-2xl font-semibold">Your Teams</h2>

      {#if teams.length === 0}
        <Card>
          <CardContent class="flex flex-col items-center justify-center py-12">
            <Users class="w-12 h-12 text-muted-foreground mb-4" />
            <h3 class="text-lg font-semibold mb-2">No teams yet</h3>
            <p class="text-muted-foreground text-center mb-4">
              Create your first team to start collaborating with others.
            </p>
            <Button onclick={() => createNewTeam()}>
              <Plus class="w-4 h-4 mr-2" />
              Create Your First Team
            </Button>
          </CardContent>
        </Card>
      {:else}
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {#each teams as team (team.id)}
            <Card class="hover:shadow-md transition-shadow cursor-pointer" onclick={() => navigateToTeam(team.id)}>
              <CardHeader class="pb-3">
                <div class="flex justify-between items-start">
                  <div class="flex-1 min-w-0">
                    <CardTitle class="text-lg truncate flex items-center space-x-2" title={team.name}>
                      <Users class="w-5 h-5" />
                      <span>{team.name}</span>
                    </CardTitle>
                    {#if team.description}
                      <CardDescription class="mt-1 line-clamp-2">
                        {team.description}
                      </CardDescription>
                    {/if}
                  </div>
                  <Badge variant="outline" class="capitalize ml-2">
                    {team.role || 'member'}
                  </Badge>
                </div>
              </CardHeader>
              <CardContent class="pt-0">
                <div class="space-y-3">
                  <div class="grid grid-cols-2 gap-4 text-sm text-muted-foreground">
                    <div>
                      <div class="font-medium">Members</div>
                      <div>{team.member_count || 0}</div>
                    </div>
                    <div>
                      <div class="font-medium">Workspaces</div>
                      <div>{team.workspace_count || 0}</div>
                    </div>
                  </div>

                  <div class="flex justify-between items-center">
                    <div class="text-xs text-muted-foreground">
                      Created {formatDate(team.created_at)}
                    </div>
                    <Button variant="ghost" size="sm" onclick={(e) => { e.stopPropagation(); navigateToTeam(team.id); }}>
                      <ExternalLink class="w-4 h-4" />
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          {/each}
        </div>
      {/if}
    </div>
  </div>
</div>
