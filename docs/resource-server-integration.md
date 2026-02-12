# Resource Server Integration (Docs <-> Drive)

This document explains how to integrate Docs and Drive so that documents created in Docs appear in Drive and vice versa.

## Overview

By default, Docs and Drive are independent applications with separate storage:
- Docs stores files in `docs-media-storage` bucket
- Drive stores files in `drive-media-storage` bucket

To integrate them, Drive can act as a **Resource Server** that Docs calls via API to store/retrieve files.

## Architecture

```
+--------+                    +---------+                    +-------+
|  User  | -- browser -->     |  Docs   | -- API call -->    | Drive |
+--------+                    +---------+                    +-------+
                                   |                              |
                                   v                              v
                              (no direct S3)              +-------------+
                                                          | S3 / MinIO  |
                                                          +-------------+
```

With Resource Server enabled:
1. User creates a document in Docs
2. Docs calls Drive API to create/store the file
3. Drive stores the file in S3
4. File appears in both Docs and Drive interfaces

## Configuration

### 1. Drive Configuration (Resource Server)

Add these environment variables to Drive backend:

```yaml
# values/drive.yaml.gotmpl
backend:
  envVars:
    # Enable Resource Server
    OIDC_RESOURCE_SERVER_ENABLED: "True"
    OIDC_OP_URL: https://auth.{{ .Values.domain }}/realms/{{ .Values.keycloak.realm }}
    OIDC_OP_INTROSPECTION_ENDPOINT: http://keycloak-keycloakx-http.lasuite-keycloak.svc.cluster.local/realms/{{ .Values.keycloak.realm }}/protocol/openid-connect/token/introspect
    OIDC_RS_CLIENT_ID: drive
    OIDC_RS_CLIENT_SECRET:
      secretKeyRef:
        name: drive-secrets
        key: OIDC_RP_CLIENT_SECRET
    OIDC_RS_AUDIENCE_CLAIM: aud
    OIDC_RS_ALLOWED_AUDIENCES: drive,docs

    # External API configuration (what endpoints docs can call)
    EXTERNAL_API: |
      {
        "items": {
          "enabled": true,
          "actions": ["list", "retrieve", "create", "update", "partial_update", "destroy", "children", "upload_ended", "move", "restore", "trashbin", "hard_delete", "tree", "breadcrumb", "link_configuration", "favorite", "media_auth", "wopi"]
        },
        "item_access": {
          "enabled": true,
          "actions": ["list", "retrieve", "create", "update", "partial_update", "destroy"]
        },
        "item_invitation": {
          "enabled": true,
          "actions": ["list", "retrieve", "create", "update", "partial_update", "destroy"]
        },
        "users": {
          "enabled": true,
          "actions": ["get_me"]
        }
      }
```

### 2. Docs Configuration (Resource Client)

Add these environment variables to Docs backend:

```yaml
# values/docs.yaml.gotmpl
backend:
  envVars:
    # Drive API integration
    DRIVE_API_ENABLED: "True"
    DRIVE_API_URL: http://drive-backend.lasuite-drive.svc.cluster.local/external_api/v1.0

    # OIDC configuration for calling Drive
    OIDC_RESOURCE_CLIENT_ID: docs
    OIDC_RESOURCE_CLIENT_SECRET:
      secretKeyRef:
        name: docs-secrets
        key: OIDC_RP_CLIENT_SECRET
```

### 3. Keycloak Configuration

The OIDC clients need to be configured to allow token exchange:

1. In Keycloak admin console, go to `lasuite` realm
2. Edit the `docs` client:
   - Enable "Service Accounts Enabled"
   - Add `drive` to "Valid Redirect URIs" (or use `*` for dev)
3. Edit the `drive` client:
   - Add `docs` to allowed audiences

## API Endpoints

Once configured, Docs can call these Drive endpoints:

| Endpoint | Description |
|----------|-------------|
| `GET /external_api/v1.0/items/` | List items (files/folders) |
| `POST /external_api/v1.0/items/{id}/children/` | Create file/folder |
| `GET /external_api/v1.0/items/{id}/` | Get item details |
| `PUT /external_api/v1.0/items/{id}/` | Update item |
| `DELETE /external_api/v1.0/items/{id}/` | Delete item |
| `GET /external_api/v1.0/users/me/` | Get current user info |

## Example: Upload Flow

1. Docs gets user's main workspace from Drive:
   ```
   GET /external_api/v1.0/items/
   Authorization: Bearer <access_token>
   ```

2. Docs creates a new file in the workspace:
   ```
   POST /external_api/v1.0/items/{workspace_id}/children/
   {
     "type": "file",
     "filename": "document.md"
   }
   ```

3. Docs uploads content using the presigned URL from the response

4. Docs notifies Drive that upload is complete:
   ```
   POST /external_api/v1.0/items/{item_id}/upload-ended/
   ```

## Status

**BLOCKED** - Waiting for Docs implementation.

**Current state (January 2026):**
- **Drive**: Resource Server code is complete and ready (`/external_api/v1.0/` endpoints)
- **Docs**: Has token storage settings (`OIDC_STORE_ACCESS_TOKEN`, etc.) but **no code to call Drive**
  - No `DRIVE_API` setting exists
  - No views or services that call Drive's external API

The integration will be possible when a future version of Docs implements the Drive API client code.

**What's missing in Docs:**
1. `DRIVE_API` setting (URL to Drive's external API)
2. Views/services that call Drive using stored access tokens
3. UI integration to display Drive files

This document is a reference for future integration. The current setup uses independent storage for docs and drive.

## References

- [Drive Resource Server Documentation](https://github.com/suitenumerique/drive/blob/main/docs/resource_server.md)
- [django-lasuite OIDC Resource Server](https://github.com/suitenumerique/django-lasuite/blob/main/documentation/how-to-use-oidc-resource-server-backend.md)
- [django-lasuite OIDC Resource Client](https://github.com/suitenumerique/django-lasuite/blob/main/documentation/how-to-use-oidc-call-to-resource-server.md)
