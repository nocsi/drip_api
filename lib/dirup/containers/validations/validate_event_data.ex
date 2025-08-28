defmodule Dirup.Containers.Validations.ValidateEventData do
  @moduledoc """
  Validates event data for deployment events.

  This validation ensures that event data contains appropriate fields
  for the specific event type and that all data is properly formatted
  and within expected bounds.
  """

  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts) do
    event_type = Ash.Changeset.get_attribute(changeset, :event_type)
    event_data = Ash.Changeset.get_attribute(changeset, :event_data)

    case validate_event_data_for_type(event_type, event_data) do
      :ok -> :ok
      {:error, message} -> {:error, field: :event_data, message: message}
    end
  end

  defp validate_event_data_for_type(nil, _event_data), do: :ok

  defp validate_event_data_for_type(event_type, event_data) when is_map(event_data) do
    case event_type do
      :deployment_started ->
        validate_deployment_started_data(event_data)

      :deployment_completed ->
        validate_deployment_completed_data(event_data)

      :deployment_failed ->
        validate_deployment_failed_data(event_data)

      :service_started ->
        validate_service_started_data(event_data)

      :service_stopped ->
        validate_service_stopped_data(event_data)

      :service_scaled ->
        validate_service_scaled_data(event_data)

      :health_check_passed ->
        validate_health_check_data(event_data)

      :health_check_failed ->
        validate_health_check_data(event_data)

      :configuration_updated ->
        validate_configuration_updated_data(event_data)

      :image_built ->
        validate_image_built_data(event_data)

      :image_pushed ->
        validate_image_pushed_data(event_data)

      _ ->
        # For unknown event types, accept any data
        :ok
    end
  end

  defp validate_event_data_for_type(_event_type, nil), do: :ok

  defp validate_event_data_for_type(_event_type, _event_data) do
    {:error, "event_data must be a map"}
  end

  defp validate_deployment_started_data(event_data) do
    required_fields = ["started_at"]
    optional_fields = ["deployment_config", "image_tag", "container_config"]

    validate_fields(event_data, required_fields, optional_fields)
  end

  defp validate_deployment_completed_data(event_data) do
    required_fields = ["completed_at"]
    optional_fields = ["container_id", "image_id", "startup_time_ms", "ports"]

    validate_fields(event_data, required_fields, optional_fields)
  end

  defp validate_deployment_failed_data(event_data) do
    required_fields = ["failed_at"]
    optional_fields = ["error", "error_code", "logs", "retry_count"]

    validate_fields(event_data, required_fields, optional_fields)
  end

  defp validate_service_started_data(event_data) do
    required_fields = ["started_at"]
    optional_fields = ["container_id", "pid", "ports", "startup_time_ms"]

    validate_fields(event_data, required_fields, optional_fields)
  end

  defp validate_service_stopped_data(event_data) do
    required_fields = ["stopped_at"]
    optional_fields = ["reason", "exit_code", "container_id", "graceful_shutdown"]

    validate_fields(event_data, required_fields, optional_fields)
  end

  defp validate_service_scaled_data(event_data) do
    optional_fields = [
      "started_at",
      "completed_at",
      "failed_at",
      "current_replicas",
      "target_replicas",
      "scaling_strategy",
      "error"
    ]

    validate_fields(event_data, [], optional_fields)
  end

  defp validate_health_check_data(event_data) do
    required_fields = ["checked_at"]
    optional_fields = ["status", "response_time_ms", "status_code", "endpoint", "error"]

    validate_fields(event_data, required_fields, optional_fields)
  end

  defp validate_configuration_updated_data(event_data) do
    required_fields = ["updated_at"]
    optional_fields = ["changed_fields", "old_values", "new_values", "updated_by"]

    validate_fields(event_data, required_fields, optional_fields)
  end

  defp validate_image_built_data(event_data) do
    required_fields = ["built_at"]
    optional_fields = ["image_id", "image_tag", "build_time_ms", "dockerfile_path", "build_args"]

    validate_fields(event_data, required_fields, optional_fields)
  end

  defp validate_image_pushed_data(event_data) do
    required_fields = ["pushed_at"]
    optional_fields = ["registry_url", "image_tag", "image_id", "push_time_ms"]

    validate_fields(event_data, required_fields, optional_fields)
  end

  defp validate_fields(event_data, required_fields, optional_fields) do
    # Convert map keys to strings for comparison
    data_keys = event_data |> Map.keys() |> Enum.map(&to_string/1) |> MapSet.new()
    required_set = MapSet.new(required_fields)
    allowed_set = MapSet.union(required_set, MapSet.new(optional_fields))

    # Check for missing required fields
    missing_required = MapSet.difference(required_set, data_keys)

    # Check for invalid fields
    invalid_fields = MapSet.difference(data_keys, allowed_set)

    errors = []

    errors =
      if MapSet.size(missing_required) > 0 do
        missing_list = MapSet.to_list(missing_required) |> Enum.join(", ")
        ["Missing required fields: #{missing_list}" | errors]
      else
        errors
      end

    errors =
      if MapSet.size(invalid_fields) > 0 do
        invalid_list = MapSet.to_list(invalid_fields) |> Enum.join(", ")
        ["Invalid fields: #{invalid_list}" | errors]
      else
        errors
      end

    case errors do
      [] -> :ok
      _ -> {:error, Enum.join(errors, "; ")}
    end
  end

  @impl true
  def describe(_opts) do
    [
      message: "must have valid event data for the event type",
      vars: []
    ]
  end
end
