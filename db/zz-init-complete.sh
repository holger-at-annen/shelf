#!/bin/sh
# Last first-boot step: runs only if Supabase's migrate.sh (init scripts + migrations) succeeded,
# because the entrypoint stops at the first failing init file. The healthcheck requires this marker,
# so a half-initialised database shows up as unhealthy instead of breaking auth/storage later.
touch "$PGDATA/.init-complete"
