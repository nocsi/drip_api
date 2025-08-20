# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :kyozo, :env, config_env()

config :ash_oban, pro?: false

config :ash_oban, :actor_persister, Kyozo.Storage.ActorPersister

config :kyozo, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [
    default: 10,
    storage_processing: 5,
    storage_cleanup: 3,
    storage_versions: 2,
    storage_bulk: 4,
    # AshOban scheduled action queues
    storage_resource_process_unprocessed: 3,
    storage_resource_daily_cleanup: 2,
    storage_resource_version_creation: 2,
    storage_resource_weekly_health_check: 1
  ],
  repo: Kyozo.Repo,
  plugins: [{Oban.Plugins.Cron, []}]



config :mime,
  extensions: %{"json" => "application/vnd.api+json"},
  types: %{"application/vnd.api+json" => ["json"]}

config :ash_json_api,
  show_public_calculations_when_loaded?: false,
  authorize_update_destroy_with_error?: true

config :ash,
  allow_forbidden_field_for_relationships_by_default?: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true,
  compatible_foreign_key_types: [
    {Ash.Type.String, Ash.Type.UUIDv7}
  ]

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :authentication,
        :tokens,
        :graphql,
        :json_api,
        :postgres,
        :resource,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :multitenancy,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [
      section_order: [
        :graphql,
        :json_api,
        :resources,
        :policies,
        :authorization,
        :domain,
        :execution
      ]
    ]
  ]

config :kyozo,
  ecto_repos: [Kyozo.Repo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [Kyozo.Accounts, Kyozo.Workspaces, Kyozo.Projects, Kyozo.Storage]

# Configures the endpoint
config :kyozo, KyozoWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: KyozoWeb.ErrorHTML, json: KyozoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Kyozo.PubSub,
  live_view: [signing_salt: "2gskVQkA"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :kyozo, Kyozo.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
# config :esbuild,
#   version: "0.17.11",
#   kyozo: [
#     args:
#       ~w(js/app.ts --bundle --target=es2020 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
#     cd: Path.expand("../assets", __DIR__),
#     env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
#   ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.4",
  kyozo: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Blob storage configuration
config :kyozo,
  blob_storage_backend: :disk,  # :disk or :s3
  blob_storage_root: Path.join([File.cwd!(), "priv", "storage", "blobs"])

# S3 storage configuration
config :kyozo, :s3_storage,
  bucket: nil,  # Set in environment-specific config
  region: "us-east-1",
  access_key_id: nil,  # Will use AWS_ACCESS_KEY_ID env var if not set
  secret_access_key: nil  # Will use AWS_SECRET_ACCESS_KEY env var if not set

# ExAws configuration
config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
  region: [{:system, "AWS_REGION"}, "us-east-1"]

config :ex_aws, :s3,
  scheme: "https://",
  host: "s3.amazonaws.com",
  port: 443

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
