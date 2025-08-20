-- PostgreSQL initialization script for Kyozo development environment
-- This script sets up the necessary database configuration and extensions

-- Create additional databases for testing and development
CREATE DATABASE kyozo_test;

-- Connect to the main database to set up extensions
\c kyozo_dev;

-- Enable necessary PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Create a function to set updated timestamps
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create indexes for common query patterns
-- These will be used by the Ash framework for efficient queries

-- Performance monitoring view
CREATE OR REPLACE VIEW pg_stat_activity_clean AS
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    client_hostname,
    client_port,
    backend_start,
    xact_start,
    query_start,
    state_change,
    state,
    backend_xmin,
    query,
    backend_type
FROM pg_stat_activity
WHERE state != 'idle'
AND query NOT LIKE '%pg_stat_activity%';

-- Create a user for read-only access (useful for monitoring tools)
CREATE USER kyozo_readonly WITH PASSWORD 'readonly_password';
GRANT CONNECT ON DATABASE kyozo_dev TO kyozo_readonly;
GRANT USAGE ON SCHEMA public TO kyozo_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO kyozo_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO kyozo_readonly;

-- Set up the test database with the same extensions
\c kyozo_test;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Recreate the timestamp function in test database
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions on test database
GRANT CONNECT ON DATABASE kyozo_test TO kyozo_readonly;
GRANT USAGE ON SCHEMA public TO kyozo_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO kyozo_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO kyozo_readonly;

-- Switch back to main database for any additional setup
\c kyozo_dev;

-- Create a simple health check function
CREATE OR REPLACE FUNCTION health_check()
RETURNS json AS $$
BEGIN
    RETURN json_build_object(
        'status', 'healthy',
        'timestamp', NOW(),
        'version', version(),
        'connections', (SELECT count(*) FROM pg_stat_activity)
    );
END;
$$ LANGUAGE plpgsql;

-- Log successful initialization
DO $$
BEGIN
    RAISE NOTICE 'Kyozo PostgreSQL initialization completed successfully';
    RAISE NOTICE 'Available databases: kyozo_dev, kyozo_test';
    RAISE NOTICE 'Extensions installed: uuid-ossp, pg_stat_statements, pg_trgm, btree_gin, btree_gist';
END $$;