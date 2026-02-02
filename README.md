# La Suite Platform

Reference [Helmfile](https://github.com/helmfile/helmfile) to deploy [La Suite numerique](https://github.com/suitenumerique) on Kubernetes.

> **Note**: This is an example repository for learning and adaptation, not a production-ready platform. Monitoring, GitOps, and advanced HA configurations are left to the deploying organization. See [Architecture Decisions](docs/decisions.md) for rationale.

## Looking for Production-Ready?

If you need a production-grade platform with automatic updates, security policies, and per-app isolation, check out [MinBZK/mijn-bureau-infra](https://github.com/MinBZK/mijn-bureau-infra) - a more sophisticated helmfile maintained by the Dutch government. See [comparison](docs/comparison-mijn-bureau.md) for details.

If you still want to use this helmfile for production, see [Advanced Deployment](docs/advanced-deployment.md) for external PostgreSQL/Keycloak setup and other production considerations.

## Differences with official docs

Each app has its own Kubernetes installation guide. This helmfile provides:

- **Unified deployment** - one config for all apps instead of following N separate guides
- **Standard tools** - cert-manager and HAProxy instead of mkcert and nginx-specific setup
- **Minimal third-party dependencies** - `/etc/hosts` instead of nip.io, no external DNS service
- **Single command** - `helmfile sync` instead of multiple `helm install` commands

See [detailed comparison](docs/decisions.md#differences-with-official-installation-methods).

## Applications

| App | Description | Status |
|-----|-------------|--------|
| **Docs** | Collaborative document editing (Google Docs-like) | Implemented |
| **Meet** | Video conferencing (Google Meet-like) | Implemented |
| **Drive** | File storage and sharing (Google Drive-like) | Implemented |
| **Desk** | Directory and team management | Planned |
| **Conversations** | AI chatbot (requires LLM backend) | Planned |

> **Note**: Desk and Conversations are defined in chart versions but not yet fully integrated.

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

### Firewall (Meet/LiveKit)

LiveKit uses `hostNetwork` by default to expose WebRTC ports directly on nodes. Open these ports:

- **UDP 50000-60000** - WebRTC media
- **TCP 7881** - WebRTC TCP fallback

To disable hostNetwork (requires cloud LoadBalancer with UDP or TURN relay), set `podHostNetwork: false` in `values/livekit.yaml.gotmpl`.

## Access (Local)

| Service | URL | Credentials |
|---------|-----|-------------|
| Docs | https://docs.suite.local | user / password |
| Meet | https://meet.suite.local | user / password |
| Drive | https://drive.suite.local | user / password |
| Keycloak Admin | https://auth.suite.local | admin / (see below) |

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

## Documentation

- [Advanced Deployment](docs/advanced-deployment.md) - External PostgreSQL/Keycloak, production setup
- [Architecture Decisions](docs/decisions.md) - Why things are the way they are
- [Known Limitations](docs/known-limitations.md) - Current limitations and workarounds
- [Comparison with mijn-bureau-infra](docs/comparison-mijn-bureau.md) - When to use which
