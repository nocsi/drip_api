# Simple test seed file to debug issues
# Run with: mix run test_seeds.exs

require Logger

alias Dirup.Accounts

# Test basic user creation
Logger.info("🧪 Testing basic user creation...")

test_user = %{
  name: "Test User",
  email: "test@example.com",
  password: "password123",
  password_confirmation: "password123"
}

try do
  Logger.info("Creating user...")
  {:ok, user} = Accounts.register_with_password(test_user)
  Logger.info("✅ User created: #{user.email}")

  # Try to confirm the user
  Logger.info("Confirming user...")

  {:ok, confirmed_user} =
    Ash.update(user, :update, %{confirmed_at: DateTime.utc_now()}, authorize?: false)

  Logger.info("✅ User confirmed")

  # Try to create a team
  Logger.info("Creating team...")

  team_attrs = %{
    name: "Test Team",
    domain: "test-team",
    description: "A test team",
    owner_user_id: user.id
  }

  {:ok, team} = Accounts.create_team(team_attrs, actor: confirmed_user)
  Logger.info("✅ Team created: #{team.name}")

  Logger.info("🎉 All basic operations successful!")
rescue
  error ->
    Logger.error("❌ Error occurred: #{inspect(error)}")
    Logger.error("Error type: #{error.__struct__}")

    case error do
      %Ash.Error.Invalid{errors: errors} ->
        Logger.error("Validation errors:")

        Enum.each(errors, fn err ->
          Logger.error("  - #{inspect(err)}")
        end)

      %Ash.Error.Forbidden{errors: errors} ->
        Logger.error("Authorization errors:")

        Enum.each(errors, fn err ->
          Logger.error("  - #{inspect(err)}")
        end)

      _ ->
        Logger.error("Full error: #{Exception.format(:error, error, __STACKTRACE__)}")
    end
end
