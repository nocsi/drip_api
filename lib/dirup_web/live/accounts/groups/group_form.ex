defmodule DirupWeb.Accounts.Groups.GroupForm do
  use DirupWeb, :live_component
  alias AshPhoenix.Form

  import DirupWeb.Components.Button
  import DirupWeb.Components.Form
  import DirupWeb.Components.Modal

  @doc """
  This a wrapper used to access this component like a static component
  in the template.

  example:
    <DirupWeb.Accounts.Groups.GroupForm.form
      :for={group <- @groups}
      actor={@current_user}
      group_id={group.id}
      show_button={false}
      id={group.id}
    />

  """
  attr :id, :string, default: Ash.UUIDv7.generate()
  attr :group_id, :string, default: nil
  attr :show_button, :boolean, default: true, doc: "Show button to create new group"
  attr :actor, Dirup.Accounts.User, required: true

  def form(assigns) do
    ~H"""
    <.live_component
      id={@id}
      actor={@actor}
      module={__MODULE__}
      group_id={@group_id}
      show_button={@show_button}
    />
    """
  end

  attr :id, :string, default: Ash.UUIDv7.generate()
  attr :group_id, :string, default: nil
  attr :show_button, :boolean, default: true
  attr :actor, Dirup.Accounts.User, required: true

  def render(assigns) do
    ~H"""
    <div id={"access-group-#{@group_id}"} class="mt-4">
      <%!-- Form modal trigger Button --%>
      <div class="flex justify-end">
        <.modal id={"access-group-modal-button#{@group_id}"} on_cancel={JS.navigate(~p"/posts")}>
          <.icon name="hero-plus-solid" class="h-5 w-5" />
        </.modal>
      </div>

      <%!-- We want this form to show-up in a modal --%>
      <.modal id={"access-group-form-modal#{@group_id}"}>
        <.header class="mt-4">
          <.icon name="hero-user-group" />
          <%!-- New Group --%>
          <span :if={is_nil(@group_id)}>{gettext("New Access Group")}</span>
          <:subtitle :if={is_nil(@group_id)}>
            {gettext("Fill below form to create a new user access group")}
          </:subtitle>

          <%!-- Existing group --%>
          <span :if={@group_id}>{@form.source.data.name}</span>
          <:subtitle :if={@group_id}>
            {gettext("Fill below form to update %{name} access group details.",
              name: @form.source.data.name
            )}
          </:subtitle>
        </.header>
        <.simple_form
          for={@form}
          phx-change="validate"
          phx-submit="save"
          id={"access-group-form#{@group_id}"}
          phx-target={@myself}
        >
          <.input
            field={@form[:name]}
            id={"access-group-name#{@id}-#{@group_id}"}
            label={gettext("Access Group Name")}
          />
          <.input
            field={@form[:description]}
            id={"access-group-description#{@id}-#{@group_id}"}
            type="textarea"
            label={gettext("Description")}
          />
          <:actions>
            <.button class="w-full" phx-disable-with={gettext("Saving...")}>
              {gettext("Submit")}
            </.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_form()
  end

  def handle_event("validate", %{"form" => attrs}, socket) do
    socket =
      socket
      |> assign(:form, Form.validate(socket.assigns.form, attrs))

    {:noreply, socket}
  end

  def handle_event("save", %{"form" => attrs}, socket) do
    case Form.submit(socket.assigns.form, params: attrs) do
      {:ok, _group} ->
        socket =
          socket
          |> put_flash(:info, gettext("Access Group Submitted."))

        {:noreply, socket}

      {:error, form} ->
        socket =
          socket
          |> assign(:form, form)

        {:noreply, socket}
    end
  end

  # Prevents the form from being re-created on every update
  defp assign_form(%{assigns: %{form: _form}} = socket), do: socket

  defp assign_form(%{assigns: assigns} = socket) do
    assign(socket, :form, get_form(assigns))
  end

  # Build for the new access group
  defp get_form(%{group_id: nil} = assigns) do
    Dirup.Accounts.Group
    |> Form.for_create(:create, actor: assigns.actor)
    |> to_form()
  end

  # Build for the existing access group
  defp get_form(%{group_id: group_id} = assigns) do
    Dirup.Accounts.Group
    |> Ash.get!(group_id, actor: assigns.actor)
    |> Form.for_update(:update, actor: assigns.actor)
    |> to_form()
  end
end
