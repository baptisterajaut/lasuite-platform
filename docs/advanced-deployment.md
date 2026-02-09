# Advanced Deployment

This guide explains how to deploy La Suite with existing infrastructure (PostgreSQL, Keycloak, S3).

## Table of Contents

- [How Secrets Work](#how-secrets-work)
- [Using Custom Secrets](#using-custom-secrets)
- [Using an Existing PostgreSQL](#using-an-existing-postgresql)
- [Using an Existing Keycloak](#using-an-existing-keycloak)
- [Using an Existing S3](#using-an-existing-s3)
- [Production Deployment](#production-deployment)
- [Troubleshooting](#troubleshooting)

---

## How Secrets Work

All secrets (DB passwords, OIDC client secrets, S3 keys...) are **automatically derived** from a single `secretSeed`. The formula is:

```
secret = sha256(secretSeed + ":" + identifier)[:50]
```

This means that using the same `secretSeed` will always produce the same secrets. This is useful for:
- Regenerating secrets without storing them
- Having consistent secrets between helmfile and your external infrastructure

To compute a specific secret:

```bash
SEED=$(grep secretSeed environments/local.yaml | cut -d'"' -f2)
echo -n "${SEED}:docs-db" | shasum -a 256 | cut -c1-50
```

Identifiers used:

| Identifier | Usage |
|------------|-------|
| `postgres-admin` | PostgreSQL admin password |
| `postgres` | PostgreSQL app user password |
| `keycloak-db` | Keycloak database password |
| `keycloak-admin` | Keycloak admin console password |
| `docs-db` | Docs DB password |
| `meet-db` | Meet DB password |
| `drive-db` | Drive DB password |
| `people-db` | People DB password |
| `conversations-db` | Conversations DB password |
| `find-db` | Find DB password |
| `redis` | Redis password |
| `s3-access` | S3 access key |
| `s3-secret` | S3 secret key |
| `docs-oidc-client` | Docs OIDC client secret |
| `meet-oidc-client` | Meet OIDC client secret |
| `drive-oidc-client` | Drive OIDC client secret |
| `people-oidc-client` | People OIDC client secret |
| `conversations-oidc-client` | Conversations OIDC client secret |
| `find-oidc-client` | Find OIDC client secret |
| `livekit-api-key` | LiveKit API key |
| `livekit-api-secret` | LiveKit API secret |
| `opensearch-admin` | OpenSearch admin password |

> **Note**: Keycloak credentials (`keycloak-db`, `keycloak-admin`) are derived in `values/keycloak.yaml.gotmpl`, not in platform-configuration.

> **Note**: For derived secrets, `!Os0` is appended to the `opensearch-admin` password to satisfy OpenSearch complexity requirements (SHA256 hex only produces `[0-9a-f]`). When using `secretOverrides`, the suffix is **not** appended -- your override value is used as-is.

---

## Using Custom Secrets

If you have existing credentials that you cannot change (e.g., existing database passwords, S3 keys from your cloud provider), you can override individual secrets.

### Method 1: Secret Overrides File

Create a file `environments/my-env.secret-overrides.yaml`:

```yaml
secretOverrides:
  # Database passwords
  docs-db: "my_existing_docs_password"
  meet-db: "my_existing_meet_password"
  drive-db: "my_existing_drive_password"

  # S3 credentials
  s3-access: "AKIAIOSFODNN7EXAMPLE"
  s3-secret: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

  # OIDC client secrets (from your Keycloak)
  docs-oidc-client: "existing-client-secret-for-docs"
  meet-oidc-client: "existing-client-secret-for-meet"
  drive-oidc-client: "existing-client-secret-for-drive"

  # Redis (if using external Redis with auth)
  redis: "my_redis_password"
```

Then add this file to your environment in `helmfile.yaml.gotmpl`:

```yaml
environments:
  my-env:
    values:
      - versions/backend-helm-versions.yaml
      - versions/lasuite-helm-versions.yaml
      - environments/my-env.yaml
      - environments/my-env.secret-overrides.yaml  # Add this
      - environments/_computed.yaml.gotmpl
```

### Method 2: Inline in environment file

You can also add overrides directly in your environment file (`environments/my-env.yaml`):

```yaml
secretSeed: "your_seed_here"

secretOverrides:
  docs-db: "my_custom_password"
  s3-access: "AKIA..."
  s3-secret: "..."
```

### How It Works

The `getSecret` helper in `platform-configuration` checks for overrides:

1. If `secretOverrides.<identifier>` exists, use that value
2. Otherwise, derive from `secretSeed` using SHA256

This means you can mix derived and custom secrets:
- Use derived secrets for internal components (Django secret keys, collaboration secrets)
- Use custom secrets for external services (existing DB, S3, Keycloak)

### Available Identifiers

| Identifier | Used For |
|------------|----------|
| `postgres-admin` | PostgreSQL superuser |
| `postgres` | PostgreSQL app user |
| `keycloak-db` | Keycloak database password |
| `keycloak-admin` | Keycloak admin console password |
| `docs-db` | Docs database password |
| `meet-db` | Meet database password |
| `drive-db` | Drive database password |
| `redis` | Redis password |
| `s3-access` | S3 access key |
| `s3-secret` | S3 secret key |
| `docs-oidc-client` | Docs OIDC client secret |
| `meet-oidc-client` | Meet OIDC client secret |
| `drive-oidc-client` | Drive OIDC client secret |
| `docs-django-secret` | Docs Django SECRET_KEY |
| `meet-django-secret` | Meet Django SECRET_KEY |
| `drive-django-secret` | Drive Django SECRET_KEY |
| `people-django-secret` | People Django SECRET_KEY |
| `conversations-django-secret` | Conversations Django SECRET_KEY |
| `find-django-secret` | Find Django SECRET_KEY |
| `docs-superuser` | Docs admin password |
| `meet-superuser` | Meet admin password |
| `drive-superuser` | Drive admin password |
| `people-superuser` | People admin password |
| `conversations-superuser` | Conversations admin password |
| `find-superuser` | Find admin password |
| `livekit-api-key` | LiveKit API key |
| `livekit-api-secret` | LiveKit API secret |
| `docs-collaboration` | Y-Provider secret |
| `opensearch-admin` | OpenSearch admin password (`!Os0` appended only for derived secrets) |

---

## Using an Existing PostgreSQL

If you already have a PostgreSQL server, you can use it instead of deploying the one from helmfile.

### 1. Create the databases

Create databases and users with your own passwords:

```sql
-- Keycloak
CREATE DATABASE keycloak;
CREATE USER keycloak WITH ENCRYPTED PASSWORD 'your_keycloak_db_password';
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
ALTER DATABASE keycloak OWNER TO keycloak;

-- Docs
CREATE DATABASE docs;
CREATE USER docs WITH SUPERUSER ENCRYPTED PASSWORD 'your_docs_db_password';
GRANT ALL PRIVILEGES ON DATABASE docs TO docs;
ALTER DATABASE docs OWNER TO docs;

-- Required extensions (run in each database)
\c docs
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Same for meet and drive...
```

> **Note**: Django users require `SUPERUSER` for migrations that create C functions.

### 2. Configure the environment

```yaml
# environments/my-env.yaml

postgres:
  enabled: false  # Do not deploy PostgreSQL
  host: postgres.example.com
  port: 5432
```

### 3. Set the passwords

In `environments/my-env.secret-overrides.yaml`:

```yaml
secretOverrides:
  keycloak-db: "your_keycloak_db_password"
  docs-db: "your_docs_db_password"
  meet-db: "your_meet_db_password"
  drive-db: "your_drive_db_password"
```

---

## Using an Existing Keycloak

If you already have a Keycloak, you can use it for OIDC authentication.

### 1. Create the realm and clients

In your Keycloak, create:

1. **A realm** (e.g., `lasuite`)
2. **A client per application**:

| Client ID | Access Type | Redirect URIs |
|-----------|-------------|---------------|
| `docs` | confidential | `https://docs.example.com/*` |
| `meet` | confidential | `https://meet.example.com/*` |
| `drive` | confidential | `https://drive.example.com/*` |

Note the **Client Secret** generated for each client.

### 2. Configure the environment

```yaml
# environments/my-env.yaml

keycloak:
  enabled: false  # Do not deploy Keycloak
  realm: lasuite  # Your realm name
  externalUrl: https://sso.example.com  # Public URL (browser redirects)
  backendUrl: https://sso.example.com   # URL for backend calls (can be internal)
```

> **Note**: If your Keycloak is accessible from pods via a different internal URL, use `backendUrl` for token/JWKS calls (better performance, avoids DNS issues).

### 3. Set the client secrets

In `environments/my-env.secret-overrides.yaml`:

```yaml
secretOverrides:
  docs-oidc-client: "client-secret-from-keycloak-for-docs"
  meet-oidc-client: "client-secret-from-keycloak-for-meet"
  drive-oidc-client: "client-secret-from-keycloak-for-drive"
```

---

## Using an Existing S3

For production, use a real S3 storage (AWS, OOS/Outscale, Scaleway, OVH, external MinIO).

### 1. Create buckets and credentials

On your S3 provider:
1. Create an IAM user or access key
2. Create the buckets: `docs-media-storage`, `drive-media-storage`
3. Grant the user read/write permissions on those buckets

### 2. Configure the environment

```yaml
# environments/my-env.yaml

minio:
  enabled: false  # Do not deploy MinIO

s3:
  provider: aws  # aws | oos | minio
  endpoint: https://s3.eu-west-1.amazonaws.com
  host: s3.eu-west-1.amazonaws.com
  port: 443
```

**For OOS (Outscale Object Storage):**

```yaml
s3:
  provider: oos
  endpoint: https://oos.eu-west-2.outscale.com
  host: oos.eu-west-2.outscale.com
  port: 443
```

Setting `provider: oos` adds compatibility env vars (`AWS_REQUEST_CHECKSUM_CALCULATION`, `AWS_RESPONSE_CHECKSUM_VALIDATION`) required for newer AWS SDK versions.

### 3. Set the credentials

In `environments/my-env.secret-overrides.yaml`:

```yaml
secretOverrides:
  s3-access: "AKIAIOSFODNN7EXAMPLE"
  s3-secret: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

---

## Production Deployment

> **Alternative**: For a more comprehensive production setup with UpdateCli, OPA policies, and per-app isolation, consider [MinBZK/mijn-bureau-infra](https://github.com/MinBZK/mijn-bureau-infra). See [comparison](comparison-mijn-bureau.md).

### 1. Run the init script

```bash
./init.sh
# Choose option 2 (Remote deployment)
# Enter: environment name, domain, admin email
```

This creates:
- `environments/<name>.yaml` - environment configuration (includes secretSeed)

### 2. Review the configuration

Edit `environments/<name>.yaml` to adjust:

```yaml
# Infrastructure - set to false if using external services
postgres:
  enabled: true   # false if external PostgreSQL
  host: lasuite-postgresql.lasuite-postgresql.svc.cluster.local

keycloak:
  enabled: true   # false if external Keycloak
  realm: lasuite

redis:
  enabled: true

minio:
  enabled: false  # Always false in production

certManager:
  enabled: true   # false if already installed

ingress:
  className: haproxy  # adapt to your cluster
```

### 3. Add environment to helmfile

Add the environment block shown by `init.sh` to `helmfile.yaml.gotmpl`.

### 4. Deploy

```bash
helmfile -e <name> sync
```

---

## Troubleshooting

### Pods cannot connect to Keycloak

Verify that `backendUrl` is accessible from pods:

```bash
kubectl run test --rm -it --image=curlimages/curl -- \
  curl -v https://sso.example.com/realms/lasuite/.well-known/openid-configuration
```

If using an internal certificate, add `OIDC_VERIFY_SSL: "false"` temporarily for debugging.

### "relation does not exist" error

Django migrations have not been executed. Check the logs:

```bash
kubectl logs -n lasuite-docs job/docs-backend-migrate
```

### Missing PostgreSQL extensions

```sql
\c docs
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;
```

### Retrieve a secret

```bash
SEED=$(grep secretSeed environments/local.yaml | cut -d'"' -f2)
echo -n "${SEED}:<identifier>" | shasum -a 256 | cut -c1-50
```
