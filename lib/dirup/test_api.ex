defmodule Elixir.Dirup.TestAPI do
  use Ash.Domain,
    otp_app: :dirup,
    extensions: [AshJsonApi.Domain]

  # GraphQL configuration removed during GraphQL cleanup

  json_api do
    authorize? false
  end

  resources do
    # Resources will be added by the generator
  end
end
