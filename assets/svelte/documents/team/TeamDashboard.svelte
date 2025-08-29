<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
  import { Button } from '../ui/button';
  import { Badge } from '../ui/badge';
  import { Input } from '../ui/input';
  import { Label } from '../ui/label';
  import { Textarea } from '../ui/textarea';
  import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '../ui/dialog';
  import { Tabs, TabsContent, TabsList, TabsTrigger } from '../ui/tabs';
  import { Avatar, AvatarFallback, AvatarImage } from '../ui/avatar';
  import { Users, Plus, Mail, Settings, Crown, Shield, User as UserIcon } from '@lucide/svelte';

  // Props from LiveView
  interface Props {
    current_user: any;
    current_tab?: string;
    user_teams?: any[];
    selected_team?: any;
    team_members?: any[];
    received_invitations?: any[];
    sent_invitations?: any[];
  }

  let {
    current_user,
    current_tab = 'overview',
    user_teams = [],
    selected_team = null,
    team_members = [],
    received_invitations = [],
    sent_invitations = []
  }: Props = $props();

  // Component state
  let show_create_team_modal = $state(false);
  let show_invite_modal = $state(false);
  let invite_email = $state('');
  let team_form = $state({
    name: '',
    domain: '',
    description: ''
  });

  const dispatch = createEventDispatcher();

  function switchTab(tab: string) {
    dispatch('switch_tab', { tab });
  }

  function selectTeam(teamId: string) {
    dispatch('select_team', { team_id: teamId });
  }

  function showCreateTeamModal() {
    team_form = { name: '', domain: '', description: '' };
    show_create_team_modal = true;
  }

  function hideCreateTeamModal() {
    show_create_team_modal = false;
  }

  function createTeam() {
    dispatch('create_team', team_form);
    hideCreateTeamModal();
  }

  function showInviteModal() {
    invite_email = '';
    show_invite_modal = true;
  }

  function hideInviteModal() {
    show_invite_modal = false;
  }

  function inviteUser() {
    dispatch('invite_user', { email: invite_email, team_id: selected_team?.id });
    hideInviteModal();
  }

  function removeMember(memberId: string) {
    if (confirm('Are you sure you want to remove this member?')) {
      dispatch('remove_member', { member_id: memberId, team_id: selected_team?.id });
    }
  }

  function changeMemberRole(memberId: string, newRole: string) {
    dispatch('change_member_role', { member_id: memberId, role: newRole, team_id: selected_team?.id });
  }

  function cancelInvitation(invitationId: string) {
    if (confirm('Are you sure you want to cancel this invitation?')) {
      dispatch('cancel_invitation', { invitation_id: invitationId });
    }
  }

  function acceptInvitation(invitationId: string) {
    dispatch('accept_invitation', { invitation_id: invitationId });
  }

  function declineInvitation(invitationId: string) {
    dispatch('decline_invitation', { invitation_id: invitationId });
  }

  function leaveTeam(teamId: string) {
    if (confirm('Are you sure you want to leave this team?')) {
      dispatch('leave_team', { team_id: teamId });
    }
  }

  function getRoleColor(role: string): string {
    switch (role) {
      case 'owner': return 'bg-purple-100 text-purple-800';
      case 'admin': return 'bg-red-100 text-red-800';
      case 'member': return 'bg-blue-100 text-blue-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  }

  function getRoleIcon(role: string) {
    switch (role) {
      case 'owner': return Crown;
      case 'admin': return Shield;
      case 'member': return UserIcon;
      default: return UserIcon;
    }
  }

  function getUserInitials(name?: string): string {
    if (!name) return '?';
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
  }
</script>

<div class="min-h-screen bg-gray-50">
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <!-- Header -->
    <div class="mb-8">
      <h1 class="text-3xl font-bold text-gray-900">Team Dashboard</h1>
      <p class="mt-2 text-gray-600">Manage your teams and collaborations</p>
    </div>

    <Tabs value={current_tab} onValueChange={switchTab} class="mb-8">
      <!-- Tab Navigation -->
      <TabsList class="grid w-full grid-cols-3">
        <TabsTrigger value="overview">
          Overview
        </TabsTrigger>
        <TabsTrigger value="teams">
          My Teams
        </TabsTrigger>
        <TabsTrigger value="invitations" class="relative">
          Invitations
          {#if received_invitations.length > 0}
            <Badge variant="destructive" class="ml-2 px-2 py-0.5 text-xs">
              {received_invitations.length}
            </Badge>
          {/if}
        </TabsTrigger>
      </TabsList>

      <!-- Overview Tab -->
      <TabsContent value="overview" class="space-y-6">
        <!-- Stats Cards -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <!-- Total Teams -->
          <Card>
            <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle class="text-sm font-medium">Total Teams</CardTitle>
              <Users class="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div class="text-2xl font-bold">{user_teams.length}</div>
              <p class="text-xs text-muted-foreground">
                Teams you're part of
              </p>
            </CardContent>
          </Card>

          <!-- Pending Invitations -->
          <Card>
            <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle class="text-sm font-medium">Pending Invitations</CardTitle>
              <Mail class="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div class="text-2xl font-bold">{received_invitations.length}</div>
              <p class="text-xs text-muted-foreground">
                Awaiting your response
              </p>
            </CardContent>
          </Card>

          <!-- Quick Actions -->
          <Card>
            <CardHeader>
              <CardTitle class="text-lg">Quick Actions</CardTitle>
            </CardHeader>
            <CardContent class="space-y-3">
              <Button onclick={showCreateTeamModal} class="w-full">
                <Plus class="h-4 w-4 mr-2" />
                Create Team
              </Button>
              <Button variant="outline" onclick={() => switchTab('invitations')} class="w-full">
                <Mail class="h-4 w-4 mr-2" />
                View Invitations
              </Button>
            </CardContent>
          </Card>
        </div>

        <!-- Recent Teams -->
        {#if user_teams.length > 0}
          <Card>
            <CardHeader>
              <CardTitle>Recent Teams</CardTitle>
            </CardHeader>
            <CardContent>
              <div class="space-y-4">
                {#each user_teams.slice(0, 5) as team}
                  <div class="flex items-center justify-between p-4 border rounded-lg">
                    <div>
                      <h4 class="font-medium text-gray-900">{team.name}</h4>
                      <p class="text-sm text-gray-500">{team.members_count || 0} members</p>
                      {#if team.description}
                        <p class="text-sm text-gray-600 mt-1">{team.description}</p>
                      {/if}
                    </div>
                    <Button variant="outline" onclick={() => selectTeam(team.id)}>
                      View
                    </Button>
                  </div>
                {/each}
              </div>
            </CardContent>
          </Card>
        {/if}
      </TabsContent>

      <!-- Teams Tab -->
      <TabsContent value="teams" class="space-y-6">
        <div class="flex justify-between items-center">
          <h2 class="text-xl font-semibold text-gray-900">My Teams</h2>
          <Button onclick={showCreateTeamModal}>
            <Plus class="h-4 w-4 mr-2" />
            Create Team
          </Button>
        </div>

        {#if user_teams.length === 0}
          <Card>
            <CardContent class="text-center py-12">
              <Users class="mx-auto h-12 w-12 text-gray-400 mb-4" />
              <h3 class="text-lg font-medium text-gray-900 mb-2">No teams yet</h3>
              <p class="text-gray-500 mb-6">Create your first team to start collaborating.</p>
              <Button onclick={showCreateTeamModal}>
                <Plus class="h-4 w-4 mr-2" />
                Create Your First Team
              </Button>
            </CardContent>
          </Card>
        {:else}
          <!-- Teams Grid -->
          <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {#each user_teams as team}
              <Card class="relative">
                <CardHeader>
                  <div class="flex items-center justify-between">
                    <CardTitle class="text-lg">{team.name}</CardTitle>
                    {#if selected_team && team.id === selected_team.id}
                      <Badge variant="secondary">Selected</Badge>
                    {/if}
                  </div>
                  <CardDescription>{team.members_count || 0} members</CardDescription>
                </CardHeader>
                <CardContent>
                  {#if team.description}
                    <p class="text-sm text-gray-600 mb-4">{team.description}</p>
                  {/if}
                  
                  <div class="flex justify-between">
                    <Button
                      variant="outline"
                      size="sm"
                      onclick={() => selectTeam(team.id)}
                      class={selected_team && team.id === selected_team.id ? 'bg-blue-50' : ''}
                    >
                      {selected_team && team.id === selected_team.id ? 'Selected' : 'Select'}
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onclick={() => leaveTeam(team.id)}
                      class="text-red-600 hover:text-red-700"
                    >
                      Leave
                    </Button>
                  </div>
                </CardContent>
              </Card>
            {/each}
          </div>

          <!-- Selected Team Details -->
          {#if selected_team}
            <Card>
              <CardHeader>
                <div class="flex justify-between items-center">
                  <CardTitle>{selected_team.name} - Team Members</CardTitle>
                  <Button onclick={showInviteModal}>
                    <Plus class="h-4 w-4 mr-2" />
                    Invite Member
                  </Button>
                </div>
              </CardHeader>
              <CardContent>
                <div class="space-y-6">
                  <!-- Current Members -->
                  <div>
                    <h4 class="font-medium text-gray-900 mb-4">
                      Current Members ({team_members.length})
                    </h4>
                    {#if team_members.length === 0}
                      <p class="text-gray-500 text-sm">No members found</p>
                    {:else}
                      <div class="space-y-3">
                        {#each team_members as member}
                          <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                            <div class="flex items-center space-x-3">
                              <Avatar>
                                <AvatarImage src={member.user?.picture} alt={member.user?.name} />
                                <AvatarFallback>
                                  {getUserInitials(member.user?.name)}
                                </AvatarFallback>
                              </Avatar>
                              <div>
                                <p class="font-medium text-gray-900">
                                  {member.user?.name || member.user?.email || 'Unknown'}
                                </p>
                                <p class="text-sm text-gray-500">{member.user?.email}</p>
                              </div>
                            </div>
                            <div class="flex items-center space-x-2">
                              <Badge class={getRoleColor(member.role)}>
                                {#if getRoleIcon(member.role) === Crown}
                                  <Crown class="h-3 w-3 mr-1" />
                                {:else if getRoleIcon(member.role) === Shield}
                                  <Shield class="h-3 w-3 mr-1" />
                                {:else}
                                  <UserIcon class="h-3 w-3 mr-1" />
                                {/if}
                                <span class="capitalize">{member.role}</span>
                              </Badge>
                              {#if member.can_manage}
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  onclick={() => removeMember(member.id)}
                                  class="text-red-600 hover:text-red-700"
                                >
                                  Remove
                                </Button>
                              {/if}
                            </div>
                          </div>
                        {/each}
                      </div>
                    {/if}
                  </div>

                  <!-- Pending Invitations -->
                  {#if sent_invitations.length > 0}
                    <div>
                      <h4 class="font-medium text-gray-900 mb-4">
                        Pending Invitations ({sent_invitations.length})
                      </h4>
                      <div class="space-y-3">
                        {#each sent_invitations as invitation}
                          <div class="flex items-center justify-between p-3 bg-yellow-50 rounded-lg">
                            <div class="flex items-center space-x-3">
                              <Avatar>
                                <AvatarImage src={invitation.invited_user?.picture} alt={invitation.invited_user?.name} />
                                <AvatarFallback class="bg-yellow-300">
                                  {getUserInitials(invitation.invited_user?.name || invitation.email)}
                                </AvatarFallback>
                              </Avatar>
                              <div>
                                <p class="font-medium text-gray-900">
                                  {invitation.invited_user?.name || invitation.email}
                                </p>
                                <p class="text-sm text-gray-500">{invitation.email}</p>
                              </div>
                            </div>
                            <div class="flex items-center space-x-2">
                              <Badge variant="outline" class="bg-yellow-100 text-yellow-800">
                                Pending
                              </Badge>
                              <Button
                                variant="ghost"
                                size="sm"
                                onclick={() => cancelInvitation(invitation.id)}
                                class="text-red-600 hover:text-red-700"
                              >
                                Cancel
                              </Button>
                            </div>
                          </div>
                        {/each}
                      </div>
                    </div>
                  {/if}
                </div>
              </CardContent>
            </Card>
          {/if}
        {/if}
      </TabsContent>

      <!-- Invitations Tab -->
      <TabsContent value="invitations">
        <Card>
          <CardHeader>
            <CardTitle>Team Invitations</CardTitle>
            <CardDescription>Invitations you've received from other teams</CardDescription>
          </CardHeader>
          <CardContent>
            {#if received_invitations.length === 0}
              <div class="text-center py-8">
                <Mail class="mx-auto h-12 w-12 text-gray-400 mb-4" />
                <h3 class="text-lg font-medium text-gray-900 mb-2">No pending invitations</h3>
                <p class="text-gray-500">When you receive team invitations, they'll appear here.</p>
              </div>
            {:else}
              <div class="space-y-4">
                {#each received_invitations as invitation}
                  <div class="flex items-center justify-between p-4 border rounded-lg">
                    <div class="flex items-center space-x-4">
                      <Avatar>
                        <AvatarFallback class="bg-indigo-100 text-indigo-700">
                          {getUserInitials(invitation.team?.name)}
                        </AvatarFallback>
                      </Avatar>
                      <div>
                        <h4 class="font-medium text-gray-900">
                          {invitation.team?.name}
                        </h4>
                        <p class="text-sm text-gray-500">
                          Invited by {invitation.inviter?.name || invitation.inviter?.email}
                        </p>
                        {#if invitation.team?.description}
                          <p class="text-sm text-gray-500 mt-1">{invitation.team.description}</p>
                        {/if}
                      </div>
                    </div>
                    <div class="flex space-x-3">
                      <Button
                        onclick={() => acceptInvitation(invitation.id)}
                        class="bg-green-600 hover:bg-green-700"
                      >
                        Accept
                      </Button>
                      <Button
                        variant="outline"
                        onclick={() => declineInvitation(invitation.id)}
                      >
                        Decline
                      </Button>
                    </div>
                  </div>
                {/each}
              </div>
            {/if}
          </CardContent>
        </Card>
      </TabsContent>
    </Tabs>
  </div>

  <!-- Create Team Modal -->
  <Dialog open={show_create_team_modal} onOpenChange={(open) => open ? showCreateTeamModal() : hideCreateTeamModal()}>
    <DialogContent>
      <DialogHeader>
        <DialogTitle>Create New Team</DialogTitle>
        <DialogDescription>
          Create a new team to collaborate with others.
        </DialogDescription>
      </DialogHeader>
      <div class="space-y-4">
        <div>
          <Label for="team-name">Team Name</Label>
          <Input id="team-name" bind:value={team_form.name} placeholder="My Awesome Team" />
        </div>
        <div>
          <Label for="team-domain">Team Domain</Label>
          <Input id="team-domain" bind:value={team_form.domain} placeholder="my-team" />
          <p class="text-sm text-gray-500 mt-1">Used for team URLs and identification</p>
        </div>
        <div>
          <Label for="team-description">Description (Optional)</Label>
          <Textarea id="team-description" bind:value={team_form.description} placeholder="What's this team for?" />
        </div>
        <div class="flex justify-end space-x-3">
          <Button variant="outline" onclick={hideCreateTeamModal}>Cancel</Button>
          <Button onclick={createTeam}>Create Team</Button>
        </div>
      </div>
    </DialogContent>
  </Dialog>

  <!-- Invite User Modal -->
  <Dialog open={show_invite_modal} onOpenChange={(open) => open ? showInviteModal() : hideInviteModal()}>
    <DialogContent>
      <DialogHeader>
        <DialogTitle>Invite Team Member</DialogTitle>
        <DialogDescription>
          Invite someone to join {selected_team?.name}.
        </DialogDescription>
      </DialogHeader>
      <div class="space-y-4">
        <div>
          <Label for="invite-email">Email Address</Label>
          <Input
            id="invite-email"
            type="email"
            bind:value={invite_email}
            placeholder="colleague@company.com"
          />
        </div>
        <div class="flex justify-end space-x-3">
          <Button variant="outline" onclick={hideInviteModal}>Cancel</Button>
          <Button onclick={inviteUser}>Send Invitation</Button>
        </div>
      </div>
    </DialogContent>
  </Dialog>
</div>