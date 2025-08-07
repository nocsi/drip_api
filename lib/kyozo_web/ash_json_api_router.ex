defmodule KyozoWeb.AshJsonApiRouter do
  use AshJsonApi.Router,
    domains: [
      Kyozo.Accounts,
      # Kyozo.Test,
      # Kyozo.Debug,
      Kyozo.Workspaces,
    ],
    open_api: "/open_api",
    open_api_title: "Kyozo API Documentation",
    open_api_version: to_string(Application.spec(:kyozo, :vsn))
end
