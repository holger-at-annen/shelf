# Official Supabase Postgres + the one init script Auth and Storage need.
FROM supabase/postgres:17.6.1.136
COPY roles.sql /docker-entrypoint-initdb.d/init-scripts/99-roles.sql
