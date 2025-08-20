# Kyozo Store - Container Migrations Guide

## Overview

This guide covers the complete database migration process for adding "Folder as a Service" container orchestration functionality to Kyozo Store. The migrations establish a comprehensive schema for service instances, topology detection, deployment events, and container monitoring.

## Migration Architecture

### Design Principles

- **UUID v7 Primary Keys**: Time-sortable, distributed-friendly identifiers
- **Foreign Key Integrity**: Proper cascade rules and constraints
- **Performance Optimization**: Strategic indexing for high-throughput operations
- **JSONB Flexibility**: Schema-flexible configuration storage
- **Audit Completeness**: Full event trails for compliance and debugging
- **Multi-tenant Isolation**: Team-based access control throughout

### Database Schema Overview

```
┌─────────────────────┐    ┌──────────────────────┐    ┌─────────────────────┐
│   workspaces        │    │  topology_detections │    │  service_instances  │
│   (extended)        │────│                      │────│                     │
│ + container_enabled │    │ - detected_patterns  │    │ - deployment_config │
│ + service_topology  │    │ - confidence_scores  │    │ - resource_limits   │
│ + auto_deploy       │    │ - recommendations    │    │ - scaling_config    │
└─────────────────────┘    └──────────────────────┘    └─────────────────────┘
                                                                    │
        ┌────────────────────┬───────────────────────────────────────┼───────────────────────┐
        │                    │                                       │                       │
┌──────────────────┐  ┌─────────────────┐  ┌────────────────────┐  ┌──────────────────────┐
│ deployment_events│  │ service_metrics │  │ service_dependencies│  │   health_checks      │
│ - event_type     │  │ - metric_type   │  │ - dependency_type   │  │ - check_type         │
│ - event_data     │  │ - value/unit    │  │ - startup_order     │  │ - status/response    │
│ - sequence_num   │  │ - recorded_at   │  │ - env_variable      │  │ - checked_at         │
└──────────────────┘  └─────────────────┘  └────────────────────┘  └──────────────────────┘
                                                    │
                                           ┌────────────────────┐
                                           │ service_permissions│
                                           │ - permission_type  │
                                           │ - granted/revoked  │
                                           │ - user_id          │
                                           └────────────────────┘
```

## Migration Files

### 1. Topology Detections Table

**File**: `002_create_topology_detections.exs`
**Purpose**: Store folder analysis results and service recommendations

```sql
-- Key Features:
- JSONB storage for detected patterns and confidence scores
- Array storage for recommended service configurations
- Timestamp tracking for analysis freshness
- Workspace and team foreign keys for multi-tenancy
- Performance indexes for recent detection queries
```

**Important Fields**:
- `detected_patterns` - Service type patterns with confidence scores
- `recommended_services` - Array of deployment recommendations
- `service_graph` - Inter-service dependency mapping
- `deployment_strategy` - Recommended orchestration approach

### 2. Service Instances Table

**File**: `001_create_service_instances.exs`
**Purpose**: Core container service management and configuration

```sql
-- Key Features:
- Comprehensive service lifecycle management
- JSONB configuration storage for flexibility
- Resource limits and scaling configurations
- Container runtime information tracking
- Multi-column indexes for performance
```

**Important Fields**:
- `deployment_config` - Service-specific deployment settings
- `port_mappings` - Container port to host port mappings
- `resource_limits` - CPU, memory, and storage constraints
- `scaling_config` - Auto-scaling parameters
- `status` - Current service lifecycle state

### 3. Deployment Events Table

**File**: `003_create_deployment_events.exs`
**Purpose**: Complete audit trail for container operations

```sql
-- Key Features:
- Sequence numbering for event ordering
- Rich event data storage in JSONB
- Error tracking with detailed context
- Duration metrics for performance analysis
- Optimized indexes for time-series queries
```

**Event Types**:
- `deployment_started/completed/failed`
- `service_started/stopped/restarted`
- `service_scaled`
- `health_check_passed/failed`
- `configuration_updated`
- `image_built/pushed`

### 4. Service Dependencies Table

**File**: `004_create_service_dependencies.exs`
**Purpose**: Model inter-service relationships and startup ordering

```sql
-- Key Features:
- Directed dependency relationships
- Startup order management
- Environment variable injection
- Connection string templates
- Circular dependency prevention
```

**Dependency Types**:
- `requires` - Hard dependency (service won't start without it)
- `optional` - Soft dependency (service can start, may have degraded functionality)
- `conflicts` - Mutual exclusion (services cannot run together)

### 5. Health Checks Table

**File**: `005_create_health_checks.exs`
**Purpose**: Service health monitoring and availability tracking

```sql
-- Key Features:
- Multiple check types (HTTP, TCP, exec, gRPC, Docker)
- Response time tracking
- Error message capture
- Time-series storage for health trends
- Alerting-optimized indexes
```

**Check Types**:
- `http` - HTTP endpoint health checks
- `tcp` - TCP port connectivity checks
- `exec` - Command execution checks
- `grpc` - gRPC health protocol
- `docker` - Docker container status

### 6. Service Metrics Table

**File**: `006_create_service_metrics.exs`
**Purpose**: Performance metrics collection and monitoring

```sql
-- Key Features:
- Time-series metrics storage
- Multiple metric types with validation
- Value and unit tracking
- Aggregation-optimized indexes
- High-value alerting support
```

**Metric Types**:
- `cpu` - CPU utilization (0.0-1.0)
- `memory` - Memory usage (0.0-1.0)
- `disk` - Disk utilization (0.0-1.0)
- `network` - Network I/O (bytes, packets)
- `requests` - Request counts
- `errors` - Error counts

### 7. Service Permissions Table

**File**: `007_create_service_permissions.exs`
**Purpose**: Granular access control for container operations

```sql
-- Key Features:
- Per-user, per-service permissions
- Grant/revoke tracking
- Permission type validation
- Audit trail with granted_by tracking
- Performance indexes for authorization checks
```

**Permission Types**:
- `deploy_service` - Deploy and update services
- `stop_service` - Stop running services
- `scale_service` - Scale service replicas
- `view_logs` - Access service logs
- `modify_config` - Update service configuration
- `delete_service` - Delete service instances

### 8. Workspace Extensions

**File**: `008_add_container_fields_to_workspaces.exs`
**Purpose**: Extend workspaces with container orchestration settings

**New Fields**:
- `container_enabled` - Enable container functionality
- `service_topology` - Cached service relationship data
- `auto_deploy_enabled` - Automatic deployment on file changes
- `deployment_environment` - Target deployment environment
- `container_registry_url` - Private registry URL
- `default_resource_limits` - Workspace-wide resource defaults

### 9. File Extensions

**File**: `009_add_service_fields_to_files.exs`
**Purpose**: Add service detection metadata to files

**New Fields**:
- `service_metadata` - Detected service configuration
- `is_service_indicator` - File indicates deployable service
- `detected_technologies` - Array of detected tech stack
- `analysis_confidence` - Detection confidence score
- `last_analyzed_at` - Timestamp of last analysis

## Running the Migrations

### Prerequisites

1. **Database Requirements**:
   - PostgreSQL 12+ with UUID extension
   - Core Kyozo tables (workspaces, teams, users, files)
   - Sufficient disk space for indexes (~10% of data size)

2. **Application Requirements**:
   - Elixir 1.15+
   - Phoenix 1.7+
   - Ash Framework 3.0+

### Execution Options

#### Option 1: Automated Migration Runner

```bash
# Run all container migrations in correct order
mix run priv/repo/migrations/containers/run_container_migrations.exs

# Rollback all container migrations
mix run priv/repo/migrations/containers/run_container_migrations.exs --rollback
```

#### Option 2: Individual Migrations

```bash
# Generate standard Ecto migrations
mix ecto.gen.migration create_topology_detections
# Copy content from containers/002_create_topology_detections.exs

mix ecto.gen.migration create_service_instances  
# Copy content from containers/001_create_service_instances.exs

# Continue for each migration...

# Run migrations
mix ecto.migrate
```

#### Option 3: Ash Postgres Integration

```bash
# Generate Ash migrations (recommended)
mix ash_postgres.generate_migrations --name add_containers_domain

# Review generated migrations
ls priv/repo/migrations/

# Apply migrations
mix ecto.migrate
```

### Migration Order

**Critical**: Migrations must run in this exact order due to foreign key dependencies:

1. `topology_detections` (no dependencies)
2. `service_instances` (references topology_detections)
3. `deployment_events` (references service_instances)
4. `service_dependencies` (references service_instances)
5. `health_checks` (references service_instances)
6. `service_metrics` (references service_instances)
7. `service_permissions` (references service_instances, users)
8. Workspace extensions (extends existing table)
9. File extensions (extends existing table)

## Post-Migration Verification

### Database Validation

```sql
-- Verify all tables exist
SELECT schemaname, tablename 
FROM pg_tables 
WHERE tablename LIKE '%service%' OR tablename LIKE '%topology%';

-- Check foreign key constraints
SELECT conname, conrelid::regclass AS table_name, confrelid::regclass AS referenced_table
FROM pg_constraint 
WHERE contype = 'f' AND conname LIKE '%service%';

-- Verify indexes created
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes 
WHERE tablename IN (
  'service_instances', 'topology_detections', 'deployment_events',
  'service_dependencies', 'health_checks', 'service_metrics', 'service_permissions'
);
```

### Application Integration Test

```elixir
# Test domain compilation
mix compile

# Test resource creation
iex -S mix
> Kyozo.Containers.ServiceInstance.create!(%{
    name: "test-service",
    folder_path: "/test",
    service_type: :nodejs,
    workspace_id: workspace_id
  })

# Test topology detection
> Kyozo.Containers.TopologyDetection.analyze_folder!(%{
    workspace_id: workspace_id,
    folder_path: "/test"
  })
```

### Performance Validation

```sql
-- Check index usage
SELECT schemaname, tablename, attname, n_distinct, correlation
FROM pg_stats 
WHERE tablename IN ('service_instances', 'deployment_events')
ORDER BY tablename, attname;

-- Verify constraint enforcement
INSERT INTO service_instances (id, name, folder_path, service_type, workspace_id, team_id) 
VALUES (uuid_generate_v4(), 'test', '/path', 'invalid_type', uuid_generate_v4(), uuid_generate_v4());
-- Should fail with constraint violation
```

## Performance Considerations

### Index Strategy

- **Time-series Indexes**: Optimized for recent data queries
- **Composite Indexes**: Multi-column indexes for common query patterns
- **Partial Indexes**: Conditional indexes for specific use cases
- **GIN Indexes**: Array and JSONB search optimization

### Storage Optimization

- **JSONB Compression**: Automatic compression for large configuration objects
- **Partitioning Ready**: Schema designed for future time-based partitioning
- **Archival Strategy**: Old events can be moved to archive tables

### Query Performance

```sql
-- Optimized queries leverage composite indexes:

-- Get recent deployment events (uses: service_instance_id, occurred_at)
SELECT * FROM deployment_events 
WHERE service_instance_id = $1 AND occurred_at > NOW() - INTERVAL '7 days'
ORDER BY occurred_at DESC;

-- Get service health status (uses: service_instance_id, status)
SELECT * FROM health_checks 
WHERE service_instance_id = $1 AND status = 'healthy'
ORDER BY checked_at DESC LIMIT 1;

-- Get workspace services by status (uses: team_id, workspace_id, status)
SELECT * FROM service_instances 
WHERE team_id = $1 AND workspace_id = $2 AND status = 'running';
```

## Security Considerations

### Access Control

- **Row Level Security**: Team-based isolation through foreign keys
- **Column Permissions**: Sensitive data in separate columns
- **Audit Logging**: All operations tracked in deployment_events

### Data Protection

- **No Plaintext Secrets**: Secrets stored in external vault systems
- **Encrypted Connections**: Database connections use TLS
- **Backup Encryption**: Database backups encrypted at rest

### Input Validation

- **Check Constraints**: Database-level validation for critical fields
- **Length Limits**: Prevent DOS attacks through oversized data
- **Type Safety**: Strict enum validation for status fields

## Troubleshooting

### Common Migration Issues

1. **Foreign Key Violations**:
   ```
   ERROR: insert or update on table "service_instances" violates foreign key constraint
   ```
   **Solution**: Ensure workspace and team records exist before creating services

2. **Index Creation Timeouts**:
   ```
   ERROR: canceling statement due to statement timeout
   ```
   **Solution**: Increase `statement_timeout` or create indexes `CONCURRENTLY`

3. **Constraint Violations**:
   ```
   ERROR: new row for relation "service_instances" violates check constraint "valid_service_type"
   ```
   **Solution**: Verify enum values match constraint definitions

### Performance Issues

1. **Slow Queries on Large Tables**:
   - Check `EXPLAIN ANALYZE` output
   - Verify appropriate indexes are being used
   - Consider adding missing composite indexes

2. **High Memory Usage During Migration**:
   - Run migrations during low-traffic periods
   - Monitor `work_mem` and `maintenance_work_mem` settings
   - Use `VACUUM ANALYZE` after large data changes

### Recovery Procedures

1. **Failed Migration Recovery**:
   ```bash
   # Check migration status
   mix ecto.migrations
   
   # Rollback specific migration
   mix ecto.rollback --to 20240115100200
   
   # Fix issues and re-run
   mix ecto.migrate
   ```

2. **Constraint Violation Cleanup**:
   ```sql
   -- Find invalid records
   SELECT * FROM service_instances WHERE service_type NOT IN ('nodejs', 'python', ...);
   
   -- Clean up invalid data
   UPDATE service_instances SET service_type = 'custom' WHERE service_type NOT IN (...);
   ```

## Maintenance

### Regular Tasks

1. **Index Maintenance**:
   ```sql
   -- Reindex heavily updated tables monthly
   REINDEX TABLE deployment_events;
   REINDEX TABLE health_checks;
   REINDEX TABLE service_metrics;
   ```

2. **Statistics Updates**:
   ```sql
   -- Update table statistics weekly
   ANALYZE service_instances;
   ANALYZE deployment_events;
   ```

3. **Archive Old Data**:
   ```sql
   -- Archive events older than 90 days
   DELETE FROM deployment_events WHERE occurred_at < NOW() - INTERVAL '90 days';
   DELETE FROM health_checks WHERE checked_at < NOW() - INTERVAL '30 days';
   DELETE FROM service_metrics WHERE recorded_at < NOW() - INTERVAL '7 days';
   ```

### Monitoring Queries

```sql
-- Check table sizes
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE tablename LIKE '%service%'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Monitor query performance
SELECT 
  query,
  calls,
  total_time,
  mean_time,
  rows
FROM pg_stat_statements 
WHERE query LIKE '%service_instances%'
ORDER BY total_time DESC;

-- Check index usage
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE schemaname = 'public' AND tablename LIKE '%service%'
ORDER BY idx_scan DESC;
```

## Migration Checklist

### Pre-Migration

- [ ] Database backup completed
- [ ] Sufficient disk space available (20%+ free)
- [ ] Application downtime scheduled (if needed)
- [ ] Team notified of maintenance window
- [ ] Migration scripts validated in staging

### During Migration

- [ ] Monitor CPU and memory usage
- [ ] Watch for lock contention
- [ ] Verify constraint creation progress
- [ ] Check index build status
- [ ] Monitor error logs

### Post-Migration

- [ ] All tables created successfully
- [ ] Foreign keys validated
- [ ] Indexes built and optimized
- [ ] Constraints enforced
- [ ] Application compilation successful
- [ ] Basic functionality tested
- [ ] Performance benchmarks recorded
- [ ] Rollback plan validated

## Conclusion

The Kyozo Store container migrations establish a comprehensive, production-ready foundation for "Folder as a Service" functionality. The schema provides:

- **Scalable Architecture**: Designed for high-throughput container operations
- **Comprehensive Monitoring**: Complete observability into service health and performance
- **Flexible Configuration**: JSONB storage for evolving requirements
- **Security First**: Multi-tenant isolation and audit trails
- **Performance Optimized**: Strategic indexing for fast queries

With these migrations in place, Kyozo Store is ready to transform any folder structure into running containerized services, bringing the vision of "Directory organization IS deployment strategy" to life.