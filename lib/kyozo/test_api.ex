defmodule Elixir.Kyozo.TestAPI do
  use Ash.Domain,
    otp_app: :kyozo,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  json_api do
    authorize? false
  end

  graphql do
    authorize? false
  end

  resources do
    # Resources will be added by the generator
  end
end
