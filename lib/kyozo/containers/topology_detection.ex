defmodule Kyozo.Containers.TopologyDetection do
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Containers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshOban]

  @moduledoc """
  TopologyDetection resource representing folder analysis results.

  This resource stores the results of analyzing workspace folders to detect
  service patterns, dependencies, and deployment recommendations. It provides
  the intelligence behind the "Folder as a Service" functionality.
  """

  json_api do
    type "topology-detection"

    routes do
      base "/topology-detections"
      get :read
      index :read
      post :analyze_folder
      patch :reanalyze, route: "/:id/reanalyze"
      delete :destroy
    end

    includes [:workspace, :team, :triggered_by, :service_instances]
  end

  postgres do
    table "container_topology_detections"
    repo Kyozo.Repo

    references do
      reference :workspace, on_delete: :delete, index?: true
      reference :team, on_delete: :delete, index?: true
      reference :triggered_by, on_delete: :nilify, index?: true
    end

    custom_indexes do
      index [:team_id, :workspace_id]
      index [:workspace_id, :folder_path, :detection_timestamp]
    end
  end

  # AshOban trigger to analyze workspace topology in the background
  oban do
    triggers do
      # Ensure triggers run for all tenants
      list_tenants(fn -> Kyozo.Repo.all_tenants() end)

      trigger :analyze do
        action :analyze_folder
        queue(:topology_analysis)
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :analyze_folder do
      argument :workspace_id, :uuid, allow_nil?: false
      argument :folder_path, :string, allow_nil?: false

      change {Kyozo.Containers.Changes.AnalyzeTopology, []}
      change {Kyozo.Containers.Changes.SetTeamFromWorkspace, []}
      change relate_actor(:triggered_by)
    end

    update :reanalyze do
      change {Kyozo.Containers.Changes.AnalyzeTopology, []}
    end

    read :by_workspace do
      argument :workspace_id, :uuid, allow_nil?: false
      filter expr(workspace_id == ^arg(:workspace_id))
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if relates_to_actor_via([:workspace, :team, :users])
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :folder_path, :string do
      allow_nil? false
      public? true
    end

    attribute :detection_timestamp, :utc_datetime_usec do
      allow_nil? false
      public? true
      default &DateTime.utc_now/0
    end

    attribute :detected_patterns, :map do
      default %{}
      public? true
      description "Detected service patterns and indicators"
    end

    attribute :service_graph, :map do
      default %{}
      public? true
      description "Service dependency graph"
    end

    attribute :recommended_services, {:array, :map} do
      default []
      public? true
      description "List of recommended service configurations"
    end

    attribute :confidence_scores, :map do
      default %{}
      public? true
      description "Confidence scores for each detection"
    end

    attribute :file_indicators, {:array, :map} do
      default []
      public? true
      description "Files that indicated service types"
    end

    attribute :deployment_strategy, :atom do
      constraints one_of: [:single_service, :compose_stack, :kubernetes, :custom]
      public? true
    end

    attribute :total_services_detected, :integer do
      default 0
      public? true
    end

    attribute :analysis_metadata, :map do
      default %{}
      public? false
      description "Internal analysis metadata"
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :workspace, Kyozo.Workspaces.Workspace do
      allow_nil? false
      public? true
    end

    belongs_to :team, Kyozo.Accounts.Team do
      allow_nil? false
      public? true
    end

    belongs_to :triggered_by, Kyozo.Accounts.User do
      public? true
    end

    has_many :service_instances, Kyozo.Containers.ServiceInstance do
      public? true
    end
  end
end
