defmodule Kyozo.Generator do
  @moduledoc "Data generation for tests"

  use Ash.Generator

  @doc """
  Generates user changesets with the `:register_with_password` action.

  ## Extra Options

  - `:role` - Specify a role to give the created user. Defaults to `:user`.
  """
  def user(opts \\ []) do
    changeset_generator(
      Kyozo.Accounts.User,
      :register_with_password,
      defaults: [
        # Generates unique values using an auto-incrementing sequence
        # eg. `user1@example.com`, `user2@example.com`, etc.
        email: sequence(:user_email, &"user#{&1}@example.com"),
        password: "password",
        password_confirmation: "password"
      ],
      overrides: opts
    )
  end

  @doc """
  Generates team changesets with the `:create` action.

  ## Extra Options

  - `:owner` - Specify the owner user for the team
  """
  def team(opts \\ []) do
    owner = opts[:owner] || once(:default_owner, fn -> generate(user()) end)

    changeset_generator(
      Kyozo.Accounts.Team,
      :create,
      defaults: [
        name: sequence(:team_name, &"Team #{&1}"),
        description: "Test team description"
      ],
      overrides: opts,
      actor: owner
    )
  end

  @doc """
  Generates workspace changesets with the `:create` action.

  ## Extra Options

  - `:team` - Specify the team for the workspace
  - `:owner` - Specify the owner user for the workspace
  """
  def workspace(opts \\ []) do
    team = opts[:team] || once(:default_team, fn -> generate(team()) end)
    owner = opts[:owner] || team.owner

    changeset_generator(
      Kyozo.Workspaces.Workspace,
      :create,
      defaults: [
        name: sequence(:workspace_name, &"Workspace #{&1}"),
        description: "Test workspace description",
        team_id: team.id
      ],
      overrides: opts,
      actor: owner
    )
  end

  @doc """
  Generates file changesets with the `:create` action.

  ## Extra Options

  - `:workspace` - Specify the workspace for the file
  - `:team` - Specify the team for the file
  - `:content` - Specify the file content
  """
  def file(opts \\ []) do
    workspace = opts[:workspace] || once(:default_workspace, fn -> generate(workspace()) end)
    team = opts[:team] || workspace.team
    actor = opts[:actor] || team.owner

    changeset_generator(
      Kyozo.Workspaces.File,
      :create,
      defaults: [
        name: sequence(:file_name, &"test_file_#{&1}.md"),
        file_path: sequence(:file_path, &"/documents/test_file_#{&1}.md"),
        content_type: "text/markdown",
        content: opts[:content] || "# Test File\n\nThis is a test file.",
        workspace_id: workspace.id,
        team_id: team.id
      ],
      overrides: opts,
      actor: actor
    )
  end

  @doc """
  Generates storage resource changesets with the `:create` action.

  ## Extra Options

  - `:content` - Specify the content to store
  - `:filename` - Specify the filename
  - `:storage_backend` - Specify the storage backend
  """
  def storage_resource(opts \\ []) do
    changeset_generator(
      Kyozo.Storage.StorageResource,
      :create_from_content,
      defaults: [
        content: opts[:content] || "Test content",
        filename: opts[:filename] || sequence(:filename, &"test_file_#{&1}.txt"),
        storage_backend: opts[:storage_backend] || :ram,
        storage_options: %{}
      ],
      overrides: opts,
      authorize?: false
    )
  end

  @doc """
  Generates notification changesets with the `:create` action.

  ## Extra Options

  - `:user_id` - Specify the user ID for the notification
  """
  def notification(opts \\ []) do
    user_id = opts[:user_id] || once(:default_user_id, fn -> generate(user()).id end)

    changeset_generator(
      Kyozo.Accounts.Notification,
      :create,
      defaults: [
        title: sequence(:notification_title, &"Notification #{&1}"),
        message: "Test notification message",
        user_id: user_id
      ],
      overrides: opts,
      authorize?: false
    )
  end
end