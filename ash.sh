#!/bin/bash

DB_NAME="kyozo_dev"

echo "🔧 Enforcing UUID v7 on database: $DB_NAME"

psql -d $DB_NAME <<'EOF'
-- Ensure extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create/Replace UUID v7 function
CREATE OR REPLACE FUNCTION uuid_generate_v7()
RETURNS UUID AS $$
DECLARE
  unix_millis BIGINT;
  uuid_bytes BYTEA;
BEGIN
  unix_millis := (extract(epoch FROM clock_timestamp()) * 1000)::BIGINT;
  uuid_bytes := gen_random_bytes(16);
  
  -- Set timestamp
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

-- Update ALL id columns to use UUID v7
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT table_name, column_name
    FROM information_schema.columns
    WHERE column_name = 'id'
      AND data_type = 'uuid'
      AND table_schema = 'public'
      AND column_default IS DISTINCT FROM 'uuid_generate_v7()'
  LOOP
    EXECUTE format('ALTER TABLE %I ALTER COLUMN %I SET DEFAULT uuid_generate_v7()',
                   r.table_name, r.column_name);
    RAISE NOTICE 'Updated %.%', r.table_name, r.column_name;
  END LOOP;
END $$;

-- Show results
SELECT 
  table_name,
  column_name,
  column_default
FROM information_schema.columns
WHERE data_type = 'uuid'
  AND column_default IS NOT NULL
  AND table_schema = 'public'
ORDER BY table_name;
EOF

echo "✅ UUID v7 enforcement complete!"
