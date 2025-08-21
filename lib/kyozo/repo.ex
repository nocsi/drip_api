defmodule Kyozo.Repo do
  use AshPostgres.Repo,
    otp_app: :kyozo

  @impl true
  def installed_extensions do
    # Add extensions here, and the migration generator will install them.
    ["ash-functions", "pg_trgm", "uuid-ossp", "pgcrypto", "citext"]
  end

  @impl true
  def uuid_v7_function do
    "ash_uuidv7_generate()"
  end

  # Don't open unnecessary transactions
  # will default to `false` in 4.0
  @impl true
  def prefer_transaction? do
    false
  end

  @impl true
  def min_pg_version do
    %Version{major: 17, minor: 4, patch: 0}
  end

  @doc """
  Used by migrations --tenants to list all tenants, create related schemas, and migrate them.
  """
  @impl true
  def all_tenants do
    for tenant <- Ash.read!(Kyozo.Accounts.Team) do
      tenant.domain
    end
  end
end
