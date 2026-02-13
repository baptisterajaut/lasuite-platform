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
| Docs | 4.5.0 | v4.5.0 | Derived from `laSuiteChartVersions.docs` |
| Drive | 0.12.0 | v0.12.0 | Derived from `laSuiteChartVersions.drive` |
| Meet | 0.0.15 | v1.5.0 | Explicit in `laSuiteImageVersions.meet` |
| People | 0.0.7 | latest | No published version tags |
| Conversations | 0.0.5 | latest | No published version tags |
| Find | 0.0.3 | main | Published as `lasuite/find` (not `find-backend`) |

### Meet Version Mismatch

Meet's Helm chart version (`0.0.x`) does not match its app version (`v1.x`). This requires an explicit `laSuiteImageVersions.meet` entry.

When updating Meet:
1. Check latest chart version: `helm search repo meet/meet --versions`
2. Check latest image tag: https://hub.docker.com/r/lasuite/meet-backend/tags
3. Update both `laSuiteChartVersions.meet` and `laSuiteImageVersions.meet` in `versions/lasuite-helm-versions.yaml`

## Waffle/Gaufre Menu

The waffle (gaufre) is the app navigation menu showing links to other La Suite apps.

### Docs

Since v4.5.0, the waffle is configurable via `backend.themeCustomization`. The helmfile configures it with local URLs pointing to deployed apps.

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
- **Broken multi-arch manifests** — declare `unknown/unknown` as platform instead of `linux/amd64`. On ARM64 (e.g., Apple Silicon), containerd refuses to pull them.
- **Invalid USER directive** — `USER 1001:127:-1000` is not a valid UID:GID format.

**Affected images**:
- `lasuite/impress-backend`, `lasuite/impress-frontend`, `lasuite/impress-y-provider` (Docs)
- `lasuite/meet-backend`, `lasuite/meet-frontend` (Meet)
- `lasuite/people-backend`, `lasuite/people-frontend` (People)
- `lasuite/conversations-backend`, `lasuite/conversations-frontend` (Conversations)

**Kubernetes**: No reliable workaround. `nerdctl pull --platform linux/amd64` works locally, but kubelet re-resolves the manifest index from the registry and ignores locally cached images.

**Docker Compose / nerdctl compose**: Pull with explicit platform, rebuild with a valid USER, tag as `-fixed`:

```bash
IMAGES=(
  lasuite/impress-backend:v4.5.0
  lasuite/impress-frontend:v4.5.0
  lasuite/impress-y-provider:v4.5.0
  lasuite/meet-backend:v1.5.0
  lasuite/meet-frontend:v1.5.0
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

Then create a `compose.override.yml` to use the fixed tags (see [compose deployment](compose-deployment.md)):

```yaml
services:
  docs-backend:
    image: lasuite/impress-backend:v4.5.0-fixed
  docs-frontend:
    image: lasuite/impress-frontend:v4.5.0-fixed
  docs-y-provider:
    image: lasuite/impress-y-provider:v4.5.0-fixed
  meet-backend:
    image: lasuite/meet-backend:v1.5.0-fixed
  meet-frontend:
    image: lasuite/meet-frontend:v1.5.0-fixed
  people-desk-backend:
    image: lasuite/people-backend:latest-fixed
  people-desk-frontend:
    image: lasuite/people-frontend:latest-fixed
  conversations-backend:
    image: lasuite/conversations-backend:latest-fixed
  conversations-frontend:
    image: lasuite/conversations-frontend:latest-fixed
```

### Drive Celery Beat (chart 0.12.0)

The `drive` chart v0.12.0 adds a `celeryBeat` deployment but does not provide a writable volume for the `celerybeat-schedule` file. The container's working directory (`/app`) is read-only, causing a `PermissionError` crash loop.

Workaround in `values/drive.yaml.gotmpl`: override the args to write the schedule to `/tmp`:

```yaml
backend:
  celeryBeat:
    args: ["celery", "-A", "drive.celery_app", "beat", "-l", "INFO", "--schedule=/tmp/celerybeat-schedule"]
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
