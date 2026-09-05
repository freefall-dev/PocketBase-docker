# PocketBase Docker

Minimal, production-minded Docker images for [PocketBase](https://pocketbase.io/), shipped in two flavors:

- **Rootless** (default, recommended) — runs as a dedicated non-root `pb` user.
- **Root** — runs as `root`, for environments where that's simpler or required.

Both use a multi-stage Alpine build that downloads a pinned PocketBase release, **verifies its SHA-256 checksum** against the published `checksums.txt`, and ships only the binary in the runtime image. An entrypoint script optionally bootstraps the superuser and enables settings encryption on every start.

## Features

- 🪶 Small Alpine-based image, multi-stage build (only the `pocketbase` binary in the final layer).
- 🔒 Checksum verification of the downloaded release during build.
- 👤 Rootless and root variants, kept isolated via distinct Compose project names.
- 🌱 Idempotent superuser bootstrap — creates the admin only if it doesn't already exist.
- 🔑 Optional settings encryption via a 32-character key.
- 🏗️ Multi-arch (`amd64` / `arm64`) via buildx `TARGETARCH`.
- ❤️ Built-in `HEALTHCHECK` hitting `/api/health`.
- 💾 Persistent `pb_data` volume for the SQLite database and uploads.

## Requirements

- Docker with Compose v2 (`docker compose`).
- Optionally buildx for multi-arch builds.

## Quick start

```bash
# 1. Configure
cp .env.example .env
# edit .env — at minimum set PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD to bootstrap an admin

# 2. Build & run (rootless variant, default)
docker compose -f docker-compose.rootless.yml up -d --build

# 3. Open the admin UI
#    http://localhost:8070/_/
```

For the root variant:

```bash
docker compose -f docker-compose.root.yml up -d --build
```

The two stacks use separate Compose project names (`pocketbase` vs `pocketbase-root`), so their containers and volumes stay isolated and can run side by side.

## Configuration

Copy `.env.example` to `.env` and adjust. Compose reads `.env` automatically; **keep it out of version control** (already covered by `.gitignore`).

| Variable | Default | Description |
|---|---|---|
| `PB_VERSION` | `0.40.2` | PocketBase release to build (published tag without the leading `v`). |
| `CONTAINER_NAME` | `pocketbase` | Base name for the container. |
| `PB_PORT` | `8070` | Port for the rootless stack (used inside the container and for the host mapping). |
| `PB_PORT_ROOT` | `8070` | Port for the root stack. |
| `PB_ADMIN_EMAIL` | *(empty)* | Superuser email to bootstrap. Leave blank to skip bootstrapping. |
| `PB_ADMIN_PASSWORD` | *(empty)* | Superuser password. Required only when the admin doesn't yet exist. |
| `PB_ENCRYPTION_KEY` | *(empty)* | Settings-encryption key. Must be **exactly 32 characters**. Leave blank to disable. |

### Superuser bootstrap

On every start the entrypoint checks whether `PB_ADMIN_EMAIL` already exists in the database:

- **exists** → nothing happens (`PB_ADMIN_PASSWORD` is ignored).
- **missing** → the superuser is created using `PB_ADMIN_PASSWORD` (required in that case, otherwise the container exits with an error).
- `PB_ADMIN_EMAIL` blank → bootstrap is skipped entirely.

### Settings encryption

To encrypt application settings stored in the database, set a 32-character `PB_ENCRYPTION_KEY`. Generate one with:

```bash
openssl rand -hex 16
```

The entrypoint validates the length and passes `--encryptionEnv=PB_ENCRYPTION_KEY` to PocketBase. See the [PocketBase production docs](https://pocketbase.io/docs/going-to-production/#enable-settings-encryption).

## Data persistence

The SQLite database and uploaded files live in `/pb/pb_data`, backed by the named Docker volume `pb_data`. Data survives container recreation. To develop migrations/hooks against the running instance, uncomment the bind mounts in the Compose file:

```yaml
# - ./pb_migrations:/pb/pb_migrations
# - ./pb_hooks:/pb/pb_hooks
```

You can also bake `pb_migrations` / `pb_hooks` into the image by uncommenting the corresponding `COPY` lines in the Dockerfile.

## Building for a specific version or architecture

```bash
# pin a version
PB_VERSION=0.40.2 docker compose -f docker-compose.rootless.yml build

# multi-arch build with buildx
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg PB_VERSION=0.40.2 \
  -f Dockerfile.rootless \
  -t pocketbase:0.40.2 .
```

## Health check

Both images define a `HEALTHCHECK` that polls `http://127.0.0.1:${PB_PORT}/api/health`. Check status with:

```bash
docker ps
docker inspect --format '{{.State.Health.Status}}' pocketbase
```

## Managing the stack

```bash
# logs
docker compose -f docker-compose.rootless.yml logs -f

# stop
docker compose -f docker-compose.rootless.yml down

# stop and remove the data volume (destroys the database!)
docker compose -f docker-compose.rootless.yml down -v
```

## Project layout

```
.
├── Dockerfile.rootless          # non-root image (default)
├── Dockerfile.root              # root image
├── docker-compose.rootless.yml  # rootless stack (project: pocketbase)
├── docker-compose.root.yml      # root stack (project: pocketbase-root)
├── entrypoint.rootless.sh       # bootstrap + serve (non-root)
├── entrypoint.root.sh           # bootstrap + serve (root)
├── .env.example                 # configuration template
├── .gitattributes               # forces LF endings for shell/Docker files
└── .gitignore
```

> **Note:** shell scripts and Dockerfiles must keep LF line endings (enforced via `.gitattributes`) — CRLF endings break execution inside the Linux container.

## License

PocketBase is distributed under its own [license](https://github.com/pocketbase/pocketbase/blob/master/LICENSE.md). This repository contains only the Docker packaging.
