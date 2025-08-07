# OpenAPI Generator Usage Guide

This guide shows how to use the enhanced OpenAPI generator to create Ash resources from OpenAPI specifications.

## Overview

The `mix generate_from_openapi` task automatically generates Ash domains and resources from OpenAPI/Swagger specifications. It creates proper Ash resources with attributes, relationships, actions, and database migrations.

## Usage

```bash
mix generate_from_openapi <path_to_openapi_file>
```

### Example with the runme project specification:

```bash
mix generate_from_openapi priv/openapi/runme/project/v1/project.openapi.yaml
```

## What Gets Generated

### 1. Domain Module
Creates a domain module based on the OpenAPI info.title:
- `lib/kyozo/runme_project_v1.ex` (domain)
- Includes JSON API and GraphQL extensions
- Configures authorization

### 2. Resources
For each schema in `components.schemas`, creates:
- Resource module with proper attributes
- Database table configuration
- JSON API and PostgreSQL extensions
- Default actions inferred from paths

### 3. Relationships
Automatically detects and creates:
- `belongs_to` for `$ref` properties
- `has_many` for array properties with `$ref` items
- Proper foreign key constraints

### 4. Actions
Infers actions from OpenAPI paths:
- `POST /resources` → `create` action
- `GET /resources` or `GET /resources/{id}` → `read` action
- `PATCH/PUT /resources/{id}` → `update` action
- `DELETE /resources/{id}` → `destroy` action

## Type Mapping

The generator maps OpenAPI types to appropriate Ash types:

| OpenAPI Type | Format | Ash Type |
|--------------|--------|----------|
| `string` | - | `string` |
| `string` | `date-time` | `utc_datetime_usec` |
| `string` | `date` | `date` |
| `string` | `email` | `ci_string` |
| `string` | `uuid` | `uuid` |
| `string` | `enum` | `atom` |
| `integer` | - | `integer` |
| `integer` | `int64` | `integer` |
| `number` | - | `decimal` |
| `boolean` | - | `boolean` |
| `object` | - | `map` |
| `array` | - | `{:array, :subtype}` |
| `oneOf/anyOf` | - | `union` |

## Generated Example

For the runme project specification, this would generate:

```
lib/kyozo/runme_project_v1/
├── runme_project_v1.ex                    # Domain
├── load_request.ex                        # LoadRequest resource
├── load_response.ex                       # LoadResponse resource
├── directory_project_options.ex           # DirectoryProjectOptions resource
├── file_project_options.ex               # FileProjectOptions resource
├── load_event_error.ex                   # LoadEventError resource
└── ... (other schema resources)
```

## Advanced Features

### 1. Attribute Modifiers
- Automatically adds `:public` to all attributes for API exposure
- Adds `:required` for fields in the OpenAPI `required` array
- Handles format-specific constraints (email, UUID, etc.)

### 2. Relationship Detection
- Detects `$ref` references and creates proper relationships
- Handles nested array relationships
- Generates proper foreign key constraints

### 3. Action Inference
- Analyzes OpenAPI paths to determine available operations
- Creates appropriate Ash actions with proper HTTP method mapping
- Falls back to default CRUD actions if no paths are found

### 4. Error Handling
- Gracefully handles missing schemas or malformed specifications
- Provides detailed error messages for debugging
- Continues generation even if individual resources fail

## Integration with Existing Projects

### 1. Domain Configuration
Add the generated domain to your application configuration:

```elixir
# config/config.exs
config :kyozo,
  ash_domains: [
    Kyozo.Files,
    Kyozo.Accounts,
    Kyozo.Storage,
    Kyozo.Workspace,
    Kyozo.RunmeProjectV1  # Add generated domain
  ]
```

### 2. Router Integration
Add routes for the generated resources:

```elixir
# lib/kyozo_web/router.ex
scope "/api/v1" do
  pipe_through :api

  # Generated JSON API routes
  forward "/runme", AshJsonApi.Router,
    domains: [Kyozo.RunmeProjectV1],
    json_schema: "/api/v1/runme/schema"
end
```

### 3. GraphQL Integration
```elixir
# lib/kyozo_web/schema.ex
defmodule KyozoWeb.Schema do
  use Absinthe.Schema

  @domains [
    Kyozo.Files,
    Kyozo.Accounts,
    Kyozo.RunmeProjectV1  # Add generated domain
  ]

  use AshGraphql, domains: @domains
end
```

## Post-Generation Steps

After running the generator:

### 1. Review Generated Code
```bash
# Check generated domain and resources
ls lib/kyozo/runme_project_v1/
```

### 2. Generate Migrations
```bash
# Generate database migrations
mix ash.codegen runme_project_generated

# Review migrations
ls priv/repo/migrations/
```

### 3. Run Migrations
```bash
# Apply database changes
mix ash.migrate
```

### 4. Validate Generation
```bash
# Test compilation
mix compile

# Verify resources work
iex -S mix
iex> Kyozo.RunmeProjectV1.list_load_requests!()
```

## Customization After Generation

### 1. Add Business Logic
```elixir
# Add custom actions to generated resources
defmodule Kyozo.RunmeProjectV1.LoadRequest do
  # ... generated code ...

  actions do
    # ... generated actions ...

    # Add custom action
    create :load_with_validation do
      accept [:path, :options]
      change {MyApp.Changes.ValidateProjectPath, []}
    end
  end
end
```

### 2. Add Relationships
```elixir
# Connect generated resources to existing resources
relationships do
  # ... generated relationships ...

  belongs_to :user, Kyozo.Accounts.User do
    allow_nil? false
  end
end
```

### 3. Add Authorization
```elixir
policies do
  policy action_type(:read) do
    authorize_if relates_to_actor_via(:user)
  end

  policy action_type(:create) do
    authorize_if actor_present()
  end
end
```

## Best Practices

### 1. Review Before Using
- Always review generated code before committing
- Check that relationships make sense for your domain
- Verify that type mappings are appropriate

### 2. Incremental Generation
- Generate resources incrementally to avoid conflicts
- Use `--ignore-if-exists` to prevent overwriting customizations
- Keep track of manual changes vs generated code

### 3. Testing
- Write tests for generated resources
- Verify that API endpoints work as expected
- Test relationships and constraints

### 4. Documentation
- Document any customizations made after generation
- Keep track of OpenAPI spec changes
- Update generated resources when spec changes

## Troubleshooting

### Common Issues

1. **Missing Dependencies**
   ```bash
   # Ensure required packages are installed
   mix deps.get
   ```

2. **Invalid OpenAPI Spec**
   ```bash
   # Validate your OpenAPI specification first
   # Use online validators or swagger-codegen validate
   ```

3. **Compilation Errors**
   ```bash
   # Fix any generated code issues
   mix compile
   # Check generated files for syntax errors
   ```

4. **Migration Failures**
   ```bash
   # Check for database conflicts
   mix ash.codegen --dry-run
   # Review generated migrations before applying
   ```

### Getting Help

- Check generated code for comments and TODOs
- Review Ash Framework documentation for advanced features
- Use `mix ash.gen.resource --help` for generator options
- Reference the original OpenAPI specification for business logic

This generator provides a solid starting point for creating Ash resources from OpenAPI specifications, but manual refinement is often needed to match your specific business requirements.
