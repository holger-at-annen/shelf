# Official Supabase Postgres + role passwords + a marker written when first-boot init has finished.
FROM supabase/postgres:17.6.1.136
COPY roles.sql /docker-entrypoint-initdb.d/init-scripts/99-roles.sql
COPY zz-init-complete.sh /docker-entrypoint-initdb.d/zz-init-complete.sh
