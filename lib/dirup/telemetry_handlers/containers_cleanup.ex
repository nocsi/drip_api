defmodule Dirup.TelemetryHandlers.ContainersCleanup do
  @moduledoc """
  Telemetry handler for containers cleanup events.

  Attaches to events emitted by CleanupWorker and logs structured summaries.
  You can extend `forward/2` to send to an external metrics backend if desired.
  """

  require Logger

  @events [
    [:dirup, :containers, :cleanup, :metrics],
    [:dirup, :containers, :cleanup, :deployment_events],
    [:dirup, :containers, :cleanup, :health_checks],
    [:dirup, :containers, :cleanup, :orphaned_containers],
    [:dirup, :containers, :cleanup, :stopped_services],
    [:dirup, :containers, :cleanup, :docker_images],
    [:dirup, :containers, :cleanup, :vacuum]
  ]

  def attach do
    for event <- @events do
      :telemetry.attach(
        handler_id(event),
        event,
        &__MODULE__.handle_event/4,
        :ok
      )
    end

    :ok
  end

  def detach do
    Enum.each(@events, fn event ->
      :telemetry.detach(handler_id(event))
    end)
  end

  def handle_event(
        [:dirup, :containers, :cleanup, :metrics] = _event,
        %{deleted: deleted},
        meta,
        _cfg
      ) do
    forward(:metrics, %{deleted: deleted}, meta)
  end

  def handle_event(
        [:dirup, :containers, :cleanup, :deployment_events],
        %{deleted: deleted},
        meta,
        _cfg
      ) do
    forward(:deployment_events, %{deleted: deleted}, meta)
  end

  def handle_event(
        [:dirup, :containers, :cleanup, :health_checks],
        %{deleted: deleted},
        meta,
        _cfg
      ) do
    forward(:health_checks, %{deleted: deleted}, meta)
  end

  def handle_event(
        [:dirup, :containers, :cleanup, :orphaned_containers],
        measurements,
        meta,
        _cfg
      ) do
    forward(:orphaned_containers, measurements, meta)
  end

  def handle_event([:dirup, :containers, :cleanup, :stopped_services], measurements, meta, _cfg) do
    forward(:stopped_services, measurements, meta)
  end

  def handle_event([:dirup, :containers, :cleanup, :docker_images], measurements, meta, _cfg) do
    forward(:docker_images, measurements, meta)
  end

  def handle_event(
        [:dirup, :containers, :cleanup, :vacuum],
        %{duration_ms: duration_ms},
        %{table: table},
        _cfg
      ) do
    forward(:vacuum, %{duration_ms: duration_ms}, %{table: table})
  end

  defp forward(kind, measurements, metadata) do
    # Log to console. Extend here to forward to external metrics backends.
    level = log_level()

    Logger.log(level, "cleanup_#{to_string(kind)}",
      measurements: measurements,
      metadata: metadata
    )
  end

  defp handler_id(event), do: {__MODULE__, event}

  defp log_level do
    case System.get_env("KYOZO_TELEMETRY_LOG_LEVEL") do
      "debug" -> :debug
      "info" -> :info
      "warn" -> :warn
      "error" -> :error
      _ -> :info
    end
  end
end
