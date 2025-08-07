defmodule KyozoWeb.Live.Workspace.Form do
  @moduledoc """
  LiveComponent for creating and editing workspaces using AshPhoenix.Form.
  """
  use KyozoWeb, :live_component

  import KyozoWeb.Components.Button

  alias Kyozo.Workspaces
  alias Kyozo.Workspaces.Workspace

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="workspace-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" required />
        <.input field={@form[:description]} type="textarea" label="Description" rows="3" />

        <.input
          field={@form[:storage_backend]}
          type="select"
          label="Storage Backend"
          options={[
            {"Hybrid (Git + S3)", :hybrid},
            {"Git Only", :git},
            {"S3 Only", :s3}
          ]}
        />

        <.input
          field={@form[:tags]}
          type="text"
          label="Tags (comma-separated)"
          placeholder="e.g., project, documentation, research"
        />

        <:actions>
          <slot name="actions" />
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{data: workspace, action: action} = assigns, socket) do
    form = case action do
      :new ->
        AshPhoenix.Form.for_create(Workspace, :create_workspace,
          api: Kyozo.Workspaces,
          actor: assigns[:current_user],
          tenant: assigns[:current_team]
        )
      :edit ->
        AshPhoenix.Form.for_update(workspace, :update_workspace,
          api: Kyozo.Workspaces,
          actor: assigns[:current_user]
        )
    end
    |> to_form()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("validate", %{"workspace" => workspace_params}, socket) do
    # Convert tags string to array before validation
    workspace_params = normalize_tags(workspace_params)

    form =
      socket.assigns.form
      |> AshPhoenix.Form.validate(workspace_params)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"workspace" => workspace_params}, socket) do
    # Convert tags string to array before submission
    workspace_params = normalize_tags(workspace_params)

    case AshPhoenix.Form.submit(socket.assigns.form, params: workspace_params) do
      {:ok, workspace} ->
        notify_parent({:saved, workspace})

        {:noreply,
         socket
         |> put_flash(:info, "Workspace #{socket.assigns.action == :new && "created" || "updated"} successfully")
         |> push_patch(to: socket.assigns.patch || ~p"/workspaces")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp normalize_tags(%{"tags" => tags_string} = params) when is_binary(tags_string) do
    tags =
      tags_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    Map.put(params, "tags", tags)
  end

  defp normalize_tags(params), do: params

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
