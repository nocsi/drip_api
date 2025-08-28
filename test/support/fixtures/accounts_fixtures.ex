defmodule Dirup.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dirup.Accounts` context.
  """

  alias Dirup.Accounts
  alias Dirup.Accounts.{User, Team}

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    default_attrs = %{
      email: "user#{unique_id}@example.com",
      password: "password123",
      confirmed_at: DateTime.utc_now(),
      name: "Test User #{unique_id}"
    }

    attrs = Enum.into(attrs, default_attrs)

    case Accounts.register_with_password(attrs) do
      {:ok, user} -> user
      {:error, changeset} -> raise "Failed to create user: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Generate a team.
  """
  def team_fixture(attrs \\ %{}) do
    user = attrs[:owner] || user_fixture()
    unique_id = System.unique_integer([:positive])

    default_attrs = %{
      name: "Test Team #{unique_id}",
      description: "A test team",
      owner_id: user.id
    }

    attrs =
      attrs
      |> Map.drop([:owner])
      |> Enum.into(default_attrs)

    case Accounts.create_team(attrs, actor: user) do
      {:ok, team} -> team
      {:error, changeset} -> raise "Failed to create team: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Generate a team membership.
  """
  def team_membership_fixture(attrs \\ %{}) do
    team = attrs[:team] || team_fixture()
    user = attrs[:user] || user_fixture()

    default_attrs = %{
      team_id: team.id,
      user_id: user.id,
      role: attrs[:role] || :member
    }

    attrs = Enum.into(attrs, default_attrs)

    case Accounts.add_team_member(team.id, user.id, attrs[:role], actor: team.owner) do
      {:ok, membership} ->
        membership

      {:error, changeset} ->
        raise "Failed to create team membership: #{inspect(changeset.errors)}"
    end
  end

  @doc """
  Generate an admin user.
  """
  def admin_user_fixture(attrs \\ %{}) do
    attrs = Map.put(attrs, :admin, true)
    user_fixture(attrs)
  end

  @doc """
  Generate a confirmed user.
  """
  def confirmed_user_fixture(attrs \\ %{}) do
    attrs = Map.put(attrs, :confirmed_at, DateTime.utc_now())
    user_fixture(attrs)
  end

  @doc """
  Extract user token from email for testing purposes.
  """
  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
