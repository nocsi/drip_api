defmodule KyozoWeb.Accounts.Groups.GroupPermissionsLive do
  use KyozoWeb, :live_view
  import KyozoWeb.Components.Button

  def render(assigns) do
    ~H"""
    <.button navigate={~p"/accounts/groups"}>{gettext("Back to access groups")}</.button>
    <.header class="mt-4">
      <.icon name="hero-shield-check" /> {gettext("%{name} Access Permissions", name: @group.name)}
      <:subtitle>{@group.description}</:subtitle>
    </.header>

    <%!-- Group permissions --%>
    <div class="mt-4">
      <KyozoWeb.Accounts.Groups.GroupPermissionForm.form
        group_id={@group_id}
        actor={@current_user}
      />
    </div>
    """
  end

  def mount(%{"group_id" => group_id}, _session, socket) do
    socket
    |> assign(:group_id, group_id)
    |> assign_group()
  end

  defp assign_group(socket) do
    %{current_user: actor, group_id: group_id} = socket.assigns
    assign(socket, :group, get_group(actor, group_id))
  end

  defp get_group(actor, group_id) do
    Ash.get!(Kyozo.Accounts.Group, group_id, actor: actor)
  end
end
