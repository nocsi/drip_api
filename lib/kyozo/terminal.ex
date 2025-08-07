defmodule Kyozo.Terminal do
  use Ash.Domain, otp_app: :kyozo, extensions: [AshGraphql.Domain, AshJsonApi.Domain]

  # json_api do
  #   type "terminal"
  # end

  # graphql do
  #   type "terminal"
  # end


  resources do
  end
end
