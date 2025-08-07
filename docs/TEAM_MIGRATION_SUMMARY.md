# Team Resource Migration Summary

## Overview

This document summarizes the migration of team-related resources from the Workspaces domain to the Accounts domain, consolidating duplicate functionality and establishing a single source of truth for team management.

## What Was Migrated

### Resources Consolidated

1. **Kyozo.Workspaces.Team** → **Kyozo.Accounts.Team** (enhanced)
2. **Kyozo.Workspaces.TeamMember** → **Kyozo.Accounts.UserTeam** (enhanced)
3. **Kyozo.Workspaces.Invitation** → **Kyozo.Accounts.Invitation** (moved)

### Key Changes Made

#### 1. Enhanced Kyozo.Accounts.Team
- Added team management actions from Workspaces.Team:
  - `create_team` - Creates team and assigns actor as admin
  - `list_user_teams` - Lists teams user belongs to
  - `update_team` - Updates team details
- Added authorization policies for team operations
- Added PubSub notifications for real-time updates
- Added relationships to invitations and user teams
- Maintained multitenancy support with tenant schema management

#### 2. Enhanced Kyozo.Accounts.UserTeam
- Added role attribute with validation (admin, member, owner)
- Added team management actions from TeamMember:
  - `add_team_member` - Adds user to team
  - `list_team_members` - Lists team members
  - `change_member_role` - Updates member role
  - `remove_team_member` - Removes member from team
  - `leave_team` - Allows member to leave team
  - `is_member?` - Checks team membership
- Added authorization policies
- Added PubSub notifications
- Added multitenancy support
- Added calculations (e.g., `can_manage`)

#### 3. Moved Kyozo.Accounts.Invitation
- Moved from Workspaces to Accounts domain
- Updated relationships to reference Accounts.Team
- Maintained all invitation functionality:
  - `invite_user` - Send invitation
  - `accept_invitation` - Accept and join team
  - `decline_invitation` - Decline invitation
  - `cancel_invitation` - Cancel sent invitation
  - `list_received_invitations` - List user's pending invitations
  - `list_invitations_sent` - List team's sent invitations

## Database Changes

### Migrations Generated
- Added `role` column to `user_teams` table
- Updated foreign key relationships
- Added proper constraints and validations
- Maintained existing data integrity

### Schema Updates
- `user_teams` table now includes role management
- `invitations` table references updated team structure
- All multitenancy relationships preserved

## API Changes

### New Code Interfaces
Added to Kyozo.Accounts domain:
```elixir
# Team management
define :create_team
define :list_user_teams
define :update_team
define :delete_team
define :get_team

# Member management
define :add_team_member
define :list_team_members
define :change_member_role
define :remove_team_member
define :leave_team
define :is_member?

# Invitation management
define :invite_user
define :list_received_invitations
define :list_invitations_sent
define :accept_invitation
define :decline_invitation
define :cancel_invitation
```

### Updated Controllers
- **KyozoWeb.API.TeamsController** - Updated to use Accounts domain
- **JSON serializers** - Updated to reference new team structure

## Dashboard Implementation

### New Team Dashboard
Created `KyozoWeb.Live.Team.Dashboard` with:

#### Features
- **Overview Tab**: Team count, pending invitations, quick actions
- **Teams Tab**: List and manage user's teams, team selection
- **Invitations Tab**: Manage received invitations

#### Team Management
- Create new teams with domain and description
- View team details and members
- Invite users by email
- Manage member roles (admin, member, owner)
- Remove team members
- Leave teams
- Accept/decline invitations

#### Real-time Updates
- PubSub integration for live updates
- Automatic refresh when members join/leave
- Live invitation status updates

### Route Added
```elixir
live "/team/dashboard", Live.Team.Dashboard, :dashboard
```

## Files Modified

### Core Resources
- `lib/kyozo/accounts/team.ex` - Enhanced with team management
- `lib/kyozo/accounts/user_team.ex` - Enhanced with role management
- `lib/kyozo/accounts/invitation.ex` - Moved from Workspaces
- `lib/kyozo/accounts.ex` - Added code interfaces

### Controllers & Views
- `lib/kyozo_web/controllers/api/teams_controller.ex` - Updated domain usage
- `lib/kyozo_web/controllers/api/teams_json.ex` - Updated references
- `lib/kyozo_web/controllers/api/workspaces_json.ex` - Updated team references
- `lib/kyozo_web/controllers/api/notebooks_json.ex` - Updated team references
- `lib/kyozo_web/controllers/api/documents_json.ex` - Updated team references

### LiveViews
- `lib/kyozo_web/live/team/dashboard.ex` - New team management interface
- `lib/kyozo_web/router.ex` - Added dashboard route

### Resource Updates
- `lib/kyozo/accounts/user.ex` - Updated invitation relationship
- `lib/kyozo/workspaces/document.ex` - Updated team references
- `lib/kyozo/workspaces/workspace.ex` - Updated team references
- `lib/kyozo/workspaces/role.ex` - Updated team member references

## Files Removed

### Deleted Resources
- `lib/kyozo/workspaces/team.ex` - Consolidated into Accounts.Team
- `lib/kyozo/workspaces/team_member.ex` - Consolidated into Accounts.UserTeam
- `lib/kyozo/workspaces/invitation.ex` - Moved to Accounts.Invitation

### Updated Domain
- `lib/kyozo/workspaces.ex` - Removed team-related resources

## Benefits Achieved

### 1. Single Source of Truth
- All team functionality now centralized in Accounts domain
- Eliminated duplicate team management logic
- Cleaner domain boundaries

### 2. Enhanced Functionality
- Rich team management dashboard
- Real-time updates via PubSub
- Comprehensive role management
- Proper authorization policies

### 3. Better User Experience
- Intuitive team dashboard interface
- Live invitation management
- Easy team switching and member management
- Real-time notifications

### 4. Improved Maintainability
- Reduced code duplication
- Clearer separation of concerns
- Consistent API patterns
- Better test coverage paths

## Remaining Work

### 1. Update Existing Controllers
Several controllers still reference old team modules and need updates:
- `lib/kyozo_web/controllers/workspace_controller.ex`
- Various validation modules in workspaces
- Plug modules for tenant authentication

### 2. Fix Deprecation Warnings
- Update `push_redirect` to `push_navigate`
- Fix undefined function calls
- Clean up unused aliases

### 3. Testing
- Add comprehensive tests for new team dashboard
- Test team invitation flows
- Verify multitenancy still works correctly
- Test authorization policies

### 4. Documentation
- Update API documentation
- Add user guides for team management
- Document new dashboard features

## Migration Verification

### Database Schema
```sql
-- Verify user_teams table has role column
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'user_teams' AND column_name = 'role';

-- Verify foreign key relationships
SELECT * FROM information_schema.table_constraints
WHERE table_name IN ('user_teams', 'invitations', 'teams');
```

### Test Team Operations
1. Create a new team via dashboard
2. Invite a user to the team
3. Accept invitation as invited user
4. Change member roles
5. Leave team
6. Verify real-time updates work

## Next Steps

1. **Complete Controller Updates**: Update remaining controllers to use Accounts domain
2. **Fix Warnings**: Address compilation warnings and deprecations
3. **Add Tests**: Comprehensive test coverage for new functionality
4. **User Documentation**: Create guides for team management features
5. **Performance Testing**: Ensure multitenancy performance is maintained
6. **Security Review**: Verify authorization policies work correctly

The migration successfully consolidates team management into a single, cohesive system while providing users with a rich dashboard interface for managing their teams and collaborations.
