# Official Shelf image + a start-up that does what Shelf's self-hosting docs leave to the operator:
# Prisma migrations and the four Storage buckets. Shelf's own code is unchanged.
ARG SHELF_VERSION=2.3.0
FROM ghcr.io/shelf-nu/shelf.nu:${SHELF_VERSION}

# Prisma's CLI is a dev dependency upstream. It currently survives into the image, but don't rely on it.
ARG PRISMA_VERSION=6.19.3
RUN { [ -x /src/node_modules/.bin/prisma ] || npm install -g "prisma@${PRISMA_VERSION}"; } \
 && test -f /src/apps/webapp/build/server/index.js \
 && ls /src/packages/database/prisma/migrations/*/migration.sql > /dev/null

COPY ensure-buckets.mjs /opt/shelf/ensure-buckets.mjs
COPY --chmod=0755 entrypoint.sh /usr/local/bin/shelf-entrypoint

ENTRYPOINT ["/usr/local/bin/shelf-entrypoint"]
