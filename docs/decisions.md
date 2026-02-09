# Architecture Decisions

This document explains why certain things are the way they are.

## Differences with official installation methods

Each La Suite application (Docs, Meet, Drive) has its own Kubernetes installation guide. This helmfile takes a different approach.

| Aspect | Official docs | This helmfile |
|--------|---------------|---------------|
| Ingress | nginx-ingress (required) | HAProxy |
| TLS | mkcert (dev tool) | cert-manager with ClusterIssuers |
| Domain names | nip.io (third-party service) | /etc/hosts or real DNS |
| Test cluster | Kind (specific setup) | Any cluster (Rancher Desktop, cloud, etc.) |
| Deployment | Multiple `helm install` commands | Single `helmfile sync` |
| Configuration | Separate guide per app | Unified configuration |
| Backend charts | helm-dev-backend wrapper | Official charts (Bitnami, codecentric) |

**Standard tools over custom solutions**: official docs use `mkcert` for local TLS, which works but is a dev-only tool. This helmfile uses `cert-manager` with ClusterIssuers - same pattern for dev (selfsigned) and prod (Let's Encrypt).

**Unified deployment**: instead of following separate installation guides for Docs, Meet, and Drive, you configure which apps to enable and run `helmfile sync`. Shared infrastructure (PostgreSQL, Redis, Keycloak) is configured once.

**Minimal third-party dependencies**: official docs use `*.127.0.0.1.nip.io` which routes DNS queries through a third-party service with unknown privacy practices. This helmfile uses `/etc/hosts` entries - no external service involved.

### When to use official docs instead

The official guides are better if you:
- Want to deploy a single app only
- Already have nginx-ingress and prefer to keep it
- Need the exact setup used by the La Suite team for debugging

---

## La Suite numerique repositories

The [suitenumerique](https://github.com/suitenumerique) GitHub organization contains many repositories. Here's a complete breakdown:

### Applications with Helm charts (included)

| App | Repo | Status | Description |
|-----|------|--------|-------------|
| **Docs** | `docs` | Enabled | Collaborative document editing |
| **Meet** | `meet` | Enabled | Video conferencing with LiveKit |
| **Drive** | `drive` | Enabled | File storage and sharing |
| **People** | `people` | Disabled | Team/user management |
| **Conversations** | `conversations` | Disabled | AI chatbot (requires LLM) |
| **Find** | `find` | Disabled | Cross-app search (requires OpenSearch) |

### Applications without Helm charts

| App | Repo | Stack | Why Not Included |
|-----|------|-------|------------------|
| **Projects** | `projects` | Node.js/Sails.js | No Helm chart. Project management app for La Suite territoriale. Would need custom chart. |
| **Messages** | `messages` | Unknown | No Helm chart, no Dockerfile. Collaborative inbox, appears incomplete. |
| **Calc** | `calc` | Docker only | No Helm chart. Prototype collaborative spreadsheet - not production ready. |
| **Messagerie** | `messagerie` | Email infra | Not a web app. Postfix/Dovecot/OpenXChange email infrastructure. |

### Meet auxiliary services

| Service | Repo | Why Not Included |
|---------|------|------------------|
| **LiveKit SIP** | `livekit-sip` | SIP-to-WebRTC bridge. Only needed for telephony integration. |
| **WhisperX** | `meet-whisperx` | Transcription service. Requires GPU, complex setup. |
| **Moshi STT** | `meet-kyutai-moshi-stt` | Speech-to-text. Requires GPU, experimental. |

### La Suite territoriale

These are specific to "La Suite territoriale" (local government variant):

| Repo | Description | Why Not Included |
|------|-------------|------------------|
| `st-home` | Homepage/landing page | Specific to territorial deployment |
| `st-deploycenter` | App management console | Operator tooling, not end-user app |
| `st-ansible` | Ansible collection | Different deployment method |

### Libraries and SDKs (not deployable)

| Repo | Type | Description |
|------|------|-------------|
| `django-lasuite` | Library | Shared Django components |
| `cunningham` | Design system | React component library |
| `ui-kit` | Design system | UI components |
| `e2esdk` | SDK | End-to-end encryption |
| `media-sdk` | SDK | Media handling |
| `integration` | API/Templates | Common UI templates |
| `buildpack` | Buildpack | For PaaS deployments (Scalingo, Heroku) |

### Infrastructure and reference

| Repo | Description |
|------|-------------|
| `helm-dev-backend` | Reference Helm chart for dev backends (PostgreSQL, Redis, etc.) |
| `containers` | Docker images for RunPod (AI workloads) |
| `dev-handbook` | Developer documentation |
| `documentation` | General documentation |

### Other

| Repo | Description |
|------|-------------|
| `.github` | GitHub organization config |
| `hackdays` / `hackdays2025` | Hackathon landing pages |
| `find` | Cross-app search engine (included in helmfile, image not yet published) |

---

## Applications not included (details)

### Tchap (messaging)

Tchap is the French government's Matrix-based messaging platform (not in `suitenumerique` org, lives in `tchapgouv`). It is **not included yet** because:

- **No Helm chart available** - Deployment is docker-compose only (`tchapgouv/tchap-docker-integration`)
- **Complex multi-component architecture**:
  - Synapse (Matrix homeserver)
  - Element Web (frontend)
  - Matrix Auth Service
  - LiveKit (for calls)
  - PostgreSQL
  - Redis
- **Heavy infrastructure requirements** - Running a full Matrix stack requires significant resources and expertise

**Future consideration**: We managed to integrate Meet with LiveKit, so Tchap integration is not impossible. It would require creating Helm charts for the Matrix stack components. Contributions welcome.

If you need messaging now, consider deploying Tchap separately or using an existing Matrix homeserver.

### Projects (project management)

Projects is a Kanban/project management app. It is **not included** because:

- **No Helm chart** - Only docker-compose available
- **Different stack** - Node.js/Sails.js instead of Django
- **Would require custom chart** - Relatively simple to create, but not prioritized

### Calc (spreadsheets)

Calc is a collaborative spreadsheet app. It is **not included** because:

- **Prototype status** - Not production ready
- **No Helm chart** - Only Dockerfile available

### Messagerie (email)

Messagerie is **not included** because:

- **Not a web application** - It's email infrastructure (Postfix, Dovecot, OpenXChange)
- **Managed separately** - Infrastructure is handled via `gitlab.mim-libre.fr/dimail`
- **Different deployment model** - Email servers have very different requirements than web apps

### Messages (collaborative inbox)

Messages is a collaborative inbox for teams. It is **not included** because:

- **No deployment artifacts** - No Dockerfile, no Helm chart, no docker-compose
- **Appears incomplete** - Repository has minimal content

---

## External apps worth considering

These are not part of La Suite Numerique but could complement it:

### Grist (spreadsheets)

[Grist](https://github.com/gristlabs/grist-core) is an open-source alternative to Google Sheets/Airtable. It could replace the prototype `calc` app.

- **Helm chart available**: Community chart on [ArtifactHub](https://artifacthub.io/packages/helm/rlex/grist)
- **Features**: Collaborative spreadsheets, Python formulas, API
- **Auth**: Supports OIDC (Keycloak compatible)

**Future consideration**: Could be added to this helmfile as an optional component.

### France Transfert (file transfer)

A WeTransfer-like service for large file transfers. **Not open source** - managed internally by DINUM.

Alternatives if needed:
- [PsiTransfer](https://github.com/psi-4ward/psitransfer) - Simple file sharing
- [Send](https://github.com/timvisee/send) - Firefox Send fork
- [Lufi](https://framagit.org/fiat-tux/hat-softwares/lufi) - Encrypted file upload

## Features disabled by default

### Meet: AI features (transcription, summarization)

Meet has built-in AI features for transcribing and summarizing meetings. These are **disabled** because:

- **Requires GPU** - Transcription models need CUDA-capable hardware
- **Additional services** - Needs separate AI model deployment (Whisper, LLM)
- **Resource intensive** - Not suitable for a simple local deployment

To enable AI features, you would need to:
1. Deploy a transcription service (e.g., Whisper)
2. Deploy an LLM for summarization
3. Configure `summary.replicas`, `celeryTranscribe.replicas`, `celerySummarize.replicas` in Meet values

### Meet: recording

Recording is **disabled** because:

- **Requires S3** - Recordings need persistent storage
- **Requires LiveKit Egress** - Additional LiveKit component for recording
- **Complex setup** - Involves webhooks, storage configuration, and egress deployment

### Conversations: LLM backend

Conversations (AI chatbot) is **disabled by default** because:

- **Requires LLM provider** - Either external API (OpenAI, Anthropic) or local model (Ollama)
- **No default provider** - We cannot ship API keys or GPU-dependent models
- **Cost implications** - External LLM APIs have per-token costs

To enable Conversations:
1. Deploy Ollama or configure an external LLM provider
2. Set `apps.conversations.enabled: true`
3. Configure LLM endpoint in Conversations values

### People: team management

People is **disabled by default** because:

- **Optional for basic deployments** - Keycloak already handles authentication
- **Useful for multi-tenant setups** - Adds value when managing multiple teams/organizations
- **Early stage** - Chart (`desk`) is still v0.0.7

## Infrastructure choices

### MinIO: development only

MinIO is provided **only for local development**. In production:

- **Use real S3** - AWS S3, OOS (Outscale), Scaleway, OVH, or any S3-compatible storage
- **MinIO lacks HA** - Single-node MinIO is not production-ready
- **Cost** - Cloud S3 is often cheaper than self-hosted MinIO at scale

### S3 provider support

The `s3.provider` setting configures S3-specific compatibility:

| Provider | Value | Notes |
|----------|-------|-------|
| AWS S3 | `aws` | Default, no special config needed |
| OOS (Outscale) | `oos` | Adds checksum compatibility env vars for newer AWS SDKs |
| MinIO | `minio` | For local development |

**OOS Compatibility**: Since January 2025, newer AWS SDK versions use checksum algorithms not yet supported by OOS. Setting `provider: oos` adds `AWS_REQUEST_CHECKSUM_CALCULATION=WHEN_REQUIRED` and `AWS_RESPONSE_CHECKSUM_VALIDATION=WHEN_REQUIRED` to affected apps.

### HAProxy over nginx-ingress

We use HAProxy instead of nginx-ingress because:

- **nginx-ingress is deprecated** - End of support scheduled for March 2026
- **La Suite charts default to nginx** - But annotations are easily mapped to HAProxy
- **Better WebSocket support** - Native WebSocket handling without special configuration

### Keycloak: always deployed

Even when using external identity providers, we deploy our own Keycloak because:

- **Consistent OIDC interface** - Apps always talk to the same endpoints
- **Federation support** - External IdPs can be added as Identity Providers in the realm
- **Avoids conflicts** - `lasuite-keycloak` namespace won't conflict with other Keycloaks on the cluster
- **Test user support** - Easy to create test users for local development

### Redis: shared instance

All apps share a single Redis instance (with different DB numbers) because:

- **Simplicity** - One less component to manage per app
- **Resource efficiency** - Redis is lightweight, no need for multiple instances
- **Standard pattern** - Most Django apps expect a single Redis with DB number isolation

DB number allocation:
- `0`: Docs cache
- `1`: Docs Celery
- `2`: Drive cache
- `3`: Drive Celery
- `4`: Meet cache
- `5`: People cache
- `6`: People Celery
- `7`: Conversations cache
- `8`: Conversations Celery
- `9`: Find cache
- `10`: Find Celery

### PostgreSQL: one database per app

Each app gets its own database (not just schema) because:

- **Isolation** - Apps cannot accidentally access each other's data
- **Independent migrations** - Each app manages its own schema
- **Backup flexibility** - Can backup/restore individual app data
- **Django convention** - Django apps expect their own database

### Helmfile over Flux/ArgoCD

We use [Helmfile](https://github.com/helmfile/helmfile) instead of GitOps tools like Flux or ArgoCD because:

- **Simplicity** - Helmfile is a single binary that wraps Helm, no cluster operators needed
- **Lower barrier to entry** - No need to understand CRDs, controllers, or reconciliation loops
- **Example-oriented** - This repo is more of a reference implementation than a production-grade deployment platform
- **Flexibility** - Users can easily adapt and integrate into their existing workflows

This is not a "production-ready platform-as-a-service". It's a working example showing how to deploy La Suite on Kubernetes. Organizations with mature GitOps practices can use this as a reference to build their own Flux/ArgoCD configurations.

### No monitoring stack

This helmfile does **not include** monitoring components (Prometheus, Grafana, Loki, etc.) because:

- **Cluster admin responsibility** - Monitoring is typically managed at the cluster level, not per-application
- **Avoid duplication** - Most Kubernetes clusters already have monitoring in place
- **Scope limitation** - Adding monitoring would significantly increase complexity
- **Different requirements** - Organizations have varying monitoring preferences and existing tooling

If you need monitoring, consider:
- **Existing cluster monitoring** - Use your cluster's Prometheus/Grafana
- **Cloud-native solutions** - AWS CloudWatch, GCP Cloud Monitoring, Datadog, etc.
- **Separate deployment** - Deploy kube-prometheus-stack independently

The La Suite applications expose standard metrics endpoints where applicable.

### TLS certificates

Two modes are supported via `tls.issuer`:

| Mode | Value | Use Case |
|------|-------|----------|
| Self-signed | `selfsigned` | Local development |
| Let's Encrypt | `letsencrypt` | Production |

**Self-signed mode** creates a CA certificate (`lasuite-ca`) that signs all app certificates. The `init.sh` script extracts this CA to `lasuite-ca.pem` so users can add it to their trust store.

**Let's Encrypt mode** uses ACME HTTP-01 challenge via the HAProxy ingress controller.

## Secret management

### Deterministic secrets from seed

All secrets are derived from a single `secretSeed` using SHA256 because:

- **Single secret to manage** - Only the seed needs to be stored securely
- **Reproducible** - Same seed always generates same secrets
- **No external dependencies** - No need for Vault, SOPS, or external secret managers
- **Easy rotation** - Change the seed, redeploy, update external systems

### No secret management

This project does not include secret management tooling because:

- **No sensitive secrets in repo** - The `secretSeed` is in `.gitignore`
- **Derived secrets** - Internal secrets are computed from the seed at deploy time
- **Simpler setup** - No additional tooling required to get started

For production, if you need to store secrets that cannot be derived (external API keys, custom credentials), consider using [SOPS](https://github.com/getsops/sops) to encrypt `environments/<env>.secret-overrides.yaml`. SOPS integrates well with git and requires minimal setup (GPG or cloud KMS).
