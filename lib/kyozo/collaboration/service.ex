defmodule Kyozo.Collaboration.Service do
  @moduledoc """
  Main service module for managing real-time collaborative editing features.

  This service orchestrates collaboration sessions, handles operation transformation,
  manages user presence, and coordinates real-time synchronization between clients.
  """

  alias Kyozo.Collaboration
  alias Kyozo.Collaboration.{Session, Operation, Cursor, Presence, OperationalTransform}
  alias Kyozo.Workspaces

  require Logger

  @doc """
  Start or join a collaboration session for a resource.

  ## Parameters
  - `resource_type`: Type of resource (:document, :notebook, :file)
  - `resource_id`: ID of the resource
  - `user`: User joining the session
  - `opts`: Optional session settings

  ## Returns
  - `{:ok, session}`: Successfully started/joined session
  - `{:error, reason}`: Failed to start/join session
  """
  def start_or_join_session(resource_type, resource_id, user, opts \\ []) do
    with {:ok, session} <- get_or_create_session(resource_type, resource_id, user, opts),
         {:ok, _presence} <- join_session_presence(session, user),
         :ok <- broadcast_user_joined(session, user) do
      # Increment participant count
      Collaboration.update_session(session, :add_participant, actor: user)
    end
  end

  @doc """
  Leave a collaboration session.

  ## Parameters
  - `session_id`: ID of the session to leave
  - `user`: User leaving the session

  ## Returns
  - `:ok`: Successfully left session
  - `{:error, reason}`: Failed to leave session
  """
  def leave_session(session_id, user) do
    with {:ok, session} <- Collaboration.get_session(session_id, actor: user),
         {:ok, _presence} <- update_presence_offline(session, user),
         :ok <- broadcast_user_left(session, user),
         {:ok, _session} <-
           Collaboration.update_session(session, :remove_participant, actor: user) do
      # End session if no participants left
      if session.participants_count <= 1 do
        Collaboration.update_session(session, :end_session, actor: user)
      end

      :ok
    end
  end

  @doc """
  Apply an operation to a collaborative session.

  This handles operational transformation, applies the operation to the document,
  and broadcasts the changes to all participants.

  ## Parameters
  - `session_id`: ID of the collaboration session
  - `operation_data`: Operation data to apply
  - `user`: User creating the operation

  ## Returns
  - `{:ok, {operation, transformed_operations}}`: Successfully applied operation
  - `{:error, reason}`: Failed to apply operation
  """
  def apply_operation(session_id, operation_data, user) do
    with {:ok, session} <- Collaboration.get_session(session_id, actor: user),
         {:ok, operation} <- create_operation(session, operation_data, user),
         {:ok, {op, transformed_ops}} <- transform_and_apply_operation(session, operation),
         :ok <- broadcast_operation(session, op, user),
         {:ok, _session} <- Collaboration.update_session(session, :increment_version, actor: user) do
      {:ok, {op, transformed_ops}}
    end
  end

  @doc """
  Update cursor position for a user in a session.

  ## Parameters
  - `session_id`: ID of the collaboration session
  - `cursor_data`: Cursor position and selection data
  - `user`: User updating cursor

  ## Returns
  - `{:ok, cursor}`: Successfully updated cursor
  - `{:error, reason}`: Failed to update cursor
  """
  def update_cursor(session_id, cursor_data, user) do
    with {:ok, session} <- Collaboration.get_session(session_id, actor: user),
         {:ok, cursor} <- upsert_cursor(session, cursor_data, user),
         :ok <- broadcast_cursor_update(session, cursor, user) do
      {:ok, cursor}
    end
  end

  @doc """
  Update user presence status in a session.

  ## Parameters
  - `session_id`: ID of the collaboration session
  - `status`: New presence status (:online, :away, :typing, :idle)
  - `user`: User updating presence
  - `metadata`: Additional presence metadata

  ## Returns
  - `{:ok, presence}`: Successfully updated presence
  - `{:error, reason}`: Failed to update presence
  """
  def update_presence(session_id, status, user, metadata \\ %{}) do
    with {:ok, session} <- Collaboration.get_session(session_id, actor: user),
         {:ok, presence} <- upsert_presence(session, status, user, metadata),
         :ok <- broadcast_presence_update(session, presence, user) do
      {:ok, presence}
    end
  end

  @doc """
  Get current session state including operations, cursors, and presence.

  ## Parameters
  - `session_id`: ID of the collaboration session
  - `user`: User requesting session state
  - `since_version`: Only include operations since this version (optional)

  ## Returns
  - `{:ok, session_state}`: Current session state
  - `{:error, reason}`: Failed to get session state
  """
  def get_session_state(session_id, user, since_version \\ 0) do
    with {:ok, session} <- Collaboration.get_session(session_id, actor: user),
         {:ok, operations} <- get_session_operations(session, since_version),
         {:ok, cursors} <- get_active_cursors(session),
         {:ok, presences} <- get_active_presences(session) do
      state = %{
        session: session,
        operations: operations,
        cursors: cursors,
        presences: presences,
        version: session.document_version
      }

      {:ok, state}
    end
  end

  @doc """
  Synchronize document content with all operations applied.

  ## Parameters
  - `session_id`: ID of the collaboration session
  - `user`: User requesting synchronization

  ## Returns
  - `{:ok, {content, version}}`: Current synchronized content and version
  - `{:error, reason}`: Failed to synchronize
  """
  def synchronize_document(session_id, user) do
    with {:ok, session} <- Collaboration.get_session(session_id, actor: user),
         {:ok, base_content} <- get_base_document_content(session),
         {:ok, operations} <- get_all_session_operations(session),
         {:ok, final_content} <- OperationalTransform.apply_operations(base_content, operations) do
      {:ok, {final_content, session.document_version}}
    end
  end

  @doc """
  Clean up stale cursors and presence records.

  This should be called periodically to remove inactive cursors and offline users.
  """
  def cleanup_stale_data(session_id, user) do
    with {:ok, session} <- Collaboration.get_session(session_id, actor: user) do
      # Remove cursors inactive for more than 30 seconds
      stale_cursor_cutoff = DateTime.add(DateTime.utc_now(), -30, :second)

      stale_cursors =
        Collaboration.list_session_cursors(session.id, active_only: false, actor: user)
        |> Enum.filter(&DateTime.before?(&1.last_activity_at, stale_cursor_cutoff))

      Enum.each(stale_cursors, fn cursor ->
        Collaboration.update_cursor(cursor, :set_inactive, actor: user)
      end)

      # Mark users as away if inactive for more than 5 minutes
      away_cutoff = DateTime.add(DateTime.utc_now(), -300, :second)

      inactive_presences =
        Collaboration.list_session_presences(session.id, active_only: false, actor: user)
        |> Enum.filter(fn presence ->
          presence.status == :online and DateTime.before?(presence.last_seen_at, away_cutoff)
        end)

      Enum.each(inactive_presences, fn presence ->
        Collaboration.update_presence(presence, :set_away, actor: user)
      end)

      # Mark users as offline if away for more than 30 minutes
      offline_cutoff = DateTime.add(DateTime.utc_now(), -1800, :second)

      away_presences =
        Collaboration.list_session_presences(session.id, active_only: false, actor: user)
        |> Enum.filter(fn presence ->
          presence.status == :away and DateTime.before?(presence.last_seen_at, offline_cutoff)
        end)

      Enum.each(away_presences, fn presence ->
        Collaboration.update_presence(presence, :set_offline, actor: user)
      end)

      :ok
    end
  end

  # Private implementation functions

  defp get_or_create_session(resource_type, resource_id, user, opts) do
    case Collaboration.get_by_resource(resource_type, resource_id, actor: user) do
      {:ok, session} ->
        {:ok, session}

      {:error, :not_found} ->
        create_session(resource_type, resource_id, user, opts)

      error ->
        error
    end
  end

  defp create_session(resource_type, resource_id, user, opts) do
    title = Keyword.get(opts, :title, "Collaboration Session")
    max_participants = Keyword.get(opts, :max_participants, 50)
    settings = Keyword.get(opts, :settings, %{})

    session_attrs = %{
      resource_type: resource_type,
      resource_id: resource_id,
      title: title,
      max_participants: max_participants,
      settings: settings
    }

    Collaboration.create_session(session_attrs, actor: user, tenant: user.team_id)
  end

  defp join_session_presence(session, user) do
    presence_attrs = %{
      status: :online,
      metadata: %{
        "client" => "web",
        "joined_at" => DateTime.utc_now()
      }
    }

    case Collaboration.get_user_presence(session.id, user.id, actor: user) do
      {:ok, presence} ->
        Collaboration.update_presence(presence, :set_online, actor: user)

      {:error, :not_found} ->
        Collaboration.create_presence(
          Map.put(presence_attrs, :session_id, session.id),
          actor: user
        )
    end
  end

  defp update_presence_offline(session, user) do
    case Collaboration.get_user_presence(session.id, user.id, actor: user) do
      {:ok, presence} ->
        Collaboration.update_presence(presence, :set_offline, actor: user)

      {:error, :not_found} ->
        {:ok, nil}
    end
  end

  defp create_operation(session, operation_data, user) do
    # Convert operation_data to proper format
    operation_attrs =
      operation_data
      |> OperationalTransform.to_operation_attributes()
      |> Map.put(:session_id, session.id)
      |> Map.put(:version, session.document_version + 1)
      |> Map.put(:client_id, generate_client_id(user))

    Collaboration.create_operation(operation_attrs, actor: user)
  end

  defp transform_and_apply_operation(session, operation) do
    # Get concurrent operations at the same version
    concurrent_ops =
      Collaboration.list_session_operations(session.id,
        since_version: operation.version - 1,
        actor: operation.user
      )
      |> Enum.reject(&(&1.id == operation.id))

    # Transform against all concurrent operations
    transformed_ops =
      concurrent_ops
      |> Enum.reduce([operation], fn concurrent_op, acc_ops ->
        Enum.map(acc_ops, fn op ->
          case OperationalTransform.transform(
                 OperationalTransform.from_operation_record(op),
                 OperationalTransform.from_operation_record(concurrent_op),
                 :left
               ) do
            {:ok, {transformed_op, _}} ->
              # Update the operation record with transformation results
              transformed_attrs = OperationalTransform.to_operation_attributes(transformed_op)

              {:ok, updated_op} =
                Collaboration.update_operation(op, :apply_transformation,
                  transformed_position: Map.get(transformed_attrs, :position),
                  transformed_length: Map.get(transformed_attrs, :length),
                  actor: operation.user
                )

              updated_op

            {:error, reason} ->
              Logger.warning("Operation transformation failed: #{reason}")
              op
          end
        end)
      end)

    # Mark operations as applied
    Enum.each(transformed_ops, fn op ->
      Collaboration.update_operation(op, :mark_applied, actor: operation.user)
    end)

    {:ok, {operation, transformed_ops}}
  end

  defp upsert_cursor(session, cursor_data, user) do
    case Collaboration.get_user_cursor(session.id, user.id, actor: user) do
      {:ok, cursor} ->
        Collaboration.update_cursor(cursor, :update_position, cursor_data, actor: user)

      {:error, :not_found} ->
        cursor_attrs =
          cursor_data
          |> Map.put(:session_id, session.id)

        Collaboration.create_cursor(cursor_attrs, actor: user)
    end
  end

  defp upsert_presence(session, status, user, metadata) do
    case Collaboration.get_user_presence(session.id, user.id, actor: user) do
      {:ok, presence} ->
        Collaboration.update_presence(presence, :update_status,
          status: status,
          metadata: metadata,
          actor: user
        )

      {:error, :not_found} ->
        presence_attrs = %{
          session_id: session.id,
          status: status,
          metadata: metadata
        }

        Collaboration.create_presence(presence_attrs, actor: user)
    end
  end

  defp get_session_operations(session, since_version) do
    {:ok,
     Collaboration.list_session_operations(session.id,
       since_version: since_version,
       actor: session.owner
     )}
  end

  defp get_all_session_operations(session) do
    {:ok,
     Collaboration.list_session_operations(session.id,
       since_version: 0,
       actor: session.owner
     )
     |> Enum.map(&OperationalTransform.from_operation_record/1)}
  end

  defp get_active_cursors(session) do
    {:ok, Collaboration.list_session_cursors(session.id, active_only: true, actor: session.owner)}
  end

  defp get_active_presences(session) do
    {:ok,
     Collaboration.list_session_presences(session.id, active_only: true, actor: session.owner)}
  end

  defp get_base_document_content(session) do
    case session.resource_type do
      :notebook ->
        case Workspaces.get_notebook(session.resource_id, actor: session.owner) do
          {:ok, notebook} -> {:ok, notebook.content || ""}
          error -> error
        end

      :document ->
        case Workspaces.get_document(session.resource_id, actor: session.owner) do
          {:ok, document} -> {:ok, document.content || ""}
          error -> error
        end

      :file ->
        case Workspaces.get_file(session.resource_id, actor: session.owner) do
          {:ok, file} ->
            case Workspaces.Storage.read_file_content(file) do
              {:ok, content} -> {:ok, content}
              error -> error
            end

          error ->
            error
        end

      _ ->
        {:error, "Unknown resource type: #{session.resource_type}"}
    end
  end

  defp generate_client_id(user) do
    "#{user.id}_#{System.system_time(:millisecond)}"
  end

  # Broadcasting functions

  defp broadcast_user_joined(session, user) do
    Phoenix.PubSub.broadcast(
      Kyozo.PubSub,
      session_topic(session),
      {:collaboration_user_joined, %{user: serialize_user(user), session_id: session.id}}
    )
  end

  defp broadcast_user_left(session, user) do
    Phoenix.PubSub.broadcast(
      Kyozo.PubSub,
      session_topic(session),
      {:collaboration_user_left, %{user: serialize_user(user), session_id: session.id}}
    )
  end

  defp broadcast_operation(session, operation, user) do
    Phoenix.PubSub.broadcast(
      Kyozo.PubSub,
      session_topic(session),
      {:collaboration_operation,
       %{
         operation: serialize_operation(operation),
         user: serialize_user(user),
         session_id: session.id,
         version: operation.version
       }}
    )
  end

  defp broadcast_cursor_update(session, cursor, user) do
    Phoenix.PubSub.broadcast(
      Kyozo.PubSub,
      session_topic(session),
      {:collaboration_cursor_update,
       %{
         cursor: serialize_cursor(cursor),
         user: serialize_user(user),
         session_id: session.id
       }}
    )
  end

  defp broadcast_presence_update(session, presence, user) do
    Phoenix.PubSub.broadcast(
      Kyozo.PubSub,
      session_topic(session),
      {:collaboration_presence_update,
       %{
         presence: serialize_presence(presence),
         user: serialize_user(user),
         session_id: session.id
       }}
    )
  end

  defp session_topic(session) do
    "collaboration:#{session.resource_type}:#{session.resource_id}"
  end

  # Serialization functions for broadcasting

  defp serialize_user(user) do
    %{
      id: user.id,
      name: user.name || user.email,
      email: user.email,
      avatar_url: get_user_avatar(user)
    }
  end

  defp serialize_operation(operation) do
    %{
      id: operation.id,
      type: operation.operation_type,
      position: operation.position,
      length: operation.length,
      content: operation.content,
      version: operation.version,
      data: operation.operation_data,
      created_at: operation.created_at
    }
  end

  defp serialize_cursor(cursor) do
    %{
      id: cursor.id,
      user_id: cursor.user_id,
      position: cursor.position,
      selection_start: cursor.selection_start,
      selection_end: cursor.selection_end,
      selection_direction: cursor.selection_direction,
      color: cursor.cursor_color,
      is_active: cursor.is_active,
      metadata: cursor.metadata
    }
  end

  defp serialize_presence(presence) do
    %{
      id: presence.id,
      user_id: presence.user_id,
      status: presence.status,
      last_seen_at: presence.last_seen_at,
      metadata: presence.metadata
    }
  end

  defp get_user_avatar(user) do
    if user.profile && user.profile["avatar_url"] do
      user.profile["avatar_url"]
    else
      # Generate a default avatar URL based on user initials
      initials =
        if user.name do
          user.name
          |> String.split()
          |> Enum.map(&String.first/1)
          |> Enum.join()
          |> String.upcase()
        else
          String.first(user.email) |> String.upcase()
        end

      "https://ui-avatars.com/api/?name=#{URI.encode(initials)}&size=40&background=random"
    end
  end
end
