# Shelf.nu on Coolify, with self-hosted Supabase in one compose

```
browser ──https──▶ Caddy ──http──▶ Coolify Traefik ──▶ app:8080      shelf.example.com
                                                   └──▶ gateway:8000  supabase.example.com
gateway ──▶ auth (GoTrue) ─┐
        └─▶ storage ───────┴──▶ db (Supabase Postgres)      app ──▶ db, storage
```

Shelf uses Supabase only for **Auth** and **Storage**, so this is 5 containers instead of Supabase's ~13.
Only official images are used; three get a small layer from this repo, built by Coolify on deploy.

## Repository structure

Everything lives in **one Git repository**. The subfolders are required: `docker-compose.yml` builds
`./app`, `./db` and `./gateway` by relative path.

```
shelf-coolify/                    ← repo root
├── docker-compose.yml            the stack; Coolify reads this
├── README.md
├── app/                          official Shelf image + start-up
│   ├── Dockerfile
│   ├── entrypoint.sh             runs migrations, then starts Shelf
│   └── ensure-buckets.mjs        creates the 4 storage buckets
├── db/                           official Supabase Postgres + role passwords
│   ├── Dockerfile
│   ├── roles.sql                 passwords for the auth and storage roles
│   └── zz-init-complete.sh       marks first-boot init as finished (healthcheck)
└── gateway/                      official nginx: routes /auth/v1 and /storage/v1
    ├── Dockerfile
    ├── default.conf
    └── email-templates/          6-digit code e-mails sent by Supabase Auth
        ├── confirmation.html     sign-up
        ├── magic_link.html       sign-in
        └── recovery.html         password reset
```

| Service | Base image | Added by this repo |
|---|---|---|
| `db` | `supabase/postgres` | `roles.sql` (passwords for the auth and storage roles) and an init-complete marker for the healthcheck |
| `auth` | `supabase/gotrue` | nothing |
| `storage` | `supabase/storage-api` | nothing |
| `gateway` | `nginx` | routing to Auth and Storage; serves the e-mail templates internally |
| `app` | `ghcr.io/shelf-nu/shelf.nu` | runs Prisma migrations and creates the buckets, then starts Shelf unchanged |

## Variables

Set in Coolify → resource → **Environment Variables**. Coolify lists them automatically from the compose file.

| Variable | Required | Notes |
|---|---|---|
| `ADMIN_EMAIL` | yes | Your account; also receives Shelf's admin notices |
| `SMTP_HOST` | yes | Used by Shelf (invites) **and** Supabase Auth (sign-in codes) |
| `SMTP_FROM_ADDRESS` | yes | Sender address |
| `SMTP_PORT` | | Default `465` (implicit TLS); `587` = STARTTLS |
| `SMTP_USER`, `SMTP_PWD` | | Leave empty for an unauthenticated relay |
| `DISABLE_SIGNUP` | | `false` until you've signed up, then `true` (invites keep working) |
| `APP_NAME` | | Default `Shelf`; used as sender name and in e-mail subjects |
| `MAPTILER_TOKEN` | | Maps stay blank without it |
| `SHELF_VERSION` | | Default `2.3.0`; official image tag |
| `FILE_SIZE_LIMIT` | | Upload limit in bytes, default 50 MB (gateway allows up to 60 MB) |
| `PUBLIC_SCHEME` | | Default `https`; only change for plain-http tests |

**Filled in by Coolify, never by hand:** `SERVICE_FQDN_APP` / `SERVICE_FQDN_GATEWAY` (hostnames of the domains
you set; the public URLs are built from them), `SERVICE_PASSWORD_JWT` (Supabase JWT secret),
`SERVICE_SUPABASEANON_KEY` / `SERVICE_SUPABASESERVICE_KEY` (Supabase keys, signed with that secret) and
`SERVICE_PASSWORD_64_*` (database password, session and invite secrets).

The service order in `docker-compose.yml` is deliberate. Coolify reads it top to bottom, so the domain
declarations and the JWT secret must come before anything that uses them.

## Deploy

1. **DNS:** point `shelf.example.com` and `supabase.example.com` at Caddy.
2. **Caddy** (on the Caddy server, not in this repo), then reload Caddy:
   ```
   shelf.example.com {
   	encode zstd gzip
   	reverse_proxy http://COOLIFY_HOST_IP:80
   }

   supabase.example.com {
   	reverse_proxy http://COOLIFY_HOST_IP:80
   }
   ```
3. **Coolify:** New Resource → your GitHub repo → Build Pack **Docker Compose**, Base Directory `/`,
   Docker Compose Location `/docker-compose.yml`.
4. **Domains** (General tab, per service), **before the first deploy**. Use `http://` (Caddy does TLS) and append
   the *container* port:
   - `app` → `http://shelf.example.com:8080`
   - `gateway` → `http://supabase.example.com:8000`
5. **Variables:** fill in the required ones from the table.
6. **Deploy.** The first boot applies ~300 migrations (a few minutes). The `app` log ends with
   `storage buckets ready` and `starting Shelf`.
7. **Create your account:** open `https://shelf.example.com`, sign up with `ADMIN_EMAIL`, enter the e-mailed code.
8. **Close registration:** set `DISABLE_SIGNUP=true` and redeploy.

### Recommended: let Traefik trust Caddy

Otherwise Traefik replaces Caddy's `X-Forwarded-Proto: https` with `http`. In Coolify → Servers → Proxy →
Configuration, add the following to `command:` and restart the proxy:
```
- '--entrypoints.http.forwardedHeaders.trustedIPs=CADDY_IP/32'
- '--entrypoints.https.forwardedHeaders.trustedIPs=CADDY_IP/32'
```

## Upgrading

- **Shelf:** set `SHELF_VERSION` to a newer tag (https://github.com/Shelf-nu/shelf.nu/releases) and redeploy.
  Migrations run automatically.
- **Supabase images:** bump the tags in `docker-compose.yml` and `db/Dockerfile` in step with upstream's
  `docker/docker-compose.yml`. Never jump Postgres major versions on an existing volume.

## Backups

State lives in three volumes: `db-data` (Postgres), `storage-data` (uploaded files) and `db-config`
(pgsodium key). Back up all three. A `pg_dump` alone loses the photos.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| 404 / "no available server" | Domain missing `:8080` / `:8000`, or the container isn't healthy yet (first boot). |
| Redirect loop / TLS error | Coolify domain set to `https://` instead of `http://`. |
| `app` log: service key empty or rejected | Keys were minted before the JWT secret existed. Delete `SERVICE_SUPABASEANON_KEY` and `SERVICE_SUPABASESERVICE_KEY` in Coolify and redeploy. |
| Sign-in code never arrives | SMTP settings; check the `auth` log. |
| Photos broken / upload fails | Gateway domain not reachable over https, or the Coolify host can't reach its own public domains. |
| URLs look like `https://http://…` | Old Coolify version; update Coolify. |
| `gateway` log: `invalid parameter "resolve"` | nginx older than 1.27.3; keep `nginx:1.28-alpine` or newer. |
| `db` stays unhealthy on first deploy | First-boot init failed; the reason is in the `db` log. Init only runs on an empty volume, so after fixing it delete the `db-data` and `db-config` volumes (or the whole resource) before redeploying. |
| `db` password errors after changing `SERVICE_PASSWORD_64_POSTGRES` | Not supported after first boot; roles keep the original password. |
