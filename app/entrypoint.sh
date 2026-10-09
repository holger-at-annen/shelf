#!/bin/sh
# 1. apply Shelf's Prisma migrations   2. ensure Storage buckets   3. start Shelf
set -eu
log() { printf '[shelf] %s\n' "$*"; }

: "${DIRECT_URL:=$DATABASE_URL}"
export DIRECT_URL

PRISMA=/src/node_modules/.bin/prisma
[ -x "$PRISMA" ] || PRISMA=prisma
SCHEMA=/src/packages/database/prisma/schema.prisma

log "applying database migrations"
i=0
# Run outside the repo so Prisma uses only --schema (no prisma.config.ts / dotenv needed).
until (cd /tmp && "$PRISMA" migrate deploy --schema "$SCHEMA"); do
  i=$((i + 1))
  [ "$i" -lt 20 ] || { log "FATAL: migrations failed; refusing to start on a partial schema"; exit 1; }
  log "migrations not applied yet, retrying in 5s ($i/20)"
  sleep 5
done

node /opt/shelf/ensure-buckets.mjs

log "starting Shelf on port ${PORT:-8080}"
cd /src/apps/webapp
exec node ./build/server/index.js
