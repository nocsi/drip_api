defmodule Kyozo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    node_path = Path.join([Application.app_dir(:kyozo), "priv"])

    children = [
      # {NodeJS.Supervisor, [path: LiveSvelte.SSR.NodeJS.server_path(), pool_size: 4]},
      # {Kyozo.NodeJS.Supervisor, [path: node_path, pool_size: 4]},  # DISABLED - causes server startup hang
      KyozoWeb.Telemetry,
      Kyozo.Repo,
      {DNSCluster, query: Application.get_env(:kyozo, :dns_cluster_query) || :ignore},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:kyozo, :ash_domains),
         Application.fetch_env!(:kyozo, Oban)
       )},
      {Phoenix.PubSub, name: Kyozo.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Kyozo.Finch},
      # Start a worker by calling: Kyozo.Worker.start_link(arg)
      # {Kyozo.Worker, arg},
      # Start to serve requests, typically the last entry
      KyozoWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :kyozo]},
      # Container management
      Kyozo.Containers.ContainerManager,
      # VFS Cache
      Kyozo.Storage.VFS.Cache
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Kyozo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    KyozoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
