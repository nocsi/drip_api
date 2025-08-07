defmodule Kyozo.Accounts.UserIdentity do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.UserIdentity],
    domain: Kyozo.Accounts

    user_identity do
      domain Kyozo.Accounts
      user_resource Kyozo.Accounts.User
    end

    postgres do
      table("user_identities")
      repo Kyozo.Repo
    end


end
