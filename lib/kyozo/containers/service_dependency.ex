defmodule Kyozo.Containers.ServiceDependency do
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Containers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  @moduledoc """
  ServiceDependency resource representing relationships between service instances.

  This resource models service dependencies, enabling proper orchestration
  of containerized services by tracking which services depend on others,
  their startup order, and connection configurations.
  """

  json_api do
    type "service-dependency"

    routes do
      base "/service-dependencies"
      get :read
      index :read
      post :create
      delete :destroy
    end

    includes [:dependent_service, :required_service]
  end

  postgres do
    table "container_service_dependencies"
    repo Kyozo.Repo

    references do
      reference :dependent_service, on_delete: :delete, index?: true
      reference :required_service, on_delete: :delete, index?: true
    end

    custom_indexes do
      index [:dependent_service_id, :required_service_id], unique: true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :dependent_service_id,
        :required_service_id,
        :dependency_type,
        :connection_string,
        :environment_variable,
        :startup_order
      ]

      change {Kyozo.Containers.Changes.ValidateNoCyclicDependencies, []}
    end

    read :for_dependent_service do
      argument :service_instance_id, :uuid, allow_nil?: false
      filter expr(dependent_service_id == ^arg(:service_instance_id))
      prepare build(sort: [startup_order: :asc])
    end

    read :for_required_service do
      argument :service_instance_id, :uuid, allow_nil?: false
      filter expr(required_service_id == ^arg(:service_instance_id))
      prepare build(sort: [startup_order: :asc])
    end

    read :startup_order do
      prepare build(sort: [startup_order: :asc, created_at: :asc])
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via([:dependent_service, :workspace, :team, :users])
    end

    policy action_type([:create, :destroy]) do
      authorize_if relates_to_actor_via([:dependent_service, :workspace, :team, :users])
    end
  end

  validations do
    validate present([:dependent_service_id, :required_service_id])

    validate {Kyozo.Containers.Validations.ValidateNoDependencyLoop, []}
    validate {Kyozo.Containers.Validations.ValidateEnvironmentVariable, []}
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :dependency_type, :atom do
      constraints one_of: [:requires, :optional, :conflicts]
      default :requires
      public? true
    end

    attribute :connection_string, :string do
      public? true
      description "Connection string or service discovery URL"
    end

    attribute :environment_variable, :string do
      public? true
      description "Environment variable to inject"
    end

    attribute :startup_order, :integer do
      default 0
      public? true
    end

    create_timestamp :created_at
  end

  relationships do
    belongs_to :dependent_service, Kyozo.Containers.ServiceInstance do
      allow_nil? false
      public? true
    end

    belongs_to :required_service, Kyozo.Containers.ServiceInstance do
      allow_nil? false
      public? true
    end
  end

  calculations do
    calculate :dependency_path,
              :string,
              {Kyozo.Containers.Calculations.DependencyPath, []}

    calculate :is_circular,
              :boolean,
              {Kyozo.Containers.Calculations.CircularDependency, []}

    calculate :depth_level, :integer, {Kyozo.Containers.Calculations.DependencyDepth, []}
  end
end
