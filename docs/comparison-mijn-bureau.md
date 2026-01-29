# Comparison: lasuite-platform vs mijn-bureau-infra

Two open-source projects deploying La Suite on Kubernetes with different philosophies.

| | **lasuite-platform** | **mijn-bureau-infra** |
|---|---|---|
| **Maintainer** | Individual (unaffiliated) | MinBZK (Netherlands) |
| **Repository** | This repo | [MinBZK/mijn-bureau-infra](https://github.com/MinBZK/mijn-bureau-infra) |
| **License** | None (repo) / MIT (La Suite code) | EUPL-1.2 |

> **Note**: This repository is maintained by an individual with no affiliation to DINUM or the French government. La Suite applications themselves are developed and maintained by DINUM under the MIT license.

## Quick Comparison

| Aspect | lasuite-platform | mijn-bureau-infra |
|--------|----------------|-------------------|
| **Goal** | Simple reference deployment | Production-grade platform |
| **Local setup** | One command (`./init.sh`) | Manual configuration |
| **Learning curve** | Low | Medium-High |
| **Customization** | Single environment file | 20+ modular config files |
| **Infrastructure** | Shared (1 PG, 1 Redis, 1 MinIO) | Per-app isolation (demo mode) |
| **Charts** | Remote (official repos) | Vendored locally |
| **Auto-updates** | Manual | UpdateCli (automatic PRs) |
| **Security policies** | None | OPA/Rego validation |
| **Extra apps** | La Suite only | +Nextcloud, Element, Collabora, Grist, Ollama |

## Architecture

### lasuite-platform

```
helmfile.yaml.gotmpl
├── values/
│   ├── docs.yaml.gotmpl
│   ├── meet.yaml.gotmpl
│   └── ...
├── environments/
│   ├── local.yaml
│   └── <env>.yaml
└── helm/
    └── platform-configuration/   # Secrets, ClusterIssuers
```

- **Single helmfile** with all releases
- **Shared infrastructure**: one PostgreSQL, one Redis, one MinIO for all apps
- **Remote charts**: pulled from official Helm repos
- **Simple secrets**: `deriveSecret` function from a single seed

### mijn-bureau-infra

```
helmfile.yaml.gotmpl
├── helmfile/
│   ├── apps/
│   │   ├── docs/
│   │   │   ├── helmfile-child.yaml.gotmpl
│   │   │   ├── charts/docs/          # Vendored chart
│   │   │   ├── values.yaml.gotmpl
│   │   │   ├── values-postgresql.yaml.gotmpl
│   │   │   ├── values-redis.yaml.gotmpl
│   │   │   └── values-minio.yaml.gotmpl
│   │   ├── meet/
│   │   ├── drive/
│   │   └── ...
│   ├── bases/
│   │   └── logic/                    # Conditional logic
│   └── environments/
│       └── default/
│           ├── application.yaml.gotmpl
│           ├── database.yaml.gotmpl
│           ├── cache.yaml.gotmpl
│           ├── security.yaml.gotmpl
│           └── ... (20+ files)
├── policy/                           # OPA/Rego policies
├── updatecli/                        # Auto-update configs
└── tests/                            # Config validation
```

- **Child helmfiles**: each app is a mini-project with its own helmfile
- **Per-app infrastructure** (demo mode): each app gets its own PG/Redis/MinIO
- **Vendored charts**: local copies in `apps/<app>/charts/`
- **Modular config**: 20+ YAML files for different concerns (ai, cache, security...)

## DevOps Tooling

| Tool | lasuite-platform | mijn-bureau-infra |
|------|----------------|-------------------|
| **UpdateCli** | No | Yes - auto PRs for version bumps |
| **OPA Policies** | No | Yes - security validation |
| **Pre-commit** | No | Yes - linting, formatting |
| **DevContainers** | No | Yes - standardized dev env |
| **Cosign** | No | Yes - image verification |
| **SOPS** | No | Yes - encrypted secrets |
| **CI Tests** | No | Yes - config validation |

## Applications

| App | lasuite-platform | mijn-bureau-infra |
|-----|----------------|-------------------|
| Docs | Yes | Yes |
| Meet | Yes | Yes |
| Drive | Yes | Yes |
| Desk (People) | Yes | No |
| Conversations | Yes | Yes |
| **Nextcloud** | No | Yes |
| **Element/Matrix** | No | Yes |
| **Collabora** | No | Yes |
| **Grist** | No | Yes |
| **Ollama (LLM)** | No | Yes |
| **ClamAV** | No | Yes |
| **OpenProject** | No | Yes (disabled) |
| **Bureaublad** | No | Yes (portal) |

## When to Use Which

### Choose lasuite-platform if:

- You just are **testing basic La Suite features**
- You want a simple **reference starting point** for your own deployment
- ~~You like to play with fire~~

### Choose mijn-bureau-infra if:

- You know what you're doing
- You are a serious person
- You need a **production-ready platform** with security policies
- You want **automatic version updates** via UpdateCli
- You need **per-app isolation** for compliance
- You want a **complete collaboration suite** (file sharing, chat, office)
- You have a **dedicated platform team** to maintain it
- You need **OPA policy validation** for security compliance

## Key Differences Explained

### Infrastructure Isolation

**lasuite-platform**: All apps share one PostgreSQL instance with separate databases. Simpler, fewer resources, but less isolation.

**mijn-bureau-infra**: In demo mode, each app gets its own PostgreSQL/Redis/MinIO. More resources, but better isolation for production.

### Chart Management

**lasuite-platform**: Uses remote charts from official repos. Simpler updates, but dependent on upstream availability.

**mijn-bureau-infra**: Vendors charts locally in `apps/<app>/charts/`. More control, can patch issues, but requires manual sync with upstream.

### Configuration Philosophy

**lasuite-platform**: One environment file (`environments/local.yaml`) with all settings. Easy to understand, quick to modify.

**mijn-bureau-infra**: 20+ modular files (ai.yaml, security.yaml, database.yaml...). Better separation of concerns, but steeper learning curve.

### Secret Management

**lasuite-platform**: `deriveSecret` generates secrets from a single seed. No encryption at rest.

**mijn-bureau-infra**: `derivePassword` (similar) plus SOPS for encrypted secrets in git.

## Migration Path

Starting with lasuite-platform and need to scale up? Here's what to adopt from mijn-bureau-infra:

1. **UpdateCli** - Add automatic version bump PRs
2. **OPA Policies** - Add security validation to CI
3. **Per-app databases** - Split shared PostgreSQL into per-app instances
4. **Vendored charts** - Copy charts locally for more control

## Links

- **lasuite-platform**: (this repository)
- **mijn-bureau-infra**: https://github.com/MinBZK/mijn-bureau-infra
- **Documentation**: https://minbzk.github.io/mijn-bureau-infra/
