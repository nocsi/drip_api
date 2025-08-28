import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/kyozo start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :dirup, DirupWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :dirup, Dirup.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :dirup, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :dirup, DirupWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  config :dirup,
    token_signing_secret:
      System.get_env("TOKEN_SIGNING_SECRET") ||
        raise("Missing environment variable `TOKEN_SIGNING_SECRET`!")

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :dirup, DirupWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :dirup, DirupWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Production Email Configuration
  #
  # Configure email provider based on available environment variables
  # Priority order: SendGrid > Mailgun > AWS SES > Resend > SMTP > Local fallback

  # Configure Swoosh API client
  config :swoosh, :api_client, Swoosh.ApiClient.Finch

  # Determine and configure email adapter based on environment
  email_config =
    cond do
      # SendGrid (Recommended for production)
      System.get_env("SENDGRID_API_KEY") ->
        [
          adapter: Swoosh.Adapters.Sendgrid,
          api_key: System.get_env("SENDGRID_API_KEY")
        ]

      # Mailgun
      System.get_env("MAILGUN_API_KEY") && System.get_env("MAILGUN_DOMAIN") ->
        [
          adapter: Swoosh.Adapters.Mailgun,
          api_key: System.get_env("MAILGUN_API_KEY"),
          domain: System.get_env("MAILGUN_DOMAIN")
        ]

      # AWS SES
      System.get_env("AWS_ACCESS_KEY_ID") && System.get_env("AWS_SECRET_ACCESS_KEY") ->
        [
          adapter: Swoosh.Adapters.AmazonSES,
          region: System.get_env("AWS_REGION") || "us-east-1",
          access_key: System.get_env("AWS_ACCESS_KEY_ID"),
          secret: System.get_env("AWS_SECRET_ACCESS_KEY")
        ]

      # Resend
      System.get_env("RESEND_API_KEY") ->
        [
          adapter: Swoosh.Adapters.Resend,
          api_key: System.get_env("RESEND_API_KEY")
        ]

      # SMTP fallback
      System.get_env("SMTP_HOST") ->
        [
          adapter: Swoosh.Adapters.SMTP,
          relay: System.get_env("SMTP_HOST"),
          username: System.get_env("SMTP_USERNAME"),
          password: System.get_env("SMTP_PASSWORD"),
          port: System.get_env("SMTP_PORT", "587") |> String.to_integer(),
          ssl: System.get_env("SMTP_SSL", "false") == "true",
          tls: if(System.get_env("SMTP_TLS", "true") == "true", do: :always, else: :never),
          auth: if(System.get_env("SMTP_AUTH", "true") == "true", do: :always, else: :never),
          retries: System.get_env("SMTP_RETRIES", "2") |> String.to_integer()
        ]

      # Development/Test fallback - Local adapter
      true ->
        [
          adapter: Swoosh.Adapters.Local,
          preview: System.get_env("EMAIL_PREVIEW", "false") == "true"
        ]
    end

  # Apply email configuration
  config :dirup, Dirup.Mailer, email_config

  # Email delivery configuration
  config :dirup, :email,
    # Default sender for system emails
    from_email: System.get_env("FROM_EMAIL") || "noreply@kyozo.io",
    from_name: System.get_env("FROM_NAME") || "Kyozo Platform",

    # Email delivery settings
    async_delivery: System.get_env("EMAIL_ASYNC", "true") == "true",
    max_retries: System.get_env("EMAIL_MAX_RETRIES", "3") |> String.to_integer(),
    retry_delay: System.get_env("EMAIL_RETRY_DELAY", "5000") |> String.to_integer(),

    # Rate limiting
    rate_limit_per_minute: System.get_env("EMAIL_RATE_LIMIT", "60") |> String.to_integer(),

    # Template settings
    template_dir: System.get_env("EMAIL_TEMPLATE_DIR") || "priv/templates/email",

    # Tracking and analytics
    track_opens: System.get_env("EMAIL_TRACK_OPENS", "true") == "true",
    track_clicks: System.get_env("EMAIL_TRACK_CLICKS", "true") == "true"

  # Log email configuration (without secrets)
  IO.puts("📧 Email configured with adapter: #{inspect(Keyword.get(email_config, :adapter))}")

  if System.get_env("LOG_EMAIL_CONFIG") == "true" do
    sanitized_config =
      email_config
      |> Keyword.drop([:api_key, :secret, :password])

    IO.puts("📧 Email config: #{inspect(sanitized_config)}")
  end
end

# Dynamic Oban Cron configuration (all environments)
health_cron = System.get_env("CONTAINERS_HEALTH_CRON") || "*/2 * * * *"
metrics_cron = System.get_env("CONTAINERS_METRICS_CRON") || "*/5 * * * *"
metrics_cleanup_cron = System.get_env("CONTAINERS_METRICS_CLEANUP_CRON") || "0 1 * * *"
cleanup_cron = System.get_env("CONTAINERS_CLEANUP_CRON") || "0 2 * * *"
vacuum_cron = System.get_env("CONTAINERS_VACUUM_CRON") || "0 3 * * 0"

metrics_retention_days =
  System.get_env("CONTAINERS_METRICS_RETENTION_DAYS")
  |> case do
    nil -> 30
    val -> String.to_integer(val)
  end

metrics_cleanup_batch =
  System.get_env("CONTAINERS_METRICS_CLEANUP_BATCH_SIZE")
  |> case do
    nil -> 1000
    val -> String.to_integer(val)
  end

config :dirup, Oban,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {health_cron, Dirup.Containers.Workers.ContainerHealthMonitor,
        args: %{"batch_check" => true}},
       {metrics_cron, Dirup.Containers.Workers.MetricsCollector,
        args: %{"batch_collection" => true}},
       {metrics_cleanup_cron, Dirup.Containers.Workers.MetricsCollector,
        args: %{
          "cleanup_old_metrics" => true,
          "retention_days" => metrics_retention_days,
          "batch_size" => metrics_cleanup_batch
        }},
       {cleanup_cron, Dirup.Containers.Workers.CleanupWorker, args: %{"type" => "full_cleanup"}},
       {vacuum_cron, Dirup.Containers.Workers.CleanupWorker, args: %{"type" => "vacuum_analyze"}}
     ]}
  ]
