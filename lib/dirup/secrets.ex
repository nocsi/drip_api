defmodule Dirup.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Dirup.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:dirup, :token_signing_secret)
  end

  def secret_for(
        [:authentication, :strategies, :google, key],
        Dirup.Accounts.User,
        _opts,
        _context
      ) do
    env_key =
      case key do
        :client_id -> :google_client_id
        :client_secret -> :google_client_secret
        :redirect_uri -> :google_redirect_uri
      end

    Application.fetch_env(:dirup, env_key)
  end

  def secret_for(
        [:authentication, :strategies, :github, key],
        Dirup.Accounts.User,
        _opts,
        _context
      ) do
    env_key =
      case key do
        :client_id -> :github_client_id
        :client_secret -> :github_client_secret
        :redirect_uri -> :github_redirect_uri
      end

    Application.fetch_env(:dirup, env_key)
  end

  def secret_for(
        [:authentication, :strategies, :apple, key],
        Dirup.Accounts.User,
        _opts,
        _context
      ) do
    env_key =
      case key do
        :client_id -> :apple_client_id
        :client_secret -> :apple_client_secret
        :team_id -> :apple_team_id
        :private_key_path -> :apple_private_key_path
        :private_key_id -> :apple_private_key_id
        :redirect_uri -> :apple_redirect_uri
      end

    Application.fetch_env(:dirup, env_key)
  end
end
