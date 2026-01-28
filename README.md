# Suite Helmfile

Helmfile to deploy [La Suite numerique](https://github.com/suitenumerique) on Kubernetes with minimal configuration.

## Quick Start (Local)

```bash
./init-local.sh
# Add the printed line to /etc/hosts
helmfile -e local sync
```

## What it deploys

- **Apps**: docs, meet, drive, desk, conversations (configurable)
- **Infra**: PostgreSQL, Redis, Keycloak, MinIO, HAProxy, cert-manager

## Environments

- `local`: Self-contained local deployment with self-signed certificates
- `remote-example`: Template for production (external S3, Let's Encrypt)

## Documentation

See [CLAUDE.md](CLAUDE.md) for technical details.
