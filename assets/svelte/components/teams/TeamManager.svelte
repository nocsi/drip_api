<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '../../utils';
  import { 
    teams, 
    currentTeam, 
    auth, 
    apiService,
    createTableStore 
  } from '../../stores/index';
  import type { Team, TeamInvitation, UserTeam } from '../../types';
  import { Button } from '../../ui/button';
  import { Input } from '../../ui/input';
  import { Label } from '../../ui/label';
  import { Textarea } from '../../ui/textarea';
  import { Avatar, AvatarFallback, AvatarImage } from '../../ui/avatar';
  import { Badge } from '../../ui/badge';
  import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../../ui/card';
  import { Separator } from '../../ui/separator';
  import { 
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DialogTrigger
  } from '../../ui/dialog';
  import { 
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger
  } from '../../ui/dropdown-menu';
  import { 
    AlertDialog,
    AlertDialogAction,
    AlertDialogCancel,
    AlertDialogContent,
    AlertDialogDescription,
    AlertDialogFooter,
    AlertDialogHeader,
    AlertDialogTitle,
    AlertDialogTrigger
  } from '../../ui/alert-dialog';
  import { 
    Plus, 
    Users,
    Settings, 
    Trash2, 
    MoreHorizontal,
    Crown,
    Shield,
    Eye,
    Mail,
    Calendar,
    Building,
    ExternalLink,
    UserCheck,
    UserX,
    Clock
  } from '@lucide/svelte';

  // Component state
  let showCreateDialog = false;
  let showInviteDialog = false;
  let selectedTeam: Team | null = null;
  let loading = false;
  let teamMembers: UserTeam[] = [];
  let teamInvitations: TeamInvitation[] = [];

  // Form state
  let createForm = $state({
    name: '',
    description: '',
    domain: '',
    is_public: false
  });

  let inviteForm = $state({
    email: '',
    role: 'member' as 'admin' | 'member' | 'viewer'
  });

  const tableStore = createTableStore<Team>();

  const teamsData = $derived($teams.data || []);
  const isLoading = $derived($teams.status === 'loading' || loading);

  onMount(async () => {
    if ($apiService) {
      await loadTeams();
    }
  });

  async function loadTeams() {
    if (!$apiService) return;
    await teams.load($apiService);
  }

  async function loadTeamDetails(team: Team) {
    if (!$apiService) return;
    
    try {
      loading = true;
      const response = await $apiService.getTeam(team.id);
      teamMembers = response.data.user_teams || [];
      teamInvitations = response.data.invitations || [];
    } catch (error) {
      console.error('Failed to load team details:', error);
    } finally {
      loading = false;
    }
  }

  async function createTeam() {
    if (!$apiService) return;

    try {
      loading = true;
      const team = await teams.create($apiService, createForm);
      
      // Reset form
      createForm = { name: '', description: '', domain: '' };
      showCreateDialog = false;
      
      // Set as current team if user has no current team
      if (!$currentTeam) {
        currentTeam.set(team);
        goto(`/teams/${team.id}`);
      }
    } catch (error) {
      console.error('Failed to create team:', error);
    } finally {
      loading = false;
    }
  }

  async function selectTeam(team: Team) {
    currentTeam.set(team);
    selectedTeam = team;
    await loadTeamDetails(team);
    goto(`/teams/${team.id}`);
  }

  async function inviteMember(team: Team) {
    if (!$apiService) return;

    try {
      loading = true;
      await $apiService.inviteTeamMember(team.id, inviteForm);
      
      // Reset form
      inviteForm = { email: '', role: 'member', message: '' };
      showInviteDialog = false;
      
      // Reload team details
      await loadTeamDetails(team);
    } catch (error) {
      console.error('Failed to invite member:', error);
    } finally {
      loading = false;
    }
  }

  async function removeMember(teamId: string, memberId: string) {
    if (!$apiService) return;

    try {
      loading = true;
      await $apiService.removeTeamMember(teamId, memberId);
      
      // Reload team details
      if (selectedTeam) {
        await loadTeamDetails(selectedTeam);
      }
    } catch (error) {
      console.error('Failed to remove member:', error);
    } finally {
      loading = false;
    }
  }

  async function updateMemberRole(teamId: string, memberId: string, role: string) {
    if (!$apiService) return;

    try {
      loading = true;
      await $apiService.updateMemberRole(teamId, memberId, role);
      
      // Reload team details
      if (selectedTeam) {
        await loadTeamDetails(selectedTeam);
      }
    } catch (error) {
      console.error('Failed to update member role:', error);
    } finally {
      loading = false;
    }
  }

  async function cancelInvitation(teamId: string, invitationId: string) {
    if (!$apiService) return;

    try {
      loading = true;
      await $apiService.cancelInvitation(teamId, invitationId);
      
      // Reload team details
      if (selectedTeam) {
        await loadTeamDetails(selectedTeam);
      }
    } catch (error) {
      console.error('Failed to cancel invitation:', error);
    } finally {
      loading = false;
    }
  }

  async function deleteTeam(team: Team) {
    if (!$apiService) return;

    try {
      loading = true;
      await teams.delete($apiService, team.id);
      
      // If this was the current team, clear it
      if ($currentTeam?.id === team.id) {
        currentTeam.set(null);
        selectedTeam = null;
      }
    } catch (error) {
      console.error('Failed to delete team:', error);
    } finally {
      loading = false;
    }
  }

  function getRoleIcon(role: string) {
    switch (role) {
      case 'owner':
        return Crown;
      case 'admin':
        return Shield;
      case 'member':
        return Users;
      case 'viewer':
        return Eye;
      default:
        return Users;
    }
  }

  function getRoleBadgeVariant(role: string) {
    switch (role) {
      case 'owner':
        return 'default';
      case 'admin':
        return 'secondary';
      case 'member':
        return 'outline';
      case 'viewer':
        return 'outline';
      default:
        return 'outline';
    }
  }

  function getInitials(name: string): string {
    return name
      .split(' ')
      .map(word => word.charAt(0))
      .join('')
      .toUpperCase()
      .slice(0, 2);
  }

  function formatDate(dateString: string): string {
    return new Date(dateString).toLocaleDateString();
  }

  function canManageTeam(team: Team): boolean {
    // Check if current user is owner or admin of the team
    const userTeam = teamMembers.find(member => member.user_id === $auth.user?.id);
    return userTeam?.role === 'owner' || userTeam?.role === 'admin';
  }
</script>

<div class="space-y-6">
  <!-- Header -->
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold text-foreground">Teams</h1>
      <p class="text-muted-foreground">
        Manage your teams and collaborate with others
      </p>
    </div>
    
    <Dialog bind:open={showCreateDialog}>
      <DialogTrigger>
        <Button>
          <Plus class="mr-2 h-4 w-4" />
          Create Team
        </Button>
      </DialogTrigger>
      <DialogContent class="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>Create New Team</DialogTitle>
          <DialogDescription>
            Create a new team to collaborate with others.
          </DialogDescription>
        </DialogHeader>
        <div class="space-y-4 py-4">
          <div class="space-y-2">
            <Label for="team-name">Team Name</Label>
            <Input
              id="team-name"
              bind:value={createForm.name}
              placeholder="Enter team name"
              required
            />
          </div>
          <div class="space-y-2">
            <Label for="team-description">Description</Label>
            <Textarea
              id="team-description"
              bind:value={createForm.description}
              placeholder="Describe your team (optional)"
              rows={3}
            />
          </div>
          <div class="space-y-2">
            <Label for="team-domain">Domain</Label>
            <Input
              id="team-domain"
              bind:value={createForm.domain}
              placeholder="team-domain (optional)"
            />
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onclick={() => (showCreateDialog = false)}>
            Cancel
          </Button>
          <Button onclick={createTeam} disabled={!createForm.name.trim() || isLoading}>
            {#if isLoading}
              Creating...
            {:else}
              Create Team
            {/if}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  </div>

  <!-- Teams Grid -->
  <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
    {#each teamsData as team (team.id)}
      <Card class="cursor-pointer transition-all hover:shadow-md {$currentTeam?.id === team.id ? 'ring-2 ring-primary' : ''}">
        <CardHeader class="pb-3">
          <div class="flex items-start justify-between">
            <div class="flex items-center space-x-3">
              <Avatar class="h-10 w-10">
                <AvatarFallback class="bg-primary text-primary-foreground">
                  {getInitials(team.name)}
                </AvatarFallback>
              </Avatar>
              <div>
                <CardTitle class="text-lg">{team.name}</CardTitle>
                {#if team.is_personal}
                  <Badge variant="outline" class="mt-1">Personal</Badge>
                {/if}
              </div>
            </div>
            
            <DropdownMenu>
              <DropdownMenuTrigger>
                <Button variant="ghost" size="sm">
                  <MoreHorizontal class="h-4 w-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onclick={() => selectTeam(team)}>
                  <ExternalLink class="mr-2 h-4 w-4" />
                  Open Team
                </DropdownMenuItem>
                {#if canManageTeam(team)}
                  <DropdownMenuItem onclick={() => { selectedTeam = team; showInviteDialog = true; }}>
                    <Mail class="mr-2 h-4 w-4" />
                    Invite Members
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                  <AlertDialog>
                    <AlertDialogTrigger>
                      <DropdownMenuItem class="text-destructive">
                        <Trash2 class="mr-2 h-4 w-4" />
                        Delete Team
                      </DropdownMenuItem>
                    </AlertDialogTrigger>
                    <AlertDialogContent>
                      <AlertDialogHeader>
                        <AlertDialogTitle>Are you sure?</AlertDialogTitle>
                        <AlertDialogDescription>
                          This action cannot be undone. This will permanently delete the team
                          "{team.name}" and remove all associated data.
                        </AlertDialogDescription>
                      </AlertDialogHeader>
                      <AlertDialogFooter>
                        <AlertDialogCancel>Cancel</AlertDialogCancel>
                        <AlertDialogAction onclick={() => deleteTeam(team)}>
                          Delete Team
                        </AlertDialogAction>
                      </AlertDialogFooter>
                    </AlertDialogContent>
                  </AlertDialog>
                {/if}
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </CardHeader>
        
        <CardContent>
          {#if team.description}
            <CardDescription class="mb-3">{team.description}</CardDescription>
          {/if}
          
          <div class="flex items-center justify-between text-sm text-muted-foreground">
            <div class="flex items-center space-x-4">
              <div class="flex items-center">
                <Users class="mr-1 h-4 w-4" />
                {team.members_count || 0} members
              </div>
              <div class="flex items-center">
                <Building class="mr-1 h-4 w-4" />
                {team.workspaces_count || 0} workspaces
              </div>
            </div>
            <div class="flex items-center">
              <Calendar class="mr-1 h-4 w-4" />
              {formatDate(team.created_at)}
            </div>
          </div>
          
          <Button 
            class="w-full mt-4" 
            variant={$currentTeam?.id === team.id ? 'default' : 'outline'}
            onclick={() => selectTeam(team)}
          >
            {$currentTeam?.id === team.id ? 'Current Team' : 'Select Team'}
          </Button>
        </CardContent>
      </Card>
    {/each}

    {#if teamsData.length === 0 && !isLoading}
      <div class="col-span-full">
        <Card class="border-dashed">
          <CardContent class="flex flex-col items-center justify-center py-12">
            <Users class="h-12 w-12 text-muted-foreground mb-4" />
            <h3 class="text-lg font-semibold mb-2">No teams yet</h3>
            <p class="text-muted-foreground text-center mb-4">
              Create your first team to start collaborating with others.
            </p>
            <Button onclick={() => (showCreateDialog = true)}>
              <Plus class="mr-2 h-4 w-4" />
              Create Team
            </Button>
          </CardContent>
        </Card>
      </div>
    {/if}
  </div>

  <!-- Team Details Modal -->
  {#if selectedTeam}
    <div class="mt-8">
      <Card>
        <CardHeader>
          <div class="flex items-center justify-between">
            <div>
              <CardTitle class="flex items-center space-x-3">
                <Avatar class="h-8 w-8">
                  <AvatarFallback class="bg-primary text-primary-foreground">
                    {getInitials(selectedTeam.name)}
                  </AvatarFallback>
                </Avatar>
                <span>{selectedTeam.name}</span>
              </CardTitle>
              {#if selectedTeam.description}
                <CardDescription class="mt-2">{selectedTeam.description}</CardDescription>
              {/if}
            </div>
            
            {#if canManageTeam(selectedTeam)}
              <Button onclick={() => { showInviteDialog = true; }}>
                <Mail class="mr-2 h-4 w-4" />
                Invite Members
              </Button>
            {/if}
          </div>
        </CardHeader>
        
        <CardContent>
          <!-- Team Members -->
          <div class="space-y-4">
            <h3 class="text-lg font-semibold">Members ({teamMembers.length})</h3>
            
            <div class="space-y-2">
              {#each teamMembers as member (member.id)}
                <div class="flex items-center justify-between p-3 rounded-lg border">
                  <div class="flex items-center space-x-3">
                    <Avatar class="h-8 w-8">
                      <AvatarImage src={member.user?.avatar} alt={member.user?.name} />
                      <AvatarFallback>
                        {getInitials(member.user?.name || 'Unknown')}
                      </AvatarFallback>
                    </Avatar>
                    <div>
                      <p class="font-medium">{member.user?.name || 'Unknown'}</p>
                      <p class="text-sm text-muted-foreground">{member.user?.email}</p>
                    </div>
                  </div>
                  
                  <div class="flex items-center space-x-2">
                    <Badge variant={getRoleBadgeVariant(member.role)}>
                      <svelte:component this={getRoleIcon(member.role)} class="mr-1 h-3 w-3" />
                      {member.role}
                    </Badge>
                    
                    {#if canManageTeam(selectedTeam) && member.user_id !== $auth.user?.id}
                      <DropdownMenu>
                        <DropdownMenuTrigger>
                          <Button variant="ghost" size="sm">
                            <MoreHorizontal class="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuLabel>Change Role</DropdownMenuLabel>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem onclick={() => updateMemberRole(selectedTeam.id, member.id, 'admin')}>
                            Make Admin
                          </DropdownMenuItem>
                          <DropdownMenuItem onclick={() => updateMemberRole(selectedTeam.id, member.id, 'member')}>
                            Make Member
                          </DropdownMenuItem>
                          <DropdownMenuItem onclick={() => updateMemberRole(selectedTeam.id, member.id, 'viewer')}>
                            Make Viewer
                          </DropdownMenuItem>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem 
                            class="text-destructive"
                            onclick={() => removeMember(selectedTeam.id, member.id)}
                          >
                            <UserX class="mr-2 h-4 w-4" />
                            Remove Member
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    {/if}
                  </div>
                </div>
              {/each}
            </div>

            <!-- Pending Invitations -->
            {#if teamInvitations.length > 0}
              <Separator />
              <h3 class="text-lg font-semibold">Pending Invitations ({teamInvitations.length})</h3>
              
              <div class="space-y-2">
                {#each teamInvitations as invitation (invitation.id)}
                  <div class="flex items-center justify-between p-3 rounded-lg border border-dashed">
                    <div class="flex items-center space-x-3">
                      <Avatar class="h-8 w-8">
                        <AvatarFallback class="bg-muted">
                          <Mail class="h-4 w-4" />
                        </AvatarFallback>
                      </Avatar>
                      <div>
                        <p class="font-medium">{invitation.email}</p>
                        <p class="text-sm text-muted-foreground">
                          Invited on {formatDate(invitation.created_at)}
                        </p>
                      </div>
                    </div>
                    
                    <div class="flex items-center space-x-2">
                      <Badge variant={getRoleBadgeVariant(invitation.role)}>
                        <svelte:component this={getRoleIcon(invitation.role)} class="mr-1 h-3 w-3" />
                        {invitation.role}
                      </Badge>
                      <Badge variant="outline">
                        <Clock class="mr-1 h-3 w-3" />
                        {invitation.status}
                      </Badge>
                      
                      {#if canManageTeam(selectedTeam)}
                        <Button 
                          variant="ghost" 
                          size="sm"
                          onclick={() => cancelInvitation(selectedTeam.id, invitation.id)}
                        >
                          Cancel
                        </Button>
                      {/if}
                    </div>
                  </div>
                {/each}
              </div>
            {/if}
          </div>
        </CardContent>
      </Card>
    </div>
  {/if}
</div>

<!-- Invite Member Dialog -->
<Dialog bind:open={showInviteDialog}>
  <DialogContent class="sm:max-w-[425px]">
    <DialogHeader>
      <DialogTitle>Invite Team Member</DialogTitle>
      <DialogDescription>
        Invite someone to join {selectedTeam?.name || 'your team'}.
      </DialogDescription>
    </DialogHeader>
    <div class="space-y-4 py-4">
      <div class="space-y-2">
        <Label for="invite-email">Email Address</Label>
        <Input
          id="invite-email"
          type="email"
          bind:value={inviteForm.email}
          placeholder="Enter email address"
          required
        />
      </div>
      <div class="space-y-2">
        <Label for="invite-role">Role</Label>
        <select
          id="invite-role"
          bind:value={inviteForm.role}
          class="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
        >
          <option value="viewer">Viewer - Can view content</option>
          <option value="member">Member - Can create and edit</option>
          <option value="admin">Admin - Can manage team</option>
        </select>
      </div>
      <div class="space-y-2">
        <Label for="invite-message">Message (Optional)</Label>
        <Textarea
          id="invite-message"
          bind:value={inviteForm.message}
          placeholder="Add a personal message"
          rows={3}
        />
      </div>
    </div>
    <DialogFooter>
      <Button variant="outline" onclick={() => (showInviteDialog = false)}>
        Cancel
      </Button>
      <Button 
        onclick={() => selectedTeam && inviteMember(selectedTeam)}
        disabled={!inviteForm.email.trim() || isLoading}
      >
        {#if isLoading}
          Sending...
        {:else}
          Send Invitation
        {/if}
      </Button>
    </DialogFooter>
  </DialogContent>
</Dialog>