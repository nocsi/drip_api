defmodule Dirup.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    node_path = Path.join([Application.app_dir(:dirup), "priv"])

    children = [
      # {NodeJS.Supervisor, [path: LiveSvelte.SSR.NodeJS.server_path(), pool_size: 4]},
      # DISABLED - causes server startup hang
      {Dirup.NodeJS.Supervisor, [path: node_path, pool_size: 4]},
      DirupWeb.Telemetry,
      Dirup.Repo,
      {DNSCluster, query: Application.get_env(:dirup, :dns_cluster_query) || :ignore},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:dirup, :ash_domains),
         Application.fetch_env!(:dirup, Oban)
       )},
      {Phoenix.PubSub, name: Dirup.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Dirup.Finch},

      # Start a worker by calling: Dirup.Worker.start_link(arg)
      # {Dirup.Worker, arg},
      # Start to serve requests, typically the last entry
      DirupWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :dirup]},
      # Container management

      Dirup.Containers.ContainerManager,
      # PerformanceVFS Cache
      Dirup.Storage.VFS.Cache
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Dirup.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DirupWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp cache_config do
    [
      # Override defaults if needed
      content_ttl: config_value(:content_ttl, 3600),
      search_ttl: config_value(:search_ttl, 1800),
      query_ttl: config_value(:query_ttl, 300),
      max_cache_entries: config_value(:max_cache_entries, 50_000),
      max_content_size_mb: config_value(:max_content_size_mb, 100),
      cleanup_interval: config_value(:cleanup_interval, 300_000)
    ]
  end

  defp config_value(key, default) do
    Application.get_env(:dirup, :content_cache, [])[key] || default
  end
end
