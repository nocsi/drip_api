defmodule Dirup.Accounts.UserIdentity do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.UserIdentity],
    domain: Dirup.Accounts

  postgres do
    table "user_identities"
    repo Dirup.Repo
  end

  user_identity do
    domain Dirup.Accounts
    user_resource Dirup.Accounts.User
  end
end
