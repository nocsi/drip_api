export type Team = {
    id: string;
    name: string;
    domain: string;
    description?: string;
    owner_user_id?: string;
    inserted_at: string;
    updated_at: string;
};

export type UserTeam = {
    id: string;
    user_id: string;
    team_id: string;
    role: 'admin' | 'member' | 'owner';
    inserted_at: string;
    updated_at: string;
    user?: User;
    team?: Team;
    can_manage?: boolean;
};

export type Invitation = {
    id: string;
    team_id: string;
    invited_user_id: string;
    inviter_user_id: string;
    invited_user?: User;
    inviter_user?: User;
    team?: Team;
};

export type User = {
    id: string;
    name: string;
    email: string;
    picture?: string;
    confirmed_at?: string;
};

export type TeamDashboardState = {
    current_tab: 'overview' | 'teams' | 'invitations';
    user_teams: Team[];
    selected_team?: Team;
    team_members: UserTeam[];
    received_invitations: Invitation[];
    sent_invitations: Invitation[];
    show_create_team_modal: boolean;
    show_invite_modal: boolean;
};
