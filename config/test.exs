import Config
config :dirup, token_signing_secret: "widzEZZsnplJzO6OoNEoi4cdUWt+AHUM"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true]

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :dirup, Dirup.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "dirup_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :dirup, DirupWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "juvWYF54fW6O46xWjNKvoSyt24rsG4J6/T0bv1YgNqVwRSxCqGj7Qumm1G0seN74",
  server: false

# In test we don't send emails
config :dirup, Dirup.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :phoenix_test, :endpoint, DirupWeb.Endpoint

# Blob storage configuration for testing
config :dirup,
  blob_storage_backend: :disk,
  blob_storage_root: Path.join([System.tmp_dir!(), "dirup_test_blobs"])

# S3 storage configuration for testing (disabled by default)
config :dirup, :s3_storage,
  # No S3 in test by default
  bucket: nil,
  region: "us-east-1"

# ExAws configuration for testing
config :ex_aws,
  access_key_id: "test",
  secret_access_key: "test",
  region: "us-east-1"

config :ex_aws, :s3,
  scheme: "http://",
  host: "localhost",
  # MinIO test server port
  port: 9000

# LiveSvelte configuration for testing
config :live_svelte,
  # Disable vite in tests
  vite_host: nil

# Markdown processing configuration
config :dirup,
  # Use earmark for consistent test results
  markdown_processor: :earmark
