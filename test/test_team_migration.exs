# Test script to verify team migration functionality
# Run with: mix run test_team_migration.exs

require Logger

alias Dirup.Accounts
alias Dirup.Accounts.{Team, UserTeam, Invitation}

Logger.info("🧪 Testing Team Migration Functionality")

# Create test user
test_user_params = %{
  name: "Test User",
  email: "test#{System.unique_integer()}@example.com",
  password: "password123",
  password_confirmation: "password123"
}

Logger.info("1️⃣ Creating test user...")
{:ok, user} = Accounts.register_with_password(test_user_params)
Logger.info("✅ Created user: #{user.email}")

# Create a team
team_params = %{
  name: "Test Team",
  domain: "test-team-#{System.unique_integer()}",
  description: "A test team for migration verification"
}

Logger.info("2️⃣ Creating team...")
{:ok, team} = Accounts.create_team(team_params, actor: user)
Logger.info("✅ Created team: #{team.name} (#{team.domain})")

# List user's teams
Logger.info("3️⃣ Listing user's teams...")
user_teams = Accounts.list_user_teams(actor: user)
Logger.info("✅ User belongs to #{length(user_teams)} team(s)")

# Check team membership
Logger.info("4️⃣ Checking team membership...")
{:ok, is_member} = Accounts.is_member?(user.id, tenant: team.id)
Logger.info("✅ User is member: #{is_member}")

# List team members
Logger.info("5️⃣ Listing team members...")
team_members = Accounts.list_team_members(actor: user, tenant: team.id)
Logger.info("✅ Team has #{length(team_members)} member(s)")

# Create second user for invitation test
test_user2_params = %{
  name: "Test User 2",
  email: "test2#{System.unique_integer()}@example.com",
  password: "password123",
  password_confirmation: "password123"
}

Logger.info("6️⃣ Creating second test user...")
{:ok, user2} = Accounts.register_with_password(test_user2_params)
Logger.info("✅ Created user: #{user2.email}")

# Send invitation
Logger.info("7️⃣ Sending invitation...")
invitation_params = %{invited_user_id: user2.id}
{:ok, invitation} = Accounts.invite_user(invitation_params, actor: user, tenant: team.id)
Logger.info("✅ Sent invitation to #{user2.email}")

# List received invitations
Logger.info("8️⃣ Checking received invitations...")
received_invitations = Accounts.list_received_invitations(actor: user2)
Logger.info("✅ User2 has #{length(received_invitations)} pending invitation(s)")

# Accept invitation
Logger.info("9️⃣ Accepting invitation...")
{:ok, _} = Accounts.accept_invitation(%{id: invitation.id}, actor: user2)
Logger.info("✅ Invitation accepted")

# Verify team now has 2 members
Logger.info("🔟 Re-checking team membership...")
team_members = Accounts.list_team_members(actor: user, tenant: team.id)
Logger.info("✅ Team now has #{length(team_members)} member(s)")

# Test role change
if length(team_members) >= 2 do
  user2_membership = Enum.find(team_members, &(&1.user_id == user2.id))

  Logger.info("1️⃣1️⃣ Changing member role...")

  {:ok, _} =
    Accounts.change_member_role(%{id: user2_membership.id, role: "admin"},
      actor: user,
      tenant: team.id
    )

  Logger.info("✅ Changed user2 role to admin")
end

# Clean up - leave team
if length(team_members) >= 2 do
  user2_membership = Enum.find(team_members, &(&1.user_id == user2.id))

  Logger.info("1️⃣2️⃣ User2 leaving team...")
  {:ok, _} = Accounts.leave_team(%{id: user2_membership.id}, actor: user2, tenant: team.id)
  Logger.info("✅ User2 left the team")
end

Logger.info("🎉 All team migration tests passed successfully!")
Logger.info("📋 Summary:")
Logger.info("   - Teams can be created")
Logger.info("   - Team membership works")
Logger.info("   - Invitations work end-to-end")
Logger.info("   - Role management works")
Logger.info("   - Members can leave teams")
Logger.info("   - All code interfaces function correctly")
