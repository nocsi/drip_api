#!/bin/bash

echo "🔥 NUCLEAR UUID v7 RESET FOR ASH/PHOENIX 🔥"
echo "================================================"
echo "This will DELETE:"
echo "  - All migrations"
echo "  - All tenant migrations"
echo "  - All resource snapshots"
echo "  - The entire database"
echo ""
echo "Press Ctrl+C to abort, or Enter to continue..."
read

# Backup first (just in case)
echo "📦 Creating backups..."
mkdir -p backups/$(date +%Y%m%d_%H%M%S)
cp -r priv/repo/migrations backups/$(date +%Y%m%d_%H%M%S)/ 2>/dev/null || true
cp -r priv/repo/tenant_migrations backups/$(date +%Y%m%d_%H%M%S)/ 2>/dev/null || true
cp -r priv/resource_snapshots backups/$(date +%Y%m%d_%H%M%S)/ 2>/dev/null || true
pg_dump kyozo_dev >backups/$(date +%Y%m%d_%H%M%S)/schema.sql 2>/dev/null || true

echo "💣 Dropping database..."
mix ecto.drop

echo "🗑️  Removing ALL migrations and snapshots..."
rm -rf ./priv/repo/migrations/*
rm -rf ./priv/repo/tenant_migrations/*
rm -rf ./priv/resource_snapshots/*

echo "✨ Creating fresh database..."
mix ecto.create

echo "🔧 Installing UUID v7 function..."
psql -d kyozo_dev <<'EOF'
-- Essential extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Create UUID v7 function
CREATE OR REPLACE FUNCTION uuid_generate_v7()
RETURNS UUID AS $$
DECLARE
  unix_millis BIGINT;
  uuid_bytes BYTEA;
BEGIN
  unix_millis := (extract(epoch FROM clock_timestamp()) * 1000)::BIGINT;
  uuid_bytes := gen_random_bytes(16);
  
  -- Set timestamp (48 bits)
  uuid_bytes := set_byte(uuid_bytes, 0, (unix_millis >> 40)::BIT(8)::INT);
  uuid_bytes := set_byte(uuid_bytes, 1, (unix_millis >> 32)::BIT(8)::INT);
  uuid_bytes := set_byte(uuid_bytes, 2, (unix_millis >> 24)::BIT(8)::INT);
  uuid_bytes := set_byte(uuid_bytes, 3, (unix_millis >> 16)::BIT(8)::INT);
  uuid_bytes := set_byte(uuid_bytes, 4, (unix_millis >> 8)::BIT(8)::INT);
  uuid_bytes := set_byte(uuid_bytes, 5, unix_millis::BIT(8)::INT);
  
  -- Set version and variant
  uuid_bytes := set_byte(uuid_bytes, 6, 
    ((substring(uuid_bytes FROM 7 FOR 1)::BIT(8) & b'00001111') | b'01110000')::BIT(8)::INT
  );
  uuid_bytes := set_byte(uuid_bytes, 8, 
    ((substring(uuid_bytes FROM 9 FOR 1)::BIT(8) & b'00111111') | b'10000000')::BIT(8)::INT
  );
  
  RETURN encode(uuid_bytes, 'hex')::UUID;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- Ash wrapper function
CREATE OR REPLACE FUNCTION ash_uuidv7_generate()
RETURNS UUID AS $$
  SELECT uuid_generate_v7();
$$ LANGUAGE SQL VOLATILE;

-- Test it
SELECT uuid_generate_v7() as "Test UUID v7";
EOF

echo "📝 Creating config enforcer..."
cat >config/uuid_v7.exs <<'EOF'
# This file ensures UUID v7 everywhere
import Config

config :kyozo, Kyozo.Repo,
  migration_primary_key: [
    name: :id,
    type: :uuid,
    default: {:fragment, "uuid_generate_v7()"}
  ],
  migration_foreign_key: [type: :uuid],
  migration_timestamps: [type: :utc_datetime_usec]

config :ash, :default_uuid_version, :v7
EOF

echo "🔄 Generating fresh Ash migrations..."
mix ash_postgres.generate_migrations --name initial_schema

echo "📋 Creating post-migration UUID enforcer..."
cat >enforce_uuid_v7_post_migration.sql <<'EOF'
-- Run this after migrations to ensure EVERYTHING uses UUID v7
DO $$
DECLARE
  r RECORD;
  cmd TEXT;
BEGIN
  -- Update all UUID primary keys
  FOR r IN 
    SELECT 
      c.table_name, 
      c.column_name,
      c.column_default
    FROM information_schema.columns c
    JOIN information_schema.table_constraints tc 
      ON c.table_name = tc.table_name
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
      AND c.column_name = kcu.column_name
    WHERE c.data_type = 'uuid'
      AND tc.constraint_type = 'PRIMARY KEY'
      AND c.table_schema = 'public'
      AND (c.column_default IS NULL OR c.column_default != 'uuid_generate_v7()')
  LOOP
    cmd := format('ALTER TABLE %I ALTER COLUMN %I SET DEFAULT uuid_generate_v7()',
                  r.table_name, r.column_name);
    EXECUTE cmd;
    RAISE NOTICE 'Updated %.% to UUID v7', r.table_name, r.column_name;
  END LOOP;
  
  -- Report
  RAISE NOTICE '';
  RAISE NOTICE 'UUID v7 Enforcement Complete!';
  RAISE NOTICE '============================';
  
  FOR r IN
    SELECT table_name, column_name, column_default
    FROM information_schema.columns
    WHERE data_type = 'uuid'
      AND column_default IS NOT NULL
      AND table_schema = 'public'
    ORDER BY table_name
  LOOP
    RAISE NOTICE '% . % -> %', 
      rpad(r.table_name, 30), 
      rpad(r.column_name, 15),
      r.column_default;
  END LOOP;
END $$;
EOF

echo ""
echo "✅ CLEANUP COMPLETE!"
echo ""
echo "Next steps:"
echo "1. Update your repo.ex to include UUID v7 config"
echo "2. Run: mix ecto.migrate"
echo "3. Run: psql -d kyozo_dev < enforce_uuid_v7_post_migration.sql"
echo "4. Verify with: mix run check_uuids.exs"
echo ""
