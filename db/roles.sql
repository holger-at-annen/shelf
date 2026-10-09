-- Based on supabase/supabase docker/volumes/db/roles.sql (Apache-2.0).
-- Runs once, on an empty data volume. Only the roles this stack logs in with get a password:
--   supabase_auth_admin    -> auth (GoTrue)
--   supabase_storage_admin -> storage
-- (Shelf itself connects as "postgres", whose password Supabase's init sets from POSTGRES_PASSWORD.)
-- Roles for services we don't run (PostgREST, pgbouncer, edge functions) keep no password: no login.
\set pgpass `echo "$POSTGRES_PASSWORD"`

ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_storage_admin WITH PASSWORD :'pgpass';
