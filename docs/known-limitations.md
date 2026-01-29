# Known Limitations

This document lists limitations of the current deployment that may affect your usage.

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
