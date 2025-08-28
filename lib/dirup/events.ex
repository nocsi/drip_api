defmodule Dirup.Events do
  use Ash.Domain,
    otp_app: :dirup

  require Logger

  resources do
    resource Dirup.Events.Event
  end

  @doc """
  Emit an event to subscribers and optionally store it.
  """
  def emit(event_type, data \\ %{}) do
    Logger.debug("Emitting event", type: event_type, data: inspect(data))

    # Broadcast to Phoenix PubSub if available
    try do
      Phoenix.PubSub.broadcast(Dirup.PubSub, "events:#{event_type}", {event_type, data})
    rescue
      _ -> :ok
    end

    # Store event if needed (optional)
    case create_event(event_type, data) do
      {:ok, event} ->
        Logger.debug("Event stored", event_id: event.id)
        {:ok, event}

      {:error, reason} ->
        Logger.warn("Failed to store event", type: event_type, error: reason)
        {:error, reason}
    end
  end

  @doc """
  Create an event record.
  """
  def create_event(event_type, data) do
    try do
      Dirup.Events.Event
      |> Ash.Changeset.for_create(:create, %{
        event_type: to_string(event_type),
        data: data,
        occurred_at: DateTime.utc_now()
      })
      |> Ash.create()
    rescue
      exception ->
        Logger.warn("Event creation failed",
          type: event_type,
          error: Exception.message(exception)
        )

        {:error, :event_creation_failed}
    end
  end

  @doc """
  Subscribe to events of a specific type.
  """
  def subscribe(event_type) do
    Phoenix.PubSub.subscribe(Dirup.PubSub, "events:#{event_type}")
  end

  @doc """
  Unsubscribe from events of a specific type.
  """
  def unsubscribe(event_type) do
    Phoenix.PubSub.unsubscribe(Dirup.PubSub, "events:#{event_type}")
  end
end
