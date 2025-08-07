# AshOban Integration with Storage Resources

This document explains how AshOban has been integrated with the Kyozo storage system to provide background job processing with proper actor persistence and authorization.

## Overview

The Kyozo storage system now includes AshOban integration that provides:

- **Background job processing** for resource-intensive storage operations
- **Actor persistence** ensuring original user context is maintained in background jobs
- **Proper authorization** with policies that allow both interactive and background job access
- **Queue management** with dedicated queues for different types of storage operations
- **Job monitoring** and management utilities

## Architecture

### Key Components

1. **Storage Resource (`Kyozo.Storage.StorageResource`)**
   - Extended with AshOban extension
   - Contains background job actions for async operations
   - Implements proper policies for job authorization

2. **Actor Persister (`Kyozo.Storage.ActorPersister`)**
   - Handles serialization/deserialization of actors for background jobs
   - Supports User, ApiKey, system, and generic actor types
   - Ensures actor context is preserved across job execution

3. **Storage Domain (`Kyozo.Storage`)**
   - Extended with AshOban.Domain extension
   - Provides utility functions for scheduling jobs
   - Includes job monitoring and management functions

4. **Configuration**
   - AshOban queues configured for different storage operations
   - Actor persister configured globally
   - Domain included in ash_domains configuration

## Background Job Actions

### Available Background Jobs

#### 1. Process Storage (`process_storage_async`)
Processes storage content asynchronously using the appropriate backend.

**Arguments:**
- `content` (string) - Content to store
- `storage_options` (map) - Backend-specific options

**Usage:**
```elixir
# Schedule via domain utility function
{:ok, job} = Kyozo.Storage.process_storage_async(storage_resource, content,
  storage_options: %{compression: true},
  actor: current_user,
  delay: 30  # Optional delay in seconds
)
```

#### 2. Cleanup Content (`cleanup_content_async`)
Cleans up storage content from the backend, typically used during deletion.

**Arguments:** None (uses storage resource data)

**Usage:**
```elixir
# Schedule via domain utility function
{:ok, job} = Kyozo.Storage.cleanup_content_async(storage_resource,
  actor: current_user,
  delay: 60  # Clean up after 1 minute
)
```

#### 3. Create Version (`create_version_async`)
Creates a new version of storage content for versioned backends.

**Arguments:**
- `content` (string, required) - New content version
- `version_name` (string, optional) - Custom version name
- `commit_message` (string, optional) - Version description

**Usage:**
```elixir
# Schedule via domain utility function
{:ok, job} = Kyozo.Storage.create_version_async(storage_resource, content,
  version_name: "v2.0",
  commit_message: "Major update with new features",
  actor: current_user
)
```

### Direct AshOban Scheduling

You can also schedule jobs directly using AshOban:

```elixir
# Direct scheduling with AshOban
args = %{content: "new content", storage_options: %{}}
{:ok, job} = AshOban.schedule(storage_resource, :process_storage_async, args,
  actor: current_user,
  queue: :storage_processing,
  delay: 60
)
```

## Actor Persistence

### Supported Actor Types

The `Kyozo.Storage.ActorPersister` handles the following actor types:

1. **User Actors** (`Kyozo.Accounts.User`)
2. **API Key Actors** (`Kyozo.Accounts.ApiKey`)
3. **System Actors** (maps with `system: true`)
4. **Generic Actors** (any map)
5. **No Actor** (`nil`)

### Actor Serialization

Actors are serialized to JSON format for storage with job data:

```elixir
# User actor stored as:
%{
  "type" => "Kyozo.Accounts.User",
  "id" => user_id
}

# System actor stored as:
%{
  "type" => "system",
  "data" => %{system: true, ...}
}
```

### Actor Lookup

During job execution, actors are reconstructed by:

1. Looking up the actor by ID from the database
2. Returning an error if the actor no longer exists
3. Providing the reconstructed actor to the job action

## Authorization & Policies

### Policy Configuration

The storage resource includes policies that allow both interactive and background job access:

```elixir
policies do
  # Allow AshOban to trigger background jobs with preserved actor context
  bypass AshOban.Checks.AshObanInteraction do
    authorize_if always()
  end

  # Standard policies for interactive access
  policy action_type(:read) do
    authorize_if always()
  end

  policy action_type([:create, :update]) do
    authorize_if actor_present()
  end

  policy action_type(:destroy) do
    authorize_if actor_present()
  end

  # Background job actions
  policy action([:process_storage_async, :cleanup_content_async, :create_version_async]) do
    authorize_if AshOban.Checks.AshObanInteraction  # Allow background jobs
    authorize_if actor_present()                    # Allow manual triggering
  end
end
```

### Authorization Flow

1. **Interactive Actions**: Require authenticated actor
2. **Background Jobs**:
   - Executed with `AshOban.Checks.AshObanInteraction` check
   - Original actor context is preserved and available
   - Authorization policies are enforced with original actor

## Queue Configuration

### Configured Queues

The following Oban queues are configured for storage operations:

```elixir
config :kyozo, Oban,
  queues: [
    default: 10,
    storage_processing: 5,  # For process_storage_async jobs
    storage_cleanup: 3,     # For cleanup_content_async jobs
    storage_versioning: 2   # For create_version_async jobs
  ]
```

### Queue Characteristics

- **storage_processing**: High priority, handles content processing
- **storage_cleanup**: Medium priority, handles resource cleanup
- **storage_versioning**: Lower priority, handles version creation

## Job Monitoring & Management

### Get Job Status

Monitor background jobs for a storage resource:

```elixir
# Get recent job status
{:ok, jobs} = Kyozo.Storage.get_job_status(storage_resource)

jobs
|> Enum.each(fn job ->
  IO.puts "Job #{job.id}: #{job.state} (#{job.attempt}/#{job.max_attempts})"
  if job.errors, do: IO.inspect(job.errors, label: "Errors")
end)
```

Returns job information including:
- Job ID, queue, and worker
- Current state (available, executing, completed, etc.)
- Attempt count and maximum attempts
- Any error information
- Timestamps for insertion, attempts, and completion

### Cancel Jobs

Cancel pending jobs for a storage resource:

```elixir
# Cancel all pending jobs
{:ok, cancelled_count} = Kyozo.Storage.cancel_jobs(storage_resource)
IO.puts "Cancelled #{cancelled_count} pending jobs"
```

This cancels jobs in 'available' or 'scheduled' state. Running jobs cannot be cancelled.

## Configuration

### Required Configuration

1. **Add Storage domain to ash_domains:**
```elixir
config :kyozo,
  ash_domains: [Kyozo.Accounts, Kyozo.Workspaces, Kyozo.Projects, Kyozo.Storage]
```

2. **Configure actor persister:**
```elixir
config :ash_oban, :actor_persister, Kyozo.Storage.ActorPersister
```

3. **Configure Oban queues:**
```elixir
config :kyozo, Oban,
  queues: [
    default: 10,
    storage_processing: 5,
    storage_cleanup: 3,
    storage_versioning: 2
  ]
```

4. **Update Application supervision tree:**
```elixir
{Oban, AshOban.config(Application.fetch_env!(:kyozo, :ash_domains), oban_config)}
```

### Optional Configuration

- **Configure AshOban Pro** (if using Oban Pro):
```elixir
config :ash_oban, pro?: true
```

## Usage Examples

### Complete Workflow Example

```elixir
# 1. Create storage resource
{:ok, storage_resource} = Kyozo.Storage.create_storage_entry(%{
  file_name: "document.md",
  storage_backend: :git
}, content: "# My Document\n\nContent here...")

# 2. Schedule background processing
{:ok, process_job} = Kyozo.Storage.process_storage_async(
  storage_resource,
  "# Updated Document\n\nNew content...",
  actor: current_user,
  storage_options: %{branch: "main"}
)

# 3. Create a version asynchronously
{:ok, version_job} = Kyozo.Storage.create_version_async(
  storage_resource,
  "# Version 2\n\nSignificant updates...",
  version_name: "v2.0",
  commit_message: "Major content revision",
  actor: current_user
)

# 4. Monitor job progress
{:ok, jobs} = Kyozo.Storage.get_job_status(storage_resource)
IO.inspect(jobs, label: "Current jobs")

# 5. Later, schedule cleanup when resource is deleted
{:ok, cleanup_job} = Kyozo.Storage.cleanup_content_async(
  storage_resource,
  actor: current_user,
  delay: 300  # Clean up after 5 minutes
)
```

### Error Handling

```elixir
case Kyozo.Storage.process_storage_async(storage_resource, content, actor: current_user) do
  {:ok, job} ->
    Logger.info("Scheduled storage processing job: #{job.id}")

  {:error, reason} ->
    Logger.error("Failed to schedule job: #{inspect(reason)}")
    # Handle error appropriately
end
```

## Best Practices

### When to Use Background Jobs

1. **Large file processing** - Files over 1MB should be processed asynchronously
2. **Version creation** - Always async for Git backend operations
3. **Storage cleanup** - Schedule with delay to allow for rollback scenarios
4. **Bulk operations** - When processing multiple storage resources

### Job Scheduling Guidelines

1. **Always provide actor** - Ensures proper authorization in background jobs
2. **Use appropriate delays** - Cleanup jobs should have delays for safety
3. **Monitor job status** - Implement job monitoring for critical operations
4. **Handle failures gracefully** - Jobs may fail due to external dependencies

### Security Considerations

1. **Actor validation** - The actor persister validates that actors still exist
2. **Permission inheritance** - Background jobs inherit original actor permissions
3. **Audit logging** - All background job actions are logged with original actor context
4. **Resource access** - Jobs can only access resources the original actor could access

## Troubleshooting

### Common Issues

1. **Actor lookup failures** - Actor may have been deleted between scheduling and execution
2. **Storage provider errors** - Backend storage systems may be unavailable
3. **Authorization failures** - Actor permissions may have changed

### Debugging

1. **Check job status:**
```elixir
{:ok, jobs} = Kyozo.Storage.get_job_status(storage_resource)
failed_jobs = Enum.filter(jobs, & &1.state == "retryable" or &1.state == "discarded")
```

2. **Review job errors:**
```elixir
if job.errors do
  IO.inspect(job.errors, label: "Job errors", pretty: true)
end
```

3. **Check actor persistence:**
```elixir
# Test actor serialization/deserialization
stored = Kyozo.Storage.ActorPersister.store(current_user)
{:ok, retrieved} = Kyozo.Storage.ActorPersister.lookup(stored)
```

## Migration Guide

If you're migrating from synchronous storage operations to background jobs:

1. **Update calling code** to schedule jobs instead of direct calls
2. **Add job monitoring** to track operation completion
3. **Handle asynchronous results** appropriately in your UI
4. **Test actor persistence** with your specific actor types
5. **Configure appropriate queue sizes** based on your usage patterns

This integration provides a robust foundation for scalable storage operations while maintaining security and auditability through proper actor persistence.
