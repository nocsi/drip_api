defmodule Dirup.Repo do
  use AshPostgres.Repo, otp_app: :dirup

  @impl true
  def init(_type, config) do
    # Force UUID v7 for EVERYTHING
    config =
      config
      |> Keyword.put(:migration_primary_key,
        name: :id,
        type: :uuid,
        default: {:fragment, "uuid_generate_v7()"}
      )
      |> Keyword.put(:migration_foreign_key, type: :uuid)
      |> Keyword.put(:migration_timestamps, type: :utc_datetime_usec)

    {:ok, config}
  end

  def installed_extensions do
    # Add extensions here, and the migration generator will install them.
    ["ash-functions", "pg_trgm", "uuid-ossp", "pgcrypto", "citext"] ++ super()
  end

  # Override default UUID generation
  def autogenerate_id do
    Ecto.Adapters.SQL.query!(
      __MODULE__,
      "SELECT uuid_generate_v7()",
      []
    ).rows
    |> List.first()
    |> List.first()
  end

  # Don't open unnecessary transactions
  # will default to `false` in 4.0
  def prefer_transaction? do
    false
  end

  @impl true
  def min_pg_version do
    %Version{major: 17, minor: 4, patch: 0}
  end

  def autogenerate_id do
    Ecto.Adapters.SQL.query!(
      __MODULE__,
      "SELECT uuid_generate_v7()",
      []
    ).rows
    |> List.first()
    |> List.first()
  end

  @doc """
  Used by migrations --tenants to list all tenants, create related schemas, and migrate them.
  """
  @impl true
  def all_tenants do
    for tenant <- Ash.read!(Dirup.Accounts.Team) do
      tenant.domain
    end
  end
end
