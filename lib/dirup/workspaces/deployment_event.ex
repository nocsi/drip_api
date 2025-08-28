defmodule Dirup.Workspaces.DeploymentEvent do
  @derive {Jason.Encoder,
           only: [
             :id,
             :event_type,
             :event_data,
             :duration_ms,
             :sequence_number,
             :occurred_at,
             :status,
             :error_details,
             :created_at
           ]}

  @moduledoc """
  DeploymentEvent resource representing events that occur during service deployment,
  scaling, starting, stopping, and other operational activities.

  This resource provides an audit trail of all deployment activities and their outcomes,
  enabling debugging, monitoring, and analysis of deployment patterns.
  """

  use Ash.Resource,
    otp_app: :dirup,
    domain: Dirup.Workspaces,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  # GraphQL configuration removed during GraphQL cleanup

  json_api do
    type "deployment-event"

    routes do
      base "/deployment-events"
      get :read
      index :read
      post :create
    end

    # JSON-LD context metadata temporarily disabled during GraphQL cleanup
    # TODO: Re-enable JSON-LD metadata when AshJsonApi meta function is available
  end

  postgres do
    table "deployment_events"
    repo Dirup.Repo

    references do
      reference :service_instance, on_delete: :delete, index?: true
      reference :workspace, on_delete: :delete, index?: true
      reference :team, on_delete: :delete, index?: true
      reference :triggered_by, on_delete: :nilify, index?: true
    end

    custom_indexes do
      index [:service_instance_id, :occurred_at]
      index [:workspace_id, :occurred_at]
      index [:team_id, :occurred_at]
      index [:event_type, :occurred_at]
      index [:status, :occurred_at]
      index [:sequence_number, :service_instance_id], unique: true
    end
  end

  actions do
    default_accept [:event_type, :event_data, :duration_ms, :occurred_at]
    defaults [:create, :read]

    read :list_deployment_events do
      prepare build(
                load: [:service_instance, :workspace, :team, :triggered_by],
                sort: [occurred_at: :desc]
              )
    end

    read :list_by_service do
      argument :service_instance_id, :uuid, allow_nil?: false

      prepare build(
                filter: [service_instance_id: arg(:service_instance_id)],
                load: [:service_instance, :triggered_by],
                sort: [sequence_number: :desc]
              )
    end

    read :list_by_workspace do
      argument :workspace_id, :uuid, allow_nil?: false

      prepare build(
                filter: [workspace_id: arg(:workspace_id)],
                load: [:service_instance, :triggered_by],
                sort: [occurred_at: :desc]
              )
    end

    read :list_recent_events do
      argument :hours, :integer, default: 24

      prepare build(
                filter: expr(occurred_at >= ago(^arg(:hours), :hour)),
                load: [:service_instance, :workspace, :triggered_by],
                sort: [occurred_at: :desc]
              )
    end

    read :list_by_event_type do
      argument :event_type, :string, allow_nil?: false

      prepare build(
                filter: [event_type: arg(:event_type)],
                load: [:service_instance, :workspace, :triggered_by],
                sort: [occurred_at: :desc]
              )
    end

    read :deployment_timeline do
      argument :service_instance_id, :uuid, allow_nil?: false
      argument :limit, :integer, default: 50

      prepare build(
                filter: [service_instance_id: arg(:service_instance_id)],
                load: [:service_instance, :triggered_by],
                sort: [sequence_number: :asc],
                limit: arg(:limit)
              )
    end

    create :create_deployment_event do
      accept [
        :event_type,
        :event_data,
        :duration_ms,
        :occurred_at,
        :status,
        :error_details,
        :service_instance_id,
        :triggered_by_id
      ]

      change {Dirup.Workspaces.DeploymentEvent.Changes.SetWorkspaceAndTeam, []}
      change {Dirup.Workspaces.DeploymentEvent.Changes.AssignSequenceNumber, []}
      change {Dirup.Workspaces.DeploymentEvent.Changes.NormalizeEventData, []}

      after_action({Dirup.Workspaces.DeploymentEvent.Changes.UpdateServiceStatus, []})
      after_action({Dirup.Workspaces.DeploymentEvent.Changes.EmitEventNotification, []})
    end

    action :create_deployment_started, :struct do
      argument :service_instance_id, :uuid, allow_nil?: false
      argument :triggered_by_id, :uuid, allow_nil?: true
      argument :deployment_config, :map, default: %{}

      run {Dirup.Workspaces.DeploymentEvent.Actions.CreateDeploymentStarted, []}
    end

    action :create_deployment_completed, :struct do
      argument :service_instance_id, :uuid, allow_nil?: false
      argument :container_id, :string, allow_nil?: false
      argument :image_id, :string, allow_nil?: false
      argument :duration_ms, :integer, allow_nil?: false

      run {Dirup.Workspaces.DeploymentEvent.Actions.CreateDeploymentCompleted, []}
    end

    action :create_deployment_failed, :struct do
      argument :service_instance_id, :uuid, allow_nil?: false
      argument :error_message, :string, allow_nil?: false
      argument :error_details, :map, default: %{}
      argument :duration_ms, :integer, allow_nil?: true

      run {Dirup.Workspaces.DeploymentEvent.Actions.CreateDeploymentFailed, []}
    end

    action :create_service_scaled, :struct do
      argument :service_instance_id, :uuid, allow_nil?: false
      argument :old_replica_count, :integer, allow_nil?: false
      argument :new_replica_count, :integer, allow_nil?: false
      argument :triggered_by_id, :uuid, allow_nil?: true

      run {Dirup.Workspaces.DeploymentEvent.Actions.CreateServiceScaled, []}
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])
    end

    policy action_type(:create) do
      authorize_if actor_present()
      # Allow system-level event creation for deployment processes
      authorize_if expr(is_nil(^actor(:id)))
    end

    policy action([
             :create_deployment_started,
             :create_deployment_completed,
             :create_deployment_failed,
             :create_service_scaled
           ]) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])

      authorize_if expr(
                     exists(
                       workspace.team.users,
                       id == ^actor(:id) and team_members.role in ["admin", "owner", "developer"]
                     )
                   )
    end
  end

  pub_sub do
    module DirupWeb.Endpoint

    publish_all :create, ["deployment_events", :service_instance_id]
    publish_all :create, ["deployment_events", :workspace_id]
  end

  preparations do
    prepare build(load: [:service_instance, :workspace, :team])
  end

  changes do
    change before_action({Dirup.Workspaces.DeploymentEvent.Changes.SetDefaultOccurredAt, []}),
      on: [:create]

    change after_action({Dirup.Workspaces.DeploymentEvent.Changes.UpdateEventMetrics, []}),
      on: [:create]
  end

  validations do
    validate present([
               :event_type,
               :service_instance_id,
               :workspace_id,
               :team_id,
               :occurred_at,
               :sequence_number
             ])

    validate {Dirup.Workspaces.DeploymentEvent.Validations.ValidateEventData, []}
    validate {Dirup.Workspaces.DeploymentEvent.Validations.ValidateSequenceNumber, []}
  end

  multitenancy do
    strategy :attribute
    attribute :team_id
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :event_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :deployment_started,
                    :deployment_completed,
                    :deployment_failed,
                    :build_started,
                    :build_completed,
                    :build_failed,
                    :container_started,
                    :container_stopped,
                    :container_crashed,
                    :service_scaled,
                    :health_check_failed,
                    :health_check_recovered,
                    :configuration_updated
                  ]
    end

    attribute :event_data, :map do
      public? true
      default %{}
      # Contains event-specific data like container_id, image_id, error details, etc.
    end

    attribute :duration_ms, :integer do
      public? true
      constraints min: 0
      # Duration of the operation that triggered this event
    end

    attribute :sequence_number, :integer do
      allow_nil? false
      public? true
      # Sequential number per service instance for chronological ordering
    end

    attribute :occurred_at, :utc_datetime_usec do
      allow_nil? false
      public? true
      default &DateTime.utc_now/0
    end

    attribute :status, :atom do
      public? true
      constraints one_of: [:success, :failure, :in_progress, :cancelled]
      default :success
    end

    attribute :error_details, :map do
      public? true
      default %{}
      # Detailed error information for failed events
    end

    create_timestamp :created_at
  end

  relationships do
    belongs_to :service_instance, Dirup.Workspaces.ServiceInstance do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :workspace, Dirup.Workspaces.Workspace do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :team, Dirup.Accounts.Team do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :triggered_by, Dirup.Accounts.User do
      allow_nil? true
      attribute_writable? true
    end
  end

  calculations do
    calculate :is_failure, :boolean do
      calculation fn events, _context ->
        Enum.map(events, fn event ->
          event.status == :failure or String.contains?(event.event_type, "failed")
        end)
      end
    end

    calculate :is_deployment_event, :boolean do
      calculation fn events, _context ->
        Enum.map(events, fn event ->
          String.starts_with?(event.event_type, "deployment_")
        end)
      end
    end

    calculate :formatted_duration, :string do
      load [:duration_ms]

      calculation fn events, _context ->
        Enum.map(events, fn event ->
          case event.duration_ms do
            nil -> "N/A"
            ms when ms < 1000 -> "#{ms}ms"
            ms when ms < 60_000 -> "#{Float.round(ms / 1000, 1)}s"
            ms -> "#{Float.round(ms / 60_000, 1)}m"
          end
        end)
      end
    end

    calculate :event_category, :string do
      calculation fn events, _context ->
        Enum.map(events, fn event ->
          case event.event_type do
            "deployment_" <> _ -> "deployment"
            "build_" <> _ -> "build"
            "container_" <> _ -> "container"
            "health_check_" <> _ -> "health"
            _ -> "other"
          end
        end)
      end
    end

    calculate :time_since_event, :string do
      calculation fn events, _context ->
        now = DateTime.utc_now()

        Enum.map(events, fn event ->
          diff_seconds = DateTime.diff(now, event.occurred_at)

          cond do
            diff_seconds < 60 -> "#{diff_seconds}s ago"
            diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
            diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
            true -> "#{div(diff_seconds, 86400)}d ago"
          end
        end)
      end
    end
  end

  # Resource-specific functions

  @doc """
  Determines if the event represents a successful operation.
  """
  def successful?(%{status: :success}), do: true

  def successful?(%{event_type: event_type}) do
    String.contains?(event_type, "completed") or String.contains?(event_type, "started")
  end

  def successful?(_), do: false

  @doc """
  Determines if the event represents a failed operation.
  """
  def failed?(%{status: :failure}), do: true

  def failed?(%{event_type: event_type}) do
    String.contains?(event_type, "failed") or String.contains?(event_type, "crashed")
  end

  def failed?(_), do: false

  @doc """
  Gets the primary error message from event details.
  """
  def primary_error_message(%{error_details: error_details}) when map_size(error_details) > 0 do
    Map.get(error_details, "message") ||
      Map.get(error_details, "error") ||
      Map.get(error_details, "reason") ||
      "Unknown error"
  end

  def primary_error_message(%{event_data: event_data}) do
    Map.get(event_data, "error_message") || "Unknown error"
  end

  def primary_error_message(_), do: nil

  @doc """
  Formats the event duration in a human-readable format.
  """
  def format_duration(nil), do: "N/A"
  def format_duration(ms) when ms < 1000, do: "#{ms}ms"
  def format_duration(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"
  def format_duration(ms), do: "#{Float.round(ms / 60_000, 1)}m"

  @doc """
  Gets the event severity level for alerting and monitoring.
  """
  def severity_level(%{status: :failure}), do: :error
  def severity_level(%{event_type: "deployment_failed"}), do: :error
  def severity_level(%{event_type: "build_failed"}), do: :error
  def severity_level(%{event_type: "container_crashed"}), do: :error
  def severity_level(%{event_type: "health_check_failed"}), do: :warning

  def severity_level(%{event_type: event_type})
      when event_type in [
             "deployment_started",
             "build_started",
             "container_started"
           ],
      do: :info

  def severity_level(%{event_type: event_type})
      when event_type in [
             "deployment_completed",
             "build_completed",
             "service_scaled"
           ],
      do: :success

  def severity_level(_), do: :info

  @doc """
  Creates a deployment event with proper formatting and validation.
  """
  def create_event(event_type, service_instance_id, event_data \\ %{}, opts \\ []) do
    base_attrs = %{
      event_type: event_type,
      service_instance_id: service_instance_id,
      event_data: event_data,
      occurred_at: DateTime.utc_now(),
      status: Keyword.get(opts, :status, :success)
    }

    # Add optional attributes
    attrs =
      base_attrs
      |> maybe_add_duration(Keyword.get(opts, :duration_ms))
      |> maybe_add_triggered_by(Keyword.get(opts, :triggered_by_id))
      |> maybe_add_error_details(Keyword.get(opts, :error_details))

    __MODULE__
    |> Ash.Changeset.for_create(:create, attrs)
    |> Dirup.Workspaces.create()
  end

  @doc """
  Gets deployment events grouped by type for analytics.
  """
  def group_by_type(events) do
    events
    |> Enum.group_by(fn event -> event.event_type end)
    |> Enum.map(fn {type, type_events} ->
      {type,
       %{
         count: length(type_events),
         success_count: Enum.count(type_events, &successful?/1),
         failure_count: Enum.count(type_events, &failed?/1),
         avg_duration: calculate_average_duration(type_events)
       }}
    end)
    |> Map.new()
  end

  @doc """
  Gets deployment statistics for a service or workspace.
  """
  def deployment_stats(events) do
    total_events = length(events)
    success_events = Enum.count(events, &successful?/1)
    failure_events = Enum.count(events, &failed?/1)

    %{
      total_events: total_events,
      success_count: success_events,
      failure_count: failure_events,
      success_rate: if(total_events > 0, do: success_events / total_events, else: 0.0),
      recent_events: Enum.take(events, 10),
      event_types: group_by_type(events)
    }
  end

  # Private helper functions

  defp maybe_add_duration(attrs, nil), do: attrs
  defp maybe_add_duration(attrs, duration_ms), do: Map.put(attrs, :duration_ms, duration_ms)

  defp maybe_add_triggered_by(attrs, nil), do: attrs

  defp maybe_add_triggered_by(attrs, triggered_by_id),
    do: Map.put(attrs, :triggered_by_id, triggered_by_id)

  defp maybe_add_error_details(attrs, nil), do: attrs

  defp maybe_add_error_details(attrs, error_details),
    do: Map.put(attrs, :error_details, error_details)

  defp calculate_average_duration(events) do
    durations = events |> Enum.map(& &1.duration_ms) |> Enum.reject(&is_nil/1)

    case durations do
      [] -> nil
      list -> Enum.sum(list) / length(list)
    end
  end
end
