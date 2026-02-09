# La Suite Platform

Reference [Helmfile](https://github.com/helmfile/helmfile) to deploy [La Suite numerique](https://github.com/suitenumerique) on Kubernetes.

## Looking for Production-Ready?

If you need a production-grade platform with automatic updates, security policies, and per-app isolation, check out [MinBZK/mijn-bureau-infra](https://github.com/MinBZK/mijn-bureau-infra) - a more sophisticated helmfile maintained by the Dutch government. See [comparison](docs/comparison-mijn-bureau.md) for details.

This repository serves as a reference implementation with some [opinionated decisions](docs/decisions.md), while still providing guidance for a somewhat [advanced deployment](docs/advanced-deployment.md) with external infrastructure, that can be iterated upon.

## Differences with official docs

Each app has its own Kubernetes installation guide. This helmfile provides:

- **Unified deployment** - one config for all apps instead of following N separate guides
- **Standard tools** - cert-manager and HAProxy instead of mkcert and nginx-specific setup
- **Minimal third-party dependencies** - `/etc/hosts` instead of nip.io, no external DNS service
- **Single command** - `helmfile sync` instead of multiple `helm install` commands

See [detailed comparison](docs/decisions.md#differences-with-official-installation-methods).

## Applications

| App | Description | Status                       |
|-----|-------------|------------------------------|
| **Docs** | Collaborative document editing (Google Docs-like) | Implemented                  |
| **Meet** | Video conferencing (Google Meet-like) | Implemented                  |
| **Drive** | File storage and sharing (Google Drive-like) | Implemented                  |
| **People** | Directory and team management | Implemented                  |
| **Find** | Cross-app search engine (requires OpenSearch) | Broken (image not published) |
| **Conversations** | AI chatbot (requires LLM backend) | Implemented - Untested       |

Apps are enabled/disabled in `environments/local.yaml` (or your environment file):

```yaml
apps:
  docs:
    enabled: true
  meet:
    enabled: false    # requires LiveKit (heavy on resources)
  drive:
    enabled: true
  people:
    enabled: true
  find:
    enabled: false    # image not published + requires OpenSearch (heavy)
  conversations:
    enabled: false    # requires LLM backend (not included)
```

Default enables Docs, Drive, and People. Meet requires LiveKit (resource-heavy). See [Known Limitations](docs/known-limitations.md) for image issues.

## Prerequisites

- Kubernetes cluster (Rancher Desktop, Docker Desktop, or other)
- [Helm](https://helm.sh/) v3.x
- [Helmfile](https://github.com/helmfile/helmfile) v0.150+
- `kubectl` configured for your cluster

## Quick Start

### Local Development

```bash
./init.sh
# Choose option 1 (Local development)
```

The interactive script will:
1. Check prerequisites (helm, kubectl, helmfile)
2. Generate a random secret seed
3. Run `helmfile sync` automatically
4. Detect the LoadBalancer IP and show the `/etc/hosts` line to add
5. Extract the CA certificate to `lasuite-ca.pem`
6. Display credentials (Keycloak admin password, People Django admin if enabled)

### Remote Deployment

```bash
./init.sh
# Choose option 2 (Remote deployment)
```

The script will ask for:
- Environment name (e.g., `production`)
- Domain (e.g., `suite.example.com`)
- Admin email (for Let's Encrypt)

It creates the configuration files. Review them before deploying.

### Post-deploy: People superuser

The People (desk) chart has a [known bug](docs/known-limitations.md#people-desk-chart-bug) that prevents the automatic superuser creation. The `init.sh` script handles this automatically for local deployments.

For manual creation, derive the password from the secret seed:

```bash
PASS=$(grep secretSeed environments/local.yaml | cut -d'"' -f2 | xargs -I{} sh -c 'echo -n "{}:people-superuser" | shasum -a 256 | cut -c1-50')
kubectl -n lasuite-people exec deploy/people-desk-backend -- \
  python manage.py createsuperuser --username admin@suite.local --password "$PASS"
```

This is only needed for Django admin access (`https://people.suite.local/admin/`). Regular users authenticate via Keycloak.

### Firewall (Meet/LiveKit)

LiveKit uses `hostNetwork` by default to expose WebRTC ports directly on nodes. Open these ports:

- **UDP 50000-60000** - WebRTC media
- **TCP 7881** - WebRTC TCP fallback

To disable hostNetwork (requires cloud LoadBalancer with UDP or TURN relay), set `podHostNetwork: false` in `values/livekit.yaml.gotmpl`.

## Manual Installation

If you prefer to set things up manually instead of using `init.sh`:

### 1. Copy the example environment

```bash
cp environments/local.yaml.example environments/local.yaml
```

### 2. Generate a secret seed

At the bottom of `environments/local.yaml`, replace the `REPLACE_ME` value of `secretSeed` with a random value (e.g. `openssl rand -hex 24`).

### 3. (Optional) Enable or disable apps

Edit `environments/local.yaml` to toggle apps under the `apps:` section.

### 4. Deploy

```bash
helmfile -e local sync
```

### 5. Configure DNS

Point `*.suite.local` domains to your LoadBalancer IP, either via local DNS or by editing `/etc/hosts`.

### 6. Trust the CA certificate

For self-signed TLS (local environment), the CA certificate is stored in the `lasuite-ca-secret` secret in the `cert-manager` namespace.

## Access (Local)

| Service | URL | Credentials |
|---------|-----|-------------|
| Docs | https://docs.suite.local | user / password |
| Meet | https://meet.suite.local | user / password |
| Drive | https://drive.suite.local | user / password |
| People | https://people.suite.local | user / password |
| Find | https://find.suite.local | user / password |
| Conversations | https://conversations.suite.local | user / password |
| Keycloak Admin | https://auth.suite.local | admin / (displayed by `init.sh`) |
| MinIO Console | https://minio-console.suite.local | (derived from secretSeed) |

Only apps with `enabled: true` in your environment file will be accessible.

### Trusting the CA Certificate

The init script extracts the CA certificate to `lasuite-ca.pem`. To avoid browser warnings:

**macOS:**
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain lasuite-ca.pem
```

**Linux (Debian/Ubuntu):**
```bash
sudo cp lasuite-ca.pem /usr/local/share/ca-certificates/lasuite-ca.crt
sudo update-ca-certificates
```

**Firefox:** Settings > Privacy & Security > Certificates > View Certificates > Import

### Keycloak Admin Password

```bash
grep secretSeed environments/local.yaml | cut -d'"' -f2 | xargs -I{} sh -c 'echo -n "{}:keycloak-admin" | shasum -a 256 | cut -c1-50'
```

## Infrastructure

All infrastructure is deployed automatically. For production, replace MinIO with real S3 and consider using external PostgreSQL/Redis.

| Component | Chart | Purpose |
|-----------|-------|---------|
| PostgreSQL | bitnami/postgresql | Shared database (1 DB per app) |
| Redis | bitnami/redis | Cache and Celery broker (1 instance, DB number isolation) |
| Keycloak | codecentric/keycloakx | OIDC identity provider (1 realm, 1 client per app) |
| MinIO | minio/minio | S3-compatible storage (dev only) |
| OpenSearch | opensearch/opensearch | Search engine (for Find) |
| LiveKit | livekit/livekit-server | WebRTC server (for Meet) |
| HAProxy | haproxytech/kubernetes-ingress | Ingress controller |
| cert-manager | jetstack/cert-manager | TLS certificates |
| Reflector | emberstack/reflector | Cross-namespace secret replication |

## Documentation

- [Advanced Deployment](docs/advanced-deployment.md) - External PostgreSQL/Keycloak, production setup
- [Architecture Decisions](docs/decisions.md) - Why things are the way they are
- [Known Limitations](docs/known-limitations.md) - Current limitations and workarounds
- [Comparison with mijn-bureau-infra](docs/comparison-mijn-bureau.md) - When to use which
