defmodule KyozoWeb.API.TeamsJSON do
  alias Kyozo.Accounts.Team
  alias Kyozo.Accounts.UserTeam
  alias Kyozo.Accounts.Invitation
  alias Kyozo.Workspaces.Workspace

  @doc """
  Renders a list of teams.
  """
  def index(%{teams: teams}) do
    %{data: for(team <- teams, do: data(team))}
  end

  @doc """
  Renders a single team.
  """
  def show(%{team: team}) do
    %{data: data(team)}
  end

  @doc """
  Renders team members.
  """
  def members(%{members: members}) do
    %{data: for(member <- members, do: member_data(member))}
  end

  @doc """
  Renders a single team member.
  """
  def member(%{member: member}) do
    %{data: member_data(member)}
  end

  @doc """
  Renders team invitations.
  """
  def invitations(%{invitations: invitations}) do
    %{data: for(invitation <- invitations, do: invitation_data(invitation))}
  end

  @doc """
  Renders a single invitation.
  """
  def invitation(%{invitation: invitation}) do
    %{data: invitation_data(invitation)}
  end

  @doc """
  Renders team workspaces.
  """
  def workspaces(%{workspaces: workspaces}) do
    %{data: for(workspace <- workspaces, do: workspace_data(workspace))}
  end

  defp data(%Team{} = team) do
    %{
      id: team.id,
      name: team.name,
      created_at: team.created_at,
      updated_at: team.updated_at,
      members_count: get_members_count(team),
      workspaces_count: get_workspaces_count(team),
      members: nil, # Team members loaded separately
      workspaces: render_if_loaded(team.workspaces, &workspace_data/1)
    }
  end

  defp member_data(%UserTeam{} = member) do
    %{
      id: member.id,
      user_id: member.user_id,
      team_id: member.team_id,
      role: member.role,
      created_at: member.created_at,
      updated_at: member.updated_at,
      user: render_if_loaded(member.user, &user_data/1)
    }
  end

  defp invitation_data(%Invitation{} = invitation) do
    %{
      id: invitation.id,
      team_id: invitation.team_id,
      invited_user_id: invitation.invited_user_id,
      invited_email: invitation.invited_email,
      role: invitation.role,
      status: invitation.status,
      expires_at: invitation.expires_at,
      created_at: invitation.created_at,
      updated_at: invitation.updated_at,
      team: render_if_loaded(invitation.team, &basic_team_data/1),
      invited_user: render_if_loaded(invitation.invited_user, &user_data/1)
    }
  end

  defp workspace_data(%Workspace{} = workspace) do
    %{
      id: workspace.id,
      name: workspace.name,
      description: workspace.description,
      status: workspace.status,
      storage_backend: workspace.storage_backend,
      tags: workspace.tags || [],
      created_at: workspace.created_at,
      updated_at: workspace.updated_at,
      team_id: workspace.team_id,
      document_count: workspace.document_count || 0,
      notebook_count: workspace.notebook_count || 0,
      last_activity: workspace.last_activity
    }
  end

  defp user_data(user) when is_map(user) do
    %{
      id: user.id,
      email: user.email,
      username: user.username || extract_username_from_email(user.email),
      created_at: user.created_at
    }
  end

  defp basic_team_data(%Team{} = team) do
    %{
      id: team.id,
      name: team.name
    }
  end

  defp render_if_loaded(%Ash.NotLoaded{}, _fun), do: nil
  defp render_if_loaded(nil, _fun), do: nil
  defp render_if_loaded(data, fun) when is_list(data), do: Enum.map(data, fun)
  defp render_if_loaded(data, fun), do: fun.(data)

  defp get_members_count(_team), do: nil

  defp get_workspaces_count(_team), do: nil

  defp extract_username_from_email(email) when is_binary(email) do
    email
    |> String.split("@")
    |> List.first()
  end
  defp extract_username_from_email(_), do: nil
end