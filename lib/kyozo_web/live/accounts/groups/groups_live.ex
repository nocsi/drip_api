# lib/helpcenter_web/live/accounts/groups/groups_live.ex
defmodule KyozoWeb.Accounts.Groups.GroupsLive do
  use KyozoWeb, :live_view
  import KyozoWeb.Components.Link
  import KyozoWeb.Components.Modal
  import KyozoWeb.Components.Table


  def render(assigns) do
    ~H"""
    <div class="flex justify-between">
      <.header class="mt-4">
        <.icon name="hero-user-group-solid" />
        {gettext("User Access Groups")}
        <:subtitle>
          {gettext("Create, update and manage user access groups and their permissions")}
        </:subtitle>
      </.header>
      <%!-- Access Group Create form --%>
      <KyozoWeb.Accounts.Groups.GroupForm.form actor={@current_user} id={Ash.UUIDv7.generate()} />
    </div>
    <%!-- Table groups --%>
    <.table id="groups" rows={@groups}>
      <:col :let={group} label={gettext("Name")}>{group.name}</:col>
      <:col :let={group} label={gettext("Description")}>{group.description}</:col>
      <:action :let={group}>
        <div class="space-x-6">

          <.modal
            id={"access-group-form-modal#{group.id}"}
            title={gettext("Edit Access Group")}
            cancel={hide_modal("access-group-form-modal#{group.id}")}
          >
            <.icon name="hero-pencil-solid" class="h-4 w-4" />
            {gettext("Edit")}
            <KyozoWeb.Accounts.Groups.GroupForm.form actor={@current_user} id={group.id} />
          </.modal>

          <.link
            id={"access-group-permissions-#{group.id}"}
            navigate={~p"/accounts/groups/#{group.id}/permissions"}
            class="font-semibold leading-6 text-zinc-900 hover:text-zinc-700 hover:underline"
          >
            <.icon name="hero-shield-check" class="h-4 w-4" />
            {gettext("Permissions")}
          </.link>
        </div>
      </:action>
    </.table>

    <%!-- Modals for group editing --%>
    <KyozoWeb.Accounts.Groups.GroupForm.form
      :for={group <- @groups}
      actor={@current_user}
      group_id={group.id}
      show_button={false}
      id={group.id}
    />
    """
  end

  def mount(_params, _sessions, socket) do
    socket = socket
    |> maybe_subscribe()
    |> assign_groups()

    {:ok, socket}
  end

  def handle_info(_message, socket) do
    socket = socket
    |> assign_groups()

    {:noreply, socket}
  end

  # Subscribe connected users to the "groups" topic for real-time
  # notifications when changes happen on access group
  defp maybe_subscribe(socket) do
    if connected?(socket), do: KyozoWeb.Endpoint.subscribe("groups")

    socket
  end

  defp assign_groups(socket) do
    assign(socket, :groups, get_groups(socket.assigns.current_user))
  end

  defp get_groups(actor) do
    Ash.read!(Kyozo.Accounts.Group, actor: actor)
  end
end
