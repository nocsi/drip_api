defmodule Dirup.Workspaces.Workspace.Validations do
  @moduledoc """
  Custom validation modules for Workspace resource.
  """

  defmodule ValidateStorageBackend do
    @moduledoc """
    Validates that the storage backend is appropriate for the workspace configuration.
    """
    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def validate(changeset, _opts, _context) do
      storage_backend = Ash.Changeset.get_attribute(changeset, :storage_backend)
      settings = Ash.Changeset.get_attribute(changeset, :settings) || %{}

      case validate_backend_compatibility(storage_backend, settings) do
        :ok -> :ok
        {:error, message} -> {:error, field: :storage_backend, message: message}
      end
    end

    defp validate_backend_compatibility(:git, settings) do
      # Git backend doesn't support binary files well
      if Map.get(settings, "allow_binary_files", false) do
        {:error, "Git backend is not recommended for workspaces with binary files enabled"}
      else
        :ok
      end
    end

    defp validate_backend_compatibility(:s3, settings) do
      # S3 backend doesn't support versioning as well as Git
      if Map.get(settings, "enable_versioning", true) do
        {:error, "S3 backend has limited versioning capabilities compared to Git"}
      else
        :ok
      end
    end

    defp validate_backend_compatibility(:hybrid, _settings) do
      # Hybrid backend supports everything
      :ok
    end

    defp validate_backend_compatibility(backend, _settings) do
      {:error, "Unknown storage backend: #{backend}"}
    end
  end

  defmodule ValidateSettings do
    @moduledoc """
    Validates workspace settings structure and values.
    """
    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def validate(changeset, _opts, _context) do
      settings = Ash.Changeset.get_attribute(changeset, :settings)

      case settings do
        nil ->
          :ok

        settings when is_map(settings) ->
          validate_settings_structure(settings)

        _ ->
          {:error, field: :settings, message: "Settings must be a map"}
      end
    end

    defp validate_settings_structure(settings) do
      with :ok <- validate_required_settings(settings),
           :ok <- validate_setting_types(settings),
           :ok <- validate_setting_values(settings) do
        :ok
      end
    end

    defp validate_required_settings(settings) do
      required_keys = ["auto_save", "max_file_size", "allowed_file_types"]

      missing_keys =
        Enum.filter(required_keys, fn key ->
          not Map.has_key?(settings, key)
        end)

      if Enum.empty?(missing_keys) do
        :ok
      else
        {:error,
         field: :settings, message: "Missing required settings: #{Enum.join(missing_keys, ", ")}"}
      end
    end

    defp validate_setting_types(settings) do
      type_validations = [
        {"auto_save", &is_boolean/1, "must be a boolean"},
        {"auto_commit", &is_boolean/1, "must be a boolean"},
        {"max_file_size", &is_integer/1, "must be an integer"},
        {"allowed_file_types", &is_list/1, "must be a list"},
        {"enable_notifications", &is_boolean/1, "must be a boolean"},
        {"enable_real_time_collaboration", &is_boolean/1, "must be a boolean"},
        {"git_auto_push", &is_boolean/1, "must be a boolean"},
        {"backup_enabled", &is_boolean/1, "must be a boolean"},
        {"backup_frequency", &is_binary/1, "must be a string"}
      ]

      Enum.reduce_while(type_validations, :ok, fn {key, validator, error_msg}, _acc ->
        case Map.get(settings, key) do
          # Optional setting
          nil ->
            {:cont, :ok}

          value ->
            if validator.(value) do
              {:cont, :ok}
            else
              {:halt, {:error, field: :settings, message: "Setting '#{key}' #{error_msg}"}}
            end
        end
      end)
    end

    defp validate_setting_values(settings) do
      with :ok <- validate_max_file_size(settings),
           :ok <- validate_allowed_file_types(settings),
           :ok <- validate_backup_frequency(settings) do
        :ok
      end
    end

    defp validate_max_file_size(settings) do
      case Map.get(settings, "max_file_size") do
        nil ->
          :ok

        # Max 1GB
        size when is_integer(size) and size > 0 and size <= 1_073_741_824 ->
          :ok

        size when is_integer(size) and size <= 0 ->
          {:error, field: :settings, message: "max_file_size must be greater than 0"}

        size when is_integer(size) and size > 1_073_741_824 ->
          {:error, field: :settings, message: "max_file_size cannot exceed 1GB"}

        _ ->
          {:error, field: :settings, message: "max_file_size must be a positive integer"}
      end
    end

    defp validate_allowed_file_types(settings) do
      case Map.get(settings, "allowed_file_types") do
        nil ->
          :ok

        types when is_list(types) ->
          if Enum.all?(types, &is_binary/1) do
            :ok
          else
            {:error, field: :settings, message: "allowed_file_types must contain only strings"}
          end

        _ ->
          {:error, field: :settings, message: "allowed_file_types must be a list of strings"}
      end
    end

    defp validate_backup_frequency(settings) do
      case Map.get(settings, "backup_frequency") do
        nil ->
          :ok

        freq when freq in ["hourly", "daily", "weekly", "monthly"] ->
          :ok

        freq when is_binary(freq) ->
          {:error,
           field: :settings,
           message: "backup_frequency must be one of: hourly, daily, weekly, monthly"}

        _ ->
          {:error, field: :settings, message: "backup_frequency must be a string"}
      end
    end
  end

  defmodule UniqueNamePerTeam do
    @moduledoc """
    Validates that workspace names are unique within a team.
    """
    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def validate(changeset, _opts, _context) do
      name = Ash.Changeset.get_attribute(changeset, :name)
      team_id = Ash.Changeset.get_attribute(changeset, :team_id)
      workspace_id = changeset.data.id

      if name && team_id do
        case check_name_uniqueness(name, team_id, workspace_id) do
          true ->
            :ok

          false ->
            {:error,
             field: :name, message: "A workspace with this name already exists in your team"}
        end
      else
        :ok
      end
    end

    @impl true
    def atomic(changeset, _opts, _context) do
      name = Ash.Changeset.get_attribute(changeset, :name)
      team_id = Ash.Changeset.get_attribute(changeset, :team_id)
      workspace_id = changeset.data.id

      if name && team_id do
        condition =
          if workspace_id do
            # Update case - exclude current workspace
            Ash.Expr.expr(name == ^name and team_id == ^team_id and id != ^workspace_id)
          else
            # Create case
            Ash.Expr.expr(name == ^name and team_id == ^team_id)
          end

        error_expr =
          Ash.Expr.expr(
            error(Ash.Error.Changes.InvalidAttribute, %{
              field: :name,
              message: "A workspace with this name already exists in your team"
            })
          )

        {:atomic, [:name, :team_id], condition, error_expr}
      else
        {:not_atomic, "Missing name or team_id for uniqueness validation"}
      end
    end

    defp check_name_uniqueness(name, team_id, workspace_id) do
      query =
        Dirup.Workspaces.Workspace
        |> Ash.Query.filter(name == ^name and team_id == ^team_id)

      query =
        if workspace_id do
          Ash.Query.filter(query, id != ^workspace_id)
        else
          query
        end

      case Dirup.Workspaces.read_one(query) do
        {:ok, nil} -> true
        {:ok, _workspace} -> false
        # Assume unique if we can't check
        {:error, _} -> true
      end
    end
  end

  defmodule ValidateWorkspaceAccess do
    @moduledoc """
    Validates that the actor has appropriate access to create/modify workspaces.
    """
    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def validate(changeset, _opts, context) do
      team_id = Ash.Changeset.get_attribute(changeset, :team_id)
      actor = context.actor

      if team_id && actor do
        case check_team_membership(actor, team_id) do
          true ->
            :ok

          false ->
            {:error,
             field: :team_id,
             message: "You don't have permission to create workspaces in this team"}
        end
      else
        {:error, field: :team_id, message: "Team ID is required and user must be authenticated"}
      end
    end

    defp check_team_membership(actor, team_id) do
      case Dirup.Workspaces.is_member?(actor.id, team_id) do
        {:ok, true} -> true
        _ -> false
      end
    rescue
      _ -> false
    end
  end

  defmodule ValidateStorageQuota do
    @moduledoc """
    Validates that the workspace doesn't exceed storage quotas.
    """
    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def validate(changeset, _opts, _context) do
      team_id = Ash.Changeset.get_attribute(changeset, :team_id)
      settings = Ash.Changeset.get_attribute(changeset, :settings) || %{}

      if team_id do
        # 1GB default
        max_workspace_size = Map.get(settings, "max_workspace_size", 1_073_741_824)

        case check_team_storage_quota(team_id, max_workspace_size) do
          :ok -> :ok
          {:error, message} -> {:error, field: :settings, message: message}
        end
      else
        :ok
      end
    end

    defp check_team_storage_quota(team_id, additional_size) do
      # Get current team storage usage
      current_usage = get_team_storage_usage(team_id)
      team_limit = get_team_storage_limit(team_id)

      if current_usage + additional_size > team_limit do
        {:error, "Adding this workspace would exceed your team's storage limit"}
      else
        :ok
      end
    end

    defp get_team_storage_usage(team_id) do
      # Sum up all workspace sizes for the team
      Dirup.Workspaces.Workspace
      |> Ash.Query.filter(team_id == ^team_id)
      |> Ash.Query.filter(status != :deleted)
      |> Ash.Query.load(:total_size)
      |> Dirup.Workspaces.read!()
      |> Enum.reduce(0, fn workspace, acc ->
        acc + (Map.get(workspace, :total_size) || 0)
      end)
    rescue
      _ -> 0
    end

    defp get_team_storage_limit(_team_id) do
      # This would typically come from team settings or subscription plan
      # For now, return a default limit of 10GB per team
      # 10GB
      10_737_418_240
    end
  end

  defmodule ValidateWorkspaceName do
    @moduledoc """
    Validates workspace name format and reserved names.
    """
    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      {:ok, opts}
    end

    @impl true
    def validate(changeset, _opts, _context) do
      case Ash.Changeset.get_attribute(changeset, :name) do
        nil -> :ok
        name -> validate_name_format(name)
      end
    end

    defp validate_name_format(name) do
      with :ok <- validate_length(name),
           :ok <- validate_characters(name),
           :ok <- validate_reserved_names(name) do
        :ok
      end
    end

    defp validate_length(name) do
      length = String.length(name)

      cond do
        length < 1 -> {:error, field: :name, message: "Name cannot be empty"}
        length > 100 -> {:error, field: :name, message: "Name cannot exceed 100 characters"}
        true -> :ok
      end
    end

    defp validate_characters(name) do
      if Regex.match?(~r/^[a-zA-Z0-9\-_\s]+$/, name) do
        :ok
      else
        {:error,
         field: :name,
         message: "Name can only contain letters, numbers, spaces, hyphens, and underscores"}
      end
    end

    defp validate_reserved_names(name) do
      reserved_names = [
        "admin",
        "api",
        "www",
        "mail",
        "ftp",
        "localhost",
        "root",
        "system",
        "null",
        "undefined",
        "default",
        "config",
        ".git",
        "node_modules",
        "tmp",
        "temp",
        "cache",
        "log",
        "logs"
      ]

      normalized_name = String.downcase(String.trim(name))

      if normalized_name in reserved_names do
        {:error, field: :name, message: "This name is reserved and cannot be used"}
      else
        :ok
      end
    end
  end
end
