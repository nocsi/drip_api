# Kyozo Store Development Guide

## Overview

This guide provides comprehensive instructions for developing, testing, and deploying the Kyozo Store platform. It covers the complete development workflow, coding standards, best practices, and architectural patterns specific to this codebase.

## Prerequisites

### System Requirements
- **Elixir**: 1.14+ 
- **Erlang/OTP**: 25+
- **Node.js**: 18+ (for frontend assets)
- **PostgreSQL**: 14+ 
- **Git**: 2.30+
- **Docker**: 20+ (optional, for containerized development)

### Development Tools
- **IDE**: VS Code with Elixir LS extension
- **Database Client**: pgAdmin, DBeaver, or psql
- **API Testing**: Insomnia, Postman, or curl
- **Git GUI**: GitKraken, SourceTree, or command line

## Project Setup

### 1. Repository Clone
```bash
git clone git@gitlab.nocsi.org:nocsi/kyozo_api.git
cd kyozo_api
```

### 2. Environment Configuration
```bash
# Copy environment template
cp .env.example .env

# Configure database settings
export DATABASE_URL="postgresql://postgres:password@localhost:5432/kyozo_dev"
export SECRET_KEY_BASE="generate_with_mix_phx_gen_secret"

# Configure external services (optional)
export AWS_ACCESS_KEY_ID="your_aws_key"
export AWS_SECRET_ACCESS_KEY="your_aws_secret"
export AWS_S3_BUCKET="kyozo-storage-dev"
```

### 3. Dependencies Installation
```bash
# Install Elixir dependencies
mix deps.get

# Setup database
mix ash.setup

# Install frontend dependencies
cd assets && npm install && cd ..
```

### 4. Database Setup
```bash
# Run migrations
mix ash_postgres.migrate
mix ash_postgres.migrate --tenants

# Seed data (optional)
mix run priv/repo/seeds.exs
```

### 5. Development Server
```bash
# Start Phoenix server with dependencies
mix phx.server

# Alternative: Start with IEx for debugging
iex -S mix phx.server
```

The application will be available at `http://localhost:4000`.

## Development Workflow

### Branch Management
```bash
# Feature development
git checkout main
git pull origin main
git checkout -b feature/new-workspace-feature

# Make changes, commit, push
git add .
git commit -m "feat: add workspace collaboration features"
git push -u origin feature/new-workspace-feature

# Create merge request in GitLab
```

### Code Quality Checks
```bash
# Format code
mix format

# Type checking
mix dialyzer

# Lint check
mix credo

# Security audit
mix deps.audit

# Test suite
mix test

# Frontend lint and format
cd assets && npm run lint && npm run format
```

### Database Management
```bash
# Generate new migration
mix ash_postgres.generate_migrations

# Apply migrations
mix ash_postgres.migrate

# Rollback migration
mix ash_postgres.rollback

# Reset database
mix ash.reset
```

## Coding Standards

### Elixir Style Guide

#### Module Organization
```elixir
defmodule Kyozo.Workspaces.Workspace do
  @moduledoc """
  Workspace resource representing a collaborative workspace container.
  
  Detailed description of the module's purpose, key features,
  and usage examples.
  """
  
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Workspaces,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]
  
  # Module constants
  @valid_statuses ~w(active archived deleted)a
  @default_settings %{auto_save: true, collaborative_mode: false}
  
  # Public API functions first
  def list_active_workspaces(opts \\ []) do
    # Implementation
  end
  
  # Private functions last
  defp validate_workspace_name(name) do
    # Implementation
  end
end
```

#### Function Definitions
```elixir
# Good: Clear function heads with guards
def create_workspace(attrs, %{team_id: team_id} = context) 
    when is_binary(team_id) do
  attrs
  |> Map.put(:team_id, team_id)
  |> validate_workspace_attrs()
  |> handle_creation_result()
end

# Pattern matching in function heads
def handle_creation_result({:ok, workspace}), do: {:ok, workspace}
def handle_creation_result({:error, reason}), do: {:error, "Failed to create workspace: #{reason}"}

# Use with for complex operation chains
def process_workspace_creation(attrs, context) do
  with {:ok, validated_attrs} <- validate_attrs(attrs),
       {:ok, workspace} <- create_workspace(validated_attrs, context),
       {:ok, _event} <- emit_creation_event(workspace) do
    {:ok, workspace}
  else
    {:error, reason} -> {:error, reason}
    error -> {:error, "Unexpected error: #{inspect(error)}"}
  end
end
```

#### Documentation Standards
```elixir
@doc """
Creates a new workspace within the given team context.

## Parameters
- `attrs` - Workspace attributes map
- `context` - Authentication and team context

## Returns
- `{:ok, workspace}` - Successfully created workspace
- `{:error, changeset}` - Validation errors
- `{:error, reason}` - Other creation errors

## Examples

    iex> create_workspace(%{name: "Dev Workspace"}, %{team_id: "team-123"})
    {:ok, %Workspace{name: "Dev Workspace", team_id: "team-123"}}

"""
def create_workspace(attrs, context) do
  # Implementation
end
```

### Frontend Style Guide

#### Svelte 5 Patterns
```typescript
// Use modern Svelte 5 runes syntax
<script lang="ts">
  import type { Workspace } from '../types';
  
  // Props with modern syntax
  let { 
    workspace,
    onUpdate,
    loading = false 
  }: {
    workspace: Workspace;
    onUpdate: (workspace: Workspace) => void;
    loading?: boolean;
  } = $props();
  
  // State with runes
  let isEditing = $state(false);
  let editForm = $state({
    name: workspace.name,
    description: workspace.description
  });
  
  // Derived values
  let canEdit = $derived(workspace.permissions?.includes('edit'));
  let hasChanges = $derived(
    editForm.name !== workspace.name || 
    editForm.description !== workspace.description
  );
  
  // Effects
  $effect(() => {
    if (workspace.id) {
      console.log('Workspace loaded:', workspace.name);
    }
  });
</script>

<!-- Use modern event syntax -->
<button 
  onclick={() => isEditing = !isEditing}
  disabled={!canEdit}
>
  {isEditing ? 'Cancel' : 'Edit'}
</button>
```

#### Icon Import Pattern
```typescript
// ALWAYS use correct Lucide import path
import { Users, Plus, Settings, Loader2 } from '@lucide/svelte';

// NEVER use this (causes build failures)
import { Users } from 'lucide-svelte';
```

#### Component Architecture
```typescript
// Component composition pattern
<script lang="ts">
  import { Card, CardContent, CardHeader, CardTitle } from '../ui/card';
  import { Button } from '../ui/button';
  import { Badge } from '../ui/badge';
</script>

<Card>
  <CardHeader>
    <div class="flex items-center justify-between">
      <CardTitle>{workspace.name}</CardTitle>
      <Badge variant={workspace.status === 'active' ? 'success' : 'secondary'}>
        {workspace.status}
      </Badge>
    </div>
  </CardHeader>
  <CardContent>
    <p class="text-muted-foreground">{workspace.description}</p>
    <div class="mt-4 flex gap-2">
      <Button variant="outline" onclick={handleEdit}>Edit</Button>
      <Button onclick={handleOpen}>Open</Button>
    </div>
  </CardContent>
</Card>
```

## Ash Framework Patterns

### Resource Definition Patterns
```elixir
defmodule Kyozo.Workspaces.Workspace do
  use Ash.Resource,
    otp_app: :kyozo,
    domain: Kyozo.Workspaces,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]
  
  # Attributes first
  attributes do
    uuid_v7_primary_key :id
    
    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end
    
    attribute :description, :string do
      public? true
    end
    
    attribute :status, :atom do
      allow_nil? false
      default :active
      constraints one_of: [:active, :archived, :deleted]
      public? true
    end
    
    attribute :settings, :map do
      default %{}
      public? true
    end
    
    # Timestamps
    create_timestamp :created_at
    update_timestamp :updated_at
  end
  
  # Relationships second
  relationships do
    belongs_to :team, Kyozo.Accounts.Team do
      allow_nil? false
      public? true
    end
    
    belongs_to :created_by, Kyozo.Accounts.User do
      public? true
    end
    
    has_many :files, Kyozo.Workspaces.File do
      public? true
    end
  end
  
  # Actions third
  actions do
    defaults [:read, :destroy]
    
    create :create do
      primary? true
      accept [:name, :description, :settings]
      
      argument :team_id, :uuid do
        allow_nil? false
      end
      
      change set_attribute(:team_id, arg(:team_id))
      change relate_actor(:created_by)
    end
    
    update :update do
      primary? true
      accept [:name, :description, :settings]
      
      # Prevent team changes after creation
      change prevent_change(:team_id)
    end
    
    read :list_active do
      filter expr(status == :active)
      prepare build(sort: [updated_at: :desc])
    end
  end
  
  # Policies fourth
  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_in_relationship(:team, :users)
    end
    
    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_in_relationship(:team, :users)
      authorize_if relates_to_actor_via(:created_by)
    end
  end
  
  # Validations, calculations, and other features last
  validations do
    validate present([:name]), on: [:create, :update]
    validate match(:name, ~r/^[a-zA-Z0-9\s\-_]+$/), message: "contains invalid characters"
  end
  
  calculations do
    calculate :file_count, :integer, expr(count(files))
  end
end
```

### Action Implementation Patterns
```elixir
# Custom actions with proper error handling
actions do
  action :duplicate_workspace, :struct do
    argument :source_workspace_id, :uuid, allow_nil?: false
    argument :new_name, :string, allow_nil?: false
    
    run fn input, context ->
      with {:ok, source_workspace} <- get_source_workspace(input.arguments.source_workspace_id),
           {:ok, duplicated_workspace} <- duplicate_workspace_data(source_workspace, input.arguments.new_name),
           {:ok, _files} <- duplicate_workspace_files(source_workspace, duplicated_workspace) do
        {:ok, duplicated_workspace}
      else
        {:error, reason} -> {:error, reason}
      end
    end
  end
end

# Change modules for reusable logic
defmodule Kyozo.Workspaces.Changes.EmitEvent do
  use Ash.Resource.Change
  
  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn changeset, result ->
      event_type = if changeset.action.type == :create, do: :workspace_created, else: :workspace_updated
      
      Phoenix.PubSub.broadcast(
        Kyozo.PubSub,
        "workspace:#{result.team_id}",
        {event_type, result}
      )
      
      {:ok, result}
    end)
  end
end
```

### Policy Patterns
```elixir
policies do
  # Allow authentication actions always
  bypass AshAuthentication.Checks.AshAuthenticationInteraction do
    authorize_if always()
  end
  
  # Team-based isolation
  policy action_type(:read) do
    authorize_if actor_attribute_in_relationship(:team, :users)
  end
  
  # Role-based permissions
  policy action_type([:update, :destroy]) do
    authorize_if expr(
      team.user_teams.role in [:owner, :admin] and 
      team.user_teams.user_id == ^actor(:id)
    )
  end
  
  # Resource ownership
  policy action(:delete_file) do
    authorize_if relates_to_actor_via(:created_by)
    authorize_if actor_attribute_equals(:role, :admin)
  end
  
  # Forbid by default
  policy always() do
    forbid_if always()
  end
end
```

## Database Development

### Migration Patterns
```elixir
defmodule Kyozo.Repo.Migrations.AddWorkspaceCollaboration do
  use Ecto.Migration

  def up do
    # Add new columns with proper constraints
    alter table(:workspaces) do
      add :collaborative_mode, :boolean, default: false, null: false
      add :max_collaborators, :integer, default: 10
      add :collaboration_settings, :map, default: %{}
    end
    
    # Add indexes for performance
    create index(:workspaces, [:team_id, :collaborative_mode])
    
    # Add check constraints for business rules
    create constraint(:workspaces, :positive_max_collaborators, 
                     check: "max_collaborators > 0")
  end

  def down do
    alter table(:workspaces) do
      remove :collaborative_mode
      remove :max_collaborators
      remove :collaboration_settings
    end
  end
end
```

### Seeding Patterns
```elixir
# priv/repo/seeds.exs
alias Kyozo.Accounts

# Create admin user
admin_attrs = %{
  name: "Admin User",
  email: "admin@kyozo.com",
  password: "SecurePassword123!"
}

{:ok, admin} = Accounts.User.seed_admin(admin_attrs)

# Create test team
{:ok, team} = Accounts.Team.create(%{
  name: "Test Team",
  domain: "test-team",
  description: "Development team"
}, actor: admin)

# Add admin to team
Accounts.UserTeam.add_team_member(%{
  user_id: admin.id,
  team_id: team.id,
  role: :owner
}, actor: admin)
```

## Testing Strategies

### Unit Testing Patterns
```elixir
defmodule Kyozo.WorkspacesTest do
  use Kyozo.DataCase, async: true
  
  alias Kyozo.Workspaces.Workspace
  
  describe "create_workspace/2" do
    setup do
      user = create_user()
      team = create_team(user)
      
      %{user: user, team: team}
    end
    
    test "creates workspace with valid attributes", %{user: user, team: team} do
      attrs = %{
        name: "Test Workspace",
        description: "A test workspace",
        team_id: team.id
      }
      
      assert {:ok, workspace} = Workspace.create(attrs, actor: user)
      assert workspace.name == "Test Workspace"
      assert workspace.team_id == team.id
      assert workspace.created_by_id == user.id
    end
    
    test "fails with invalid name", %{user: user, team: team} do
      attrs = %{
        name: "", # Invalid: empty name
        team_id: team.id
      }
      
      assert {:error, changeset} = Workspace.create(attrs, actor: user)
      assert changeset.errors[:name]
    end
  end
  
  describe "authorization" do
    test "prevents access to other team's workspaces" do
      user1 = create_user()
      user2 = create_user()
      team1 = create_team(user1)
      team2 = create_team(user2)
      
      workspace = create_workspace(team1, user1)
      
      # User2 should not be able to access team1's workspace
      assert {:error, %Ash.Error.Forbidden{}} = 
        Workspace.read!(workspace.id, actor: user2)
    end
  end
end
```

### Integration Testing
```elixir
defmodule KyozoWeb.WorkspaceControllerTest do
  use KyozoWeb.ConnCase, async: true
  
  setup %{conn: conn} do
    user = create_user()
    team = create_team(user)
    token = create_auth_token(user)
    
    conn = 
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/vnd.api+json")
    
    %{conn: conn, user: user, team: team}
  end
  
  describe "POST /api/v1/workspaces" do
    test "creates workspace", %{conn: conn, team: team} do
      attrs = %{
        data: %{
          type: "workspace",
          attributes: %{
            name: "New Workspace",
            description: "A new workspace"
          }
        }
      }
      
      conn = post(conn, ~p"/api/v1/workspaces", attrs)
      
      assert %{"data" => workspace_data} = json_response(conn, 201)
      assert workspace_data["attributes"]["name"] == "New Workspace"
    end
  end
end
```

### Frontend Testing
```typescript
// Component testing
import { render, screen, fireEvent } from '@testing-library/svelte';
import { expect, test, vi } from 'vitest';
import WorkspaceCard from './WorkspaceCard.svelte';

test('displays workspace information', () => {
  const workspace = {
    id: '123',
    name: 'Test Workspace',
    description: 'A test workspace',
    status: 'active'
  };
  
  render(WorkspaceCard, { props: { workspace } });
  
  expect(screen.getByText('Test Workspace')).toBeInTheDocument();
  expect(screen.getByText('A test workspace')).toBeInTheDocument();
});

test('calls onEdit when edit button is clicked', async () => {
  const onEdit = vi.fn();
  const workspace = { id: '123', name: 'Test' };
  
  render(WorkspaceCard, { 
    props: { workspace, onEdit } 
  });
  
  await fireEvent.click(screen.getByText('Edit'));
  expect(onEdit).toHaveBeenCalledWith(workspace);
});
```

## API Development

### JSON:API Patterns
```elixir
# In resource definition
json_api do
  type "workspace"
  
  routes do
    base "/workspaces"
    get :read
    index :read
    post :create
    patch :update
    delete :destroy
    
    # Custom actions
    post :duplicate, route: "/:id/duplicate"
  end
  
  # Include relationships by default
  includes [:team, :created_by, :files]
end
```

### GraphQL Patterns
```elixir
# In resource definition
graphql do
  type :workspace
  
  queries do
    list :workspaces, :read
    get :workspace, :read
  end
  
  mutations do
    create :create_workspace, :create
    update :update_workspace, :update
    destroy :delete_workspace, :destroy
  end
end
```

### API Testing
```bash
# Test JSON:API endpoints
curl -X POST http://localhost:4000/api/v1/workspaces \
  -H "Content-Type: application/vnd.api+json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "data": {
      "type": "workspace",
      "attributes": {
        "name": "API Test Workspace",
        "description": "Created via API"
      }
    }
  }'

# Test GraphQL endpoint
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "query": "query { workspaces { id name description } }"
  }'
```

## Storage Development

### Storage Backend Implementation
```elixir
defmodule Kyozo.Storage.Storages.CustomBackend do
  @behaviour Kyozo.Storage.AbstractStorage
  
  @impl true
  def store_content(content, file_name, options) do
    # Custom storage implementation
    with {:ok, storage_path} <- generate_storage_path(file_name),
         {:ok, metadata} <- store_file(content, storage_path, options) do
      {:ok, %{
        locator_id: storage_path,
        storage_metadata: metadata
      }}
    end
  end
  
  @impl true
  def retrieve_content(locator_id, _options) do
    # Custom retrieval implementation
  end
  
  @impl true
  def delete_content(locator_id, _options) do
    # Custom deletion implementation
  end
end
```

### Background Job Patterns
```elixir
defmodule Kyozo.Storage.Workers.ProcessFileWorker do
  use Oban.Worker, queue: :file_processing, max_attempts: 3
  
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"file_id" => file_id}}) do
    with {:ok, file} <- get_file(file_id),
         {:ok, processed_file} <- process_file_content(file),
         {:ok, _result} <- update_file_metadata(processed_file) do
      :ok
    else
      {:error, reason} -> 
        {:error, reason}
    end
  end
  
  # Schedule job
  def schedule_processing(file_id) do
    %{"file_id" => file_id}
    |> new()
    |> Oban.insert()
  end
end
```

## Real-time Features

### Phoenix Channel Patterns
```elixir
defmodule KyozoWeb.WorkspaceChannel do
  use KyozoWeb, :channel
  
  @impl true
  def join("workspace:" <> workspace_id, _params, socket) do
    if authorized?(socket, workspace_id) do
      send(self(), :after_join)
      {:ok, assign(socket, :workspace_id, workspace_id)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end
  
  @impl true
  def handle_info(:after_join, socket) do
    workspace_id = socket.assigns.workspace_id
    
    # Send current workspace state
    workspace = get_workspace(workspace_id)
    push(socket, "workspace_state", workspace)
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_in("document_change", %{"document_id" => doc_id, "changes" => changes}, socket) do
    # Broadcast changes to other users
    broadcast_from!(socket, "document_updated", %{
      document_id: doc_id,
      changes: changes,
      user: socket.assigns.current_user
    })
    
    {:noreply, socket}
  end
end
```

### LiveView Integration
```elixir
defmodule KyozoWeb.WorkspaceLive do
  use KyozoWeb, :live_view
  
  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      # Subscribe to workspace updates
      Phoenix.PubSub.subscribe(Kyozo.PubSub, "workspace:#{session["team_id"]}")
    end
    
    socket = 
      socket
      |> assign(:workspaces, [])
      |> assign(:loading, true)
    
    {:ok, socket, temporary_assigns: [workspaces: []]}
  end
  
  @impl true
  def handle_info({:workspace_created, workspace}, socket) do
    # Update workspace list
    socket = update(socket, :workspaces, &[workspace | &1])
    {:noreply, socket}
  end
end
```

## Performance Optimization

### Database Query Optimization
```elixir
# Efficient queries with preloading
def list_workspaces_with_stats(team_id) do
  Workspace
  |> Ash.Query.filter(team_id == ^team_id)
  |> Ash.Query.load([
    :created_by,
    :file_count,
    :recent_files
  ])
  |> Ash.read!()
end

# Use calculations for derived data
calculations do
  calculate :file_count, :integer, expr(count(files))
  calculate :last_activity, :utc_datetime_usec, expr(max(files.updated_at))
end
```

### Frontend Performance
```typescript
// Lazy loading with Intersection Observer
export function lazyLoad(node: HTMLElement, src: string) {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        loadComponent(src).then(Component => {
          node.appendChild(Component);
        });
        observer.disconnect();
      }
    });
  });
  
  observer.observe(node);
  
  return {
    destroy() {
      observer.disconnect();
    }
  };
}
```

## Deployment Guide

### Docker Development
```dockerfile
# Dockerfile.dev
FROM elixir:1.14-alpine

# Install dependencies
RUN apk add --no-cache build-base nodejs npm postgresql-client

# Create app directory
WORKDIR /app

# Copy dependency files
COPY mix.exs mix.lock ./
COPY config config

# Install dependencies
RUN mix deps.get

# Copy frontend dependencies
COPY assets/package*.json assets/
RUN cd assets && npm install

# Copy application code
COPY . .

# Compile dependencies
RUN mix deps.compile

EXPOSE 4000
CMD ["mix", "phx.server"]
```

### Production Build
```bash
# Build production assets
cd assets && npm run build

# Build release
MIX_ENV=prod mix release

# Start production server
_build/prod/rel/kyozo/bin/kyozo start
```

### Environment Configuration
```bash
# Production environment variables
export SECRET_KEY_BASE="$(mix phx.gen.secret)"
export DATABASE_URL="postgresql://user:pass@localhost/kyozo_prod"
export PHX_HOST="kyozo.example.com"
export PORT=4000
export MIX_ENV=prod

# AWS S3 configuration
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_S3_BUCKET="kyozo-production"
export AWS_REGION="us-east-1"

# Email configuration
export SMTP_RELAY="smtp.sendgrid.net"
export SMTP_USERNAME="apikey"
export SMTP_PASSWORD="your_sendgrid_api_key"
```

## Debugging and Troubleshooting

### Common Issues

#### Database Connection Issues
```bash
# Check database status
sudo systemctl status postgresql

# Connect to database directly
psql -U postgres -h localhost -d kyozo_dev

# Check migration status
mix ash_postgres.migrate --check
```

#### Frontend Build Issues
```bash
# Clear node modules cache
rm -rf assets/node_modules
cd assets && npm install

# Check for build errors
cd assets && npm run build

# Verify icon imports
grep -r "from 'lucide-svelte'" assets/svelte/
# Should be empty - all imports should be from '@lucide/svelte'
```

#### Phoenix Server Issues
```bash
# Check port availability
lsof -i :4000

# Debug with IEx
iex -S mix phx.server

# Check logs
tail -f phoenix.log
```

### Debugging Tools
```elixir
# Add debugging to any function
def my_function(params) do
  require IEx; IEx.pry() # Breakpoint
  
  IO.inspect(params, label: "Input params")
  
  result = do_something(params)
  
  IO.inspect(result, label: "Result")
  
  result
end
```

### Performance Profiling
```elixir
# Profile database queries
config :kyozo, Kyozo.Repo,
  log: :info,
  query_cache_ttl: 300_000

# Profile LiveView rendering
def mount(_params, _session, socket) do
  :telemetry.span([:my_app, :live_view, :mount], %{}, fn ->
    # Mount logic
    result = {:ok, socket}
    {result, %{}}
  end)
end
```

## CI/CD Configuration

### GitLab CI Pipeline
```yaml
# .gitlab-ci.yml
stages:
  - test
  - build
  - deploy

variables:
  MIX_ENV: test
  POSTGRES_DB: kyozo_test
  POSTGRES_USER: postgres
  POSTGRES_PASSWORD: password

test:
  stage: test
  image: elixir:1.14
  services:
    - postgres:14
  before_script:
    - mix local.hex --force
    - mix local.rebar --force
    - mix deps.get
    - mix ash.setup
  script:
    - mix test
    - mix credo
    - mix dialyzer
  
build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -t kyozo:$CI_COMMIT_SHA .
    - docker tag kyozo:$CI_COMMIT_SHA kyozo:latest
```

This development guide provides a comprehensive foundation for working with the Kyozo Store codebase, covering all aspects from initial setup through production deployment. Follow these patterns and practices to maintain code quality and system reliability.