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
