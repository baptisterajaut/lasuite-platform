# Known Limitations

This document lists limitations of the current deployment that may affect your usage.

## Image Versioning

### Chart Version vs Image Version

La Suite Helm charts default to `image.tag: latest`, which is not reproducible. This helmfile pins image versions explicitly.

**How it works**:
- By default, image tags are derived from chart versions: `v{laSuiteChartVersions.X}`
- When chart and app versions differ, use `laSuiteImageVersions` in `versions/lasuite-helm-versions.yaml`

| App | Chart Version | Image Tag | Source |
|-----|---------------|-----------|--------|
| Docs | 5.2.1 | v5.2.1 | Derived from `laSuiteChartVersions.docs` |
| Drive | 0.18.0 | v0.18.0 | Derived from `laSuiteChartVersions.drive` |
| Meet | 0.0.23 | v1.19.0 | Explicit in `laSuiteImageVersions.meet` |
| People | 0.0.7 | latest | No published version tags |
| Conversations | 0.0.5 | latest | No published version tags |
| Find | 0.0.3 | main | Published as `lasuite/find` (not `find-backend`) |

### Meet Version Mismatch

Meet's Helm chart version (`0.0.x`) does not match its app version (`v1.x`). This requires an explicit `laSuiteImageVersions.meet` entry.

When updating Meet:
1. Check latest chart version: `helm search repo meet/meet --versions`
2. Check latest image tag: https://hub.docker.com/r/lasuite/meet-backend/tags
3. Update both `laSuiteChartVersions.meet` and `laSuiteImageVersions.meet` in `versions/lasuite-helm-versions.yaml`

### Bitnami images pinned to `latest`

PostgreSQL and Redis use the Bitnami charts' default image, which resolves to `docker.io/bitnami/{postgresql,redis}:latest`. This is not a deliberate choice: since the August 2025 catalog change, Bitnami's free tier only publishes `latest`. All versioned tags moved to the frozen `docker.io/bitnamilegacy` repo, and the maintained versioned catalog now requires the paid Bitnami Secure Images subscription. So it's `latest` or nothing without paying.

`latest` still pulls anonymously, so nothing is broken — but it is a moving, unpinned target, unlike every other image in this deployment.

**Footgun**: `latest` on a *stateful* PostgreSQL means a future major-version bump in `latest` can leave a restarting pod unable to start on an existing data directory (PostgreSQL refuses to start on a `PGDATA` from a different major version). Redis is only used as a cache/broker, so it is unaffected.

The intended long-term fix is to drop Bitnami entirely (e.g. PostgreSQL → CloudNativePG, Redis → official image or Valkey). Held off for now because this repo doubles as a dekube/compose source, where operators and CRDs transpile poorly.

## Waffle/Gaufre Menu

The waffle (gaufre) is the app navigation menu showing links to other La Suite apps.

### Docs

Since v4.5.0, the waffle is configurable via `backend.themeCustomization`. The helmfile configures it with local URLs pointing to deployed apps.

Since v4.6.0, the header icon, logo, and favicon are also part of the `themeCustomization` JSON (keys: `header.icon`, `header.logo`, `favicon.light`, `favicon.dark`). The helmfile does not override these — the defaults from the image work out of the box. For custom branding, add these keys to `file_content` in `values/docs.yaml.gotmpl`. See the upstream default: `src/backend/impress/configuration/theme/default.json`.

**Note**: The `themeCustomization` JSON is cached by Django in Redis for 24h. After changing the config, either wait for cache expiry or delete the cache key manually.

### Drive

Drive's waffle fetches services from an external API (`https://lasuite.numerique.gouv.fr/api/services`). URLs are hardcoded per theme in `cunningham.ts`.

**Current state**: Waffle disabled with `FRONTEND_HIDE_GAUFRE: "True"` since URLs cannot be configured.

**Future fix**: Requires a PR on suitenumerique/drive to make waffle URLs configurable at runtime.

### People

People's waffle is unconditionally rendered in the header (`LaGaufre.tsx`). The gaufre script is hardcoded to `https://integration.lasuite.numerique.gouv.fr/api/v1/gaufre.js`. There is no environment variable, feature flag, or backend configuration to disable it.

**Current state**: Waffle always enabled. Links point to official gouv.fr instances. Cannot be disabled without source code changes.

**Future fix**: Requires a PR on suitenumerique/people to add a `FRONTEND_HIDE_GAUFRE` env var (same pattern as Drive).

### Conversations

Conversations' waffle is hardcoded in the frontend (`LaGaufre.tsx`). It loads the widget from `https://static.suite.anct.gouv.fr/widgets/lagaufre.js` and fetches services from `https://lasuite.numerique.gouv.fr/api/services`. The `backend.themeCustomization` chart value exists but is unrelated to the waffle — it controls other branding aspects.

**Current state**: Waffle always enabled. Links point to official gouv.fr instances. Cannot be customized without source code changes.

### Meet

Meet does not have a waffle menu.

## LiveKit / WebRTC

### Host Network Mode

LiveKit uses `hostNetwork: true` by default to expose WebRTC ports directly on nodes. This requires opening firewall ports:

- **UDP 50000-60000**: WebRTC media
- **TCP 7881**: WebRTC TCP fallback

To disable hostNetwork (requires cloud LoadBalancer with UDP support or TURN relay), set `podHostNetwork: false` in `values/livekit.yaml.gotmpl`.

### Self-signed Certificates

When using self-signed certificates (local development), Meet requires `LIVEKIT_VERIFY_SSL: "false"` to connect to LiveKit.

## S3 / Object Storage

### No Shared Storage Between Apps

Each app has its own isolated S3 bucket:

- `docs-media-storage` for Docs
- `drive-media-storage` for Drive

There is no integration between Docs and Drive. You cannot open a Docs document from Drive or save a document to Drive from Docs.

**Note**: Drive exposes a [Resource Server API](https://github.com/suitenumerique/drive/blob/main/docs/resource_server.md) (`/external_api/v1.0/*`) that could allow other apps to access files, but Docs does not implement a client for this API.

### MinIO is Development Only

MinIO is provided for local development convenience. Do not use in production. Use AWS S3, OOS (Outscale), or another S3-compatible service.

### OOS (Outscale) Compatibility

When using OOS as S3 provider, set `s3.provider: oos` in your environment config. This adds AWS SDK checksum compatibility settings required by newer SDK versions:

```yaml
AWS_REQUEST_CHECKSUM_CALCULATION: WHEN_REQUIRED
AWS_RESPONSE_CHECKSUM_VALIDATION: WHEN_REQUIRED
```

## Kubernetes 1.34+ Compatibility

### Duplicate Environment Variables

Kubernetes 1.34 enforces strict validation on pod specs and rejects containers with duplicate environment variable names. This affects two areas:

- **Keycloak**: The `keycloakx` chart generates `KC_HTTP_ENABLED` from `proxy.enabled: true`. Do not also set it in `extraEnv` — K8s will reject the pod.
- **People (desk)**: The chart template copies `backend.envVars` into celery worker/beat deployments. Do not redeclare these vars in `celeryWorker.envVars` or `celeryBeat.envVars` — they are inherited automatically.

## Keycloak / OIDC

### Internal vs External URLs

Pods cannot resolve `/etc/hosts` entries from the host machine. OIDC configuration uses:

- **External URLs** for browser redirects (auth, logout): `https://auth.{domain}/...`
- **Internal URLs** for backend-to-backend calls (token, JWKS): `http://keycloak-keycloakx-http.lasuite-keycloak.svc.cluster.local/...`

### Backchannel Dynamic

Keycloak must have `KC_HOSTNAME_BACKCHANNEL_DYNAMIC=true` to accept requests on internal URLs when `KC_HOSTNAME` is set to an external URL.

### Find Service Account

The Find Keycloak client has `serviceAccountsEnabled: true` (unlike other apps) because Find uses the OIDC Resource Server pattern with token introspection for API access.

## Redis

### FLUSHDB / FLUSHALL Disabled

The Bitnami Redis chart disables `FLUSHDB` and `FLUSHALL` by default (`master.disableCommands`). This is a security best practice but affects Django apps that use `cache.clear()` (e.g., `django-redis` calls `FLUSHDB` internally).

**Consequence**: `cache.clear()` will raise `ConnectionInterrupted`. To invalidate specific cache entries, use `cache.delete(key)` instead.

To re-enable these commands (not recommended in production), set `master.disableCommands: []` in `values/redis.yaml.gotmpl`.

## PostgreSQL

### Django Users Require SUPERUSER

Django app database users are created with SUPERUSER privileges. This is required for migrations that create C functions (extensions). In production, consider using a more restrictive setup with pre-created extensions.

## Docker Images / ARM64

### Broken Docker Images (ARM64 / invalid USER)

Some La Suite Docker images have two upstream issues:

#### Broken multi-arch manifests (unknown/unknown)

Affects **Kubernetes** and **nerdctl compose** on ARM64. Docker Compose is not affected (supports `platform:` per service).

**Root cause**: GitHub's runner images [upgraded to Docker Engine 29](https://github.com/actions/runner-images/commit/c218bde724e0ae9730d9ce101bca654a4c2e521d), which switches to the [containerd image store](https://docs.docker.com/engine/storage/containerd/) by default. This silently changed how `docker buildx build --push` works — images are now pushed as OCI manifest lists with [provenance attestation manifests](https://docs.docker.com/build/metadata/attestations/attestation-storage/) (`unknown/unknown` platform entries) instead of single-platform images. Before, a single-image manifest meant Rosetta fell back to amd64 transparently; now the OCI index triggers platform selection, the runtime finds `unknown/unknown`, and gives up. The Docker 29 [release notes](https://docs.docker.com/engine/release-notes/29/) mention the containerd switch but not this consequence. The only place describing the actual breakage is [moby/moby#51532](https://github.com/moby/moby/issues/51532).

La Suite's `docker-hub.yml` workflows didn't change — the Docker Engine underneath them did. Drive 0.12.0 was fine (built on Docker 28, simple manifest v2); 0.13.0+ was the first release built after the runner upgrade.

**Upstream fix (in progress)**: MANY thanks to [Stephan Meijer](https://github.com/StephanMeijer) who opened PRs, adding native arm64 builds across all La Suite repos, which eliminates the problem entirely — proper multi-arch manifests with real platform entries replace the broken single-arch + attestation layout:

| Repo | PR |
|------|-----|
| calc | [#14](https://github.com/suitenumerique/calc/pull/14) |
| containers | [#1](https://github.com/suitenumerique/containers/pull/1) |
| conversations | [#296](https://github.com/suitenumerique/conversations/pull/296) |
| docs | [#1901](https://github.com/suitenumerique/docs/pull/1901) |
| drive | [#551](https://github.com/suitenumerique/drive/pull/551) |
| e2esdk | [#1](https://github.com/suitenumerique/e2esdk/pull/1) |
| find | [#54](https://github.com/suitenumerique/find/pull/54) |
| meet | [#981](https://github.com/suitenumerique/meet/pull/981) |
| meet-kyutai-moshi-stt | [#2](https://github.com/suitenumerique/meet-kyutai-moshi-stt/pull/2) |
| meet-whisperx | [#26](https://github.com/suitenumerique/meet-whisperx/pull/26) |
| messages | [#554](https://github.com/suitenumerique/messages/pull/554) |
| people | [#1070](https://github.com/suitenumerique/people/pull/1070) |

Until these are merged and released, the workarounds below apply.

**Affected images** (current releases):
- `lasuite/impress-backend`, `lasuite/impress-frontend`, `lasuite/impress-y-provider` (Docs)
- `lasuite/drive-backend`, `lasuite/drive-frontend` (Drive, since v0.13.0)
- `lasuite/meet-backend`, `lasuite/meet-frontend` (Meet)
- `lasuite/people-backend`, `lasuite/people-frontend` (People)
- `lasuite/conversations-backend`, `lasuite/conversations-frontend` (Conversations)

**Kubernetes**: No reliable workaround. kubelet re-resolves the manifest index from the registry every time, ignoring locally cached images.

**Docker Compose**: Add `platform: linux/amd64` to affected services in `compose.override.yml`. No rebuild needed:

```yaml
services:
  # Docs (impress)
  docs-backend:
    platform: linux/amd64
  docs-backend-createsuperuser:
    platform: linux/amd64
  docs-backend-migrate:
    platform: linux/amd64
  docs-celery-worker:
    platform: linux/amd64
  docs-frontend:
    platform: linux/amd64
  docs-y-provider:
    platform: linux/amd64
  # Drive
  drive-backend:
    platform: linux/amd64
  drive-backend-migrate:
    platform: linux/amd64
  drive-celery-worker:
    platform: linux/amd64
  drive-celery-beat:
    platform: linux/amd64
  drive-frontend:
    platform: linux/amd64
  # Meet
  meet-backend:
    platform: linux/amd64
  meet-backend-createsuperuser:
    platform: linux/amd64
  meet-backend-migrate:
    platform: linux/amd64
  meet-frontend:
    platform: linux/amd64
  # People
  people-desk-backend:
    platform: linux/amd64
  people-desk-backend-migrate:
    platform: linux/amd64
  people-desk-celery-beat:
    platform: linux/amd64
  people-desk-celery-worker:
    platform: linux/amd64
  people-desk-frontend:
    platform: linux/amd64
  # Conversations
  conversations-backend:
    platform: linux/amd64
  conversations-frontend:
    platform: linux/amd64
```

**nerdctl compose**: Does not support `platform:` per service. Pull with explicit platform and retag:

```bash
IMAGES=(
  lasuite/impress-backend:v4.6.0
  lasuite/impress-frontend:v4.6.0
  lasuite/impress-y-provider:v4.6.0
  lasuite/drive-backend:v0.14.0
  lasuite/drive-frontend:v0.14.0
  lasuite/meet-backend:v1.10.0
  lasuite/meet-frontend:v1.10.0
  lasuite/people-backend:latest
  lasuite/people-frontend:latest
  lasuite/conversations-backend:latest
  lasuite/conversations-frontend:latest
)

for img in "${IMAGES[@]}"; do
  nerdctl pull --platform linux/amd64 "$img"
  nerdctl tag "$img" "${img}-fixed"
done
```

Then use `-fixed` tags in `compose.override.yml`:

```yaml
services:
  # Docs (impress)
  docs-backend:
    image: lasuite/impress-backend:v4.6.0-fixed
  docs-backend-createsuperuser:
    image: lasuite/impress-backend:v4.6.0-fixed
  docs-backend-migrate:
    image: lasuite/impress-backend:v4.6.0-fixed
  docs-celery-worker:
    image: lasuite/impress-backend:v4.6.0-fixed
  docs-frontend:
    image: lasuite/impress-frontend:v4.6.0-fixed
  docs-y-provider:
    image: lasuite/impress-y-provider:v4.6.0-fixed
  # Drive
  drive-backend:
    image: lasuite/drive-backend:v0.14.0-fixed
  drive-backend-migrate:
    image: lasuite/drive-backend:v0.14.0-fixed
  drive-celery-worker:
    image: lasuite/drive-backend:v0.14.0-fixed
  drive-celery-beat:
    image: lasuite/drive-backend:v0.14.0-fixed
  drive-frontend:
    image: lasuite/drive-frontend:v0.14.0-fixed
  # Meet
  meet-backend:
    image: lasuite/meet-backend:v1.10.0-fixed
  meet-backend-createsuperuser:
    image: lasuite/meet-backend:v1.10.0-fixed
  meet-backend-migrate:
    image: lasuite/meet-backend:v1.10.0-fixed
  meet-frontend:
    image: lasuite/meet-frontend:v1.10.0-fixed
  # People
  people-desk-backend:
    image: lasuite/people-backend:latest-fixed
  people-desk-backend-migrate:
    image: lasuite/people-backend:latest-fixed
  people-desk-celery-beat:
    image: lasuite/people-backend:latest-fixed
  people-desk-celery-worker:
    image: lasuite/people-backend:latest-fixed
  people-desk-frontend:
    image: lasuite/people-frontend:latest-fixed
  # Conversations
  conversations-backend:
    image: lasuite/conversations-backend:latest-fixed
  conversations-frontend:
    image: lasuite/conversations-frontend:latest-fixed
```

#### Invalid USER directive (nerdctl only)

The `docker-hub.yml` workflows use `DOCKER_USER=${{ env.DOCKER_USER }}:-1000` in build-args. The `:-1000` is meant as a shell default but GitHub Actions interpolates it literally, producing `USER 1001:127:-1000`. Docker ignores the invalid part, but nerdctl rejects it.

**Affected images** (all except Drive):
- `lasuite/impress-backend`, `lasuite/impress-frontend`, `lasuite/impress-y-provider` (Docs) — backend+frontend fixed on main, but v4.6.0 images are affected
- `lasuite/meet-backend`, `lasuite/meet-frontend` (Meet) — not fixed on main
- `lasuite/people-backend`, `lasuite/people-frontend` (People) — not fixed on main
- `lasuite/conversations-backend`, `lasuite/conversations-frontend` (Conversations) — not fixed on main

**nerdctl workaround**: rebuild affected images with a valid USER:

```bash
IMAGES=(
  lasuite/impress-backend:v4.6.0
  lasuite/impress-frontend:v4.6.0
  lasuite/impress-y-provider:v4.6.0
  lasuite/meet-backend:v1.10.0
  lasuite/meet-frontend:v1.10.0
  lasuite/people-backend:latest
  lasuite/people-frontend:latest
  lasuite/conversations-backend:latest
  lasuite/conversations-frontend:latest
)

for img in "${IMAGES[@]}"; do
  nerdctl pull --platform linux/amd64 "$img"
  echo "FROM $img
USER 1001" | nerdctl build --tag "${img}-fixed" -
done
```

### People (Desk) Chart Bug

The `desk` chart v0.0.7 templates the `createsuperuser` job `command` as a YAML string instead of an array, causing Kubernetes to reject the Job. Workaround: `backend.createsuperuser.enabled: false` in values, then create the superuser manually:

```bash
# Derive password from secretSeed (same formula as other secrets)
PASS=$(grep secretSeed environments/local.yaml | cut -d'"' -f2 | xargs -I{} sh -c 'echo -n "{}:people-superuser" | shasum -a 256 | cut -c1-50')
kubectl -n lasuite-people exec deploy/people-desk-backend -- \
  python manage.py createsuperuser --username admin@suite.local --password "$PASS"
```

### Find Image Name Mismatch

The Find Helm chart defaults to `lasuite/find-backend` but the image is published as `lasuite/find` on Docker Hub. The helmfile overrides the repository in `values/find.yaml.gotmpl`. Only the `main` tag is available (no versioned tags).

## Find / OpenSearch

### Indexation requires external URL (SECURE_SSL_REDIRECT)

Find deploys and runs fine everywhere. The problem is **indexation** — Docs and Drive push content to Find for search.

Find's Django `Production` class hardcodes `SECURE_SSL_REDIRECT = True` as a plain class attribute (not a `values.Value()`), making it impossible to override via environment variable. This 301-redirects all HTTP requests to HTTPS. Since TLS terminates at ingress (no HTTPS between pods), Docs and Drive cannot use the internal K8s service URL (`http://find-backend.lasuite-find.svc.cluster.local/...`) — Find rejects it. They must go through the external ingress URL (`https://find.{domain}/...`) instead.

This means:
- **Production with real DNS**: works — pods resolve the external domain, ingress terminates TLS, Find receives the request over HTTP internally.
- **K8s local dev** (`/etc/hosts`): fails — pods cannot resolve the external domain since `/etc/hosts` is host-only.
- **Compose**: fails for a different reason — see [compose limitations](compose-deployment.md#find-not-available-in-compose).

**Upstream fix**: `SECURE_SSL_REDIRECT` and `SECURE_REDIRECT_EXEMPT` should be `values.BooleanValue()` / `values.ListValue()` like the rest of Find's settings, allowing env var override.

### OpenSearch resource requirements

OpenSearch requires significant resources (JVM heap, mmap `vm.max_map_count`) and has compatibility issues with nerdctl (security plugin bootstrap, sysctl requirements).

### Experimental status

Find is still early-stage. It is disabled by default (`apps.find.enabled: false` in `_defaults.yaml`). Indexation (Docs/Drive integration) requires a cluster with real DNS resolution.

### Migrate Job Must Be Deleted Before Upgrade

Kubernetes Jobs have immutable `spec.template`. The Find chart names its migrate Job `find-backend-migrate-{chartVersion}`. Since the chart version barely moves (`0.0.3` for months), any change to the Job spec (env vars, command, image) will fail with `field is immutable`. You must delete the Job manually before every `helmfile sync` that touches Find:

```bash
kubectl -n lasuite-find delete job find-backend-migrate-0.0.3
```

This also interacts badly with `helmDefaults.waitForJobs: true` — the Job has `ttlSecondsAfterFinished: 30`, so Helm's `--wait-for-jobs` may find the Job already garbage-collected and fail. We set `waitForJobs: false` globally to avoid this.
