defmodule Kyozo.Containers.Changes.ValidateDeploymentConfig do
  @moduledoc """
  Validates deployment configuration for service instances.

  This change ensures that deployment configurations contain valid settings
  for the specified service type and deployment strategy.
  """

  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :deployment_config) do
      nil ->
        changeset

      config ->
        service_type = Ash.Changeset.get_attribute(changeset, :service_type)
        validate_config(changeset, config, service_type)
    end
  end

  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end

  defp validate_config(changeset, config, service_type) when is_map(config) do
    case validate_config_for_service_type(config, service_type) do
      {:ok, validated_config} ->
        Ash.Changeset.change_attribute(changeset, :deployment_config, validated_config)

      {:error, errors} ->
        Ash.Changeset.add_error(changeset,
          field: :deployment_config,
          message: format_errors(errors)
        )
    end
  end

  defp validate_config(changeset, _config, _service_type) do
    Ash.Changeset.add_error(changeset,
      field: :deployment_config,
      message: "deployment_config must be a map"
    )
  end

  defp validate_config_for_service_type(config, :nodejs) do
    required_keys = []

    optional_keys = [
      :build_command,
      :start_command,
      :node_version,
      :package_manager,
      :environment
    ]

    validate_config_keys(config, required_keys, optional_keys)
  end

  defp validate_config_for_service_type(config, :python) do
    required_keys = []
    optional_keys = [:python_version, :framework, :wsgi_app, :requirements_file, :environment]
    validate_config_keys(config, required_keys, optional_keys)
  end

  defp validate_config_for_service_type(config, :containerized) do
    required_keys = []
    optional_keys = [:dockerfile_path, :build_args, :multi_stage]
    validate_config_keys(config, required_keys, optional_keys)
  end

  defp validate_config_for_service_type(config, :compose_stack) do
    required_keys = []
    optional_keys = [:compose_file, :services, :networks, :volumes]
    validate_config_keys(config, required_keys, optional_keys)
  end

  defp validate_config_for_service_type(config, _service_type) do
    # For other service types, accept any configuration for now
    {:ok, config}
  end

  defp validate_config_keys(config, required_keys, optional_keys) do
    config_keys = Map.keys(config) |> Enum.map(&to_string/1) |> MapSet.new()
    required_set = MapSet.new(Enum.map(required_keys, &to_string/1))
    allowed_set = MapSet.union(required_set, MapSet.new(Enum.map(optional_keys, &to_string/1)))

    missing_required = MapSet.difference(required_set, config_keys)
    invalid_keys = MapSet.difference(config_keys, allowed_set)

    errors = []

    errors =
      if MapSet.size(missing_required) > 0 do
        ["Missing required keys: #{MapSet.to_list(missing_required) |> Enum.join(", ")}" | errors]
      else
        errors
      end

    errors =
      if MapSet.size(invalid_keys) > 0 do
        ["Invalid keys: #{MapSet.to_list(invalid_keys) |> Enum.join(", ")}" | errors]
      else
        errors
      end

    case errors do
      [] -> {:ok, config}
      _ -> {:error, errors}
    end
  end

  defp format_errors(errors) do
    Enum.join(errors, "; ")
  end
end
