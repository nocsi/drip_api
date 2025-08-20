defmodule KyozoWeb.AshJsonApiRouter do
  use AshJsonApi.Router,
    domains: [
      Kyozo.Accounts,
      # Kyozo.Test,
      # Kyozo.Debug,
      Kyozo.Workspaces
    ]
end
