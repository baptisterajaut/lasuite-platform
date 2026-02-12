# Deploy with Docker Compose

Run La Suite without a Kubernetes cluster. The `generate-compose.sh` script
converts the same Helmfile charts into a `compose.yml` + `Caddyfile`, using
[helmfile2compose](https://github.com/baptisterajaut/helmfile2compose).

## What you need

- Docker or a compatible runtime (`nerdctl`, `podman`) with compose support
- [Helm](https://helm.sh/) v3 and [Helmfile](https://github.com/helmfile/helmfile) v0.150+
- Python 3 with `pyyaml` (`pip install pyyaml`)
- `openssl`

## Quick start

```bash
git clone https://github.com/suitenumerique/suite-helmfile.git
cd suite-helmfile
./generate-compose.sh
docker compose up -d
```

On first run, the script prompts for:

| Prompt | Default | Description |
|--------|---------|-------------|
| Domain | `suite.local` | Base domain for all services |
| Meet + LiveKit | No | Enable video calls (requires UDP ports 50000-50100) |
| Conversations | No | Enable AI chatbot (requires OpenAI-compatible LLM endpoint) |
| Keycloak username | `user` | Test user for app login |
| Keycloak password | `password` | Test user password |
| Data directory | `./data` | Where PostgreSQL, Redis, MinIO store persistent data |
| Let's Encrypt email | *(none)* | Only asked for non-`.local` domains |

Subsequent runs skip the prompts and just regenerate.

## DNS / /etc/hosts

For local development, add to `/etc/hosts`:

```
127.0.0.1  docs.suite.local drive.suite.local meet.suite.local auth.suite.local
127.0.0.1  people.suite.local conversations.suite.local minio.suite.local
127.0.0.1  minio-console.suite.local livekit.suite.local
```

For real domains, create DNS A records pointing to the host running compose. Caddy handles TLS automatically via Let's Encrypt.

## TLS

For `.local` domains, Caddy uses its internal CA. Browsers will show a certificate warning — click through it or trust Caddy's root CA.

For public domains, Caddy obtains Let's Encrypt certificates automatically (requires ports 80/443 reachable from the internet).

## What you get

| Service | URL | Description |
|---------|-----|-------------|
| Docs | `https://docs.<domain>` | Collaborative documents (Impress) |
| Drive | `https://drive.<domain>` | File management |
| Meet | `https://meet.<domain>` | Video calls (requires LiveKit) |
| People | `https://people.<domain>` | Contact directory |
| Conversations | `https://conversations.<domain>` | AI chatbot |
| Keycloak | `https://auth.<domain>` | SSO / Identity provider |
| MinIO Console | `https://minio-console.<domain>` | Object storage admin |

## Credentials

All secrets are derived from a single `secretSeed` (generated on first run).

- **App login**: `<username>` / `<password>` (Keycloak test user, chosen during setup)
- **Keycloak admin**: `admin` / `<derived>` (printed by generate-compose.sh)

## Configuration

The `compose.yml` and `Caddyfile` are **generated** — never edit them directly. All configuration goes through the files below. Re-run `./generate-compose.sh` to regenerate.

### `environments/compose.yaml`

Generated from `compose.yaml.template` on first run. Controls:
- Domain name
- Which apps are enabled
- AI/LLM config for Conversations
- Test user credentials
- Secret seed

### `helmfile2compose.yaml`

Generated from `helmfile2compose.yaml.template` on first run. Controls:
- Data directory (`volume_root`)
- Volume mappings
- Excluded K8s-only workloads
- Service overrides (Redis vanilla, PostgreSQL volumes, LiveKit ports)
- Custom services (MinIO bucket init)
- String replacements

For the full config file reference, see [helmfile2compose architecture](https://github.com/baptisterajaut/helmfile2compose/blob/main/docs/architecture.md#config-file-helmfile2composeyaml).

### `compose.override.yml` (optional)

Not generated — create manually if needed. Auto-loaded by `docker compose up`.

On ARM64 (Apple Silicon), some La Suite images have broken manifests. See [known limitations](known-limitations.md#broken-docker-images-arm64--invalid-user) for the workaround using `compose.override.yml`.

### Enabling Conversations (AI)

Conversations requires an OpenAI-compatible LLM endpoint. The setup prompts for:

- **AI base URL**: e.g. `http://192.168.1.100:11434/v1/` (Ollama)
- **AI model**: e.g. `llama3`, `mistral`, or a HuggingFace GGUF model name
- **AI API key**: `ollama` for Ollama (no real key needed)

To change the LLM config after setup, edit `environments/compose.yaml` and re-run `./generate-compose.sh`.

## Day-to-day operations

For regenerating, data management, troubleshooting, and architecture details, see the [helmfile2compose usage guide](https://github.com/baptisterajaut/helmfile2compose/blob/main/docs/usage-guide.md) and [architecture](https://github.com/baptisterajaut/helmfile2compose/blob/main/docs/architecture.md).
