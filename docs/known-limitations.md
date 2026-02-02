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
| Docs | 4.4.0 | v4.4.0 | Derived from `laSuiteChartVersions.docs` |
| Drive | 0.11.1 | v0.11.1 | Derived from `laSuiteChartVersions.drive` |
| Meet | 0.0.15 | v1.5.0 | Explicit in `laSuiteImageVersions.meet` |

### Meet Version Mismatch

Meet's Helm chart version (`0.0.x`) does not match its app version (`v1.x`). This requires an explicit `laSuiteImageVersions.meet` entry.

When updating Meet:
1. Check latest chart version: `helm search repo meet/meet --versions`
2. Check latest image tag: https://hub.docker.com/r/lasuite/meet-backend/tags
3. Update both `laSuiteChartVersions.meet` and `laSuiteImageVersions.meet` in `versions/lasuite-helm-versions.yaml`

## Waffle/Gaufre Menu

The waffle (gaufre) is the app navigation menu showing links to other La Suite apps.

### Docs

| Version | Behavior |
|---------|----------|
| v4.4.0 | Waffle controlled by `FRONTEND_THEME`. Set to `dsfr` to enable, but URLs are hardcoded to gouv.fr |
| v4.5.0+ | Waffle configurable via `themeCustomization.waffle` (not yet released) |

**Current state**: Waffle enabled with `FRONTEND_THEME: dsfr`. Links point to official gouv.fr instances, not your local deployment.

**Future fix**: When Docs 4.5.0 releases, uncomment `themeCustomization` in `values/docs.yaml.gotmpl` to configure custom URLs.

### Drive

Drive's waffle fetches services from an external API (`https://lasuite.numerique.gouv.fr/api/services`). URLs are hardcoded per theme in `cunningham.ts`.

**Current state**: Waffle disabled with `FRONTEND_HIDE_GAUFRE: "True"` since URLs cannot be configured.

**Future fix**: Requires a PR on suitenumerique/drive to make waffle URLs configurable at runtime.

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

## Redis

### FLUSHDB Disabled

Our Redis configuration disables dangerous commands including `FLUSHDB`. To clear specific cache keys, delete them individually rather than flushing the entire database.

## PostgreSQL

### Django Users Require SUPERUSER

Django app database users are created with SUPERUSER privileges. This is required for migrations that create C functions (extensions). In production, consider using a more restrictive setup with pre-created extensions.
