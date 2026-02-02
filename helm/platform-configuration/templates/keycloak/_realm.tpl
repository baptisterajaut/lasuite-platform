{{/*
Generate Keycloak realm JSON
*/}}
{{- define "keycloak-realm.json" -}}
{{- $seed := .Values.secretSeed | required "secretSeed is required" -}}
{{- $realm := .Values.keycloak.realm -}}
{{- $domain := .Values.domain -}}
{
  "realm": "{{ $realm }}",
  "enabled": true,
  "sslRequired": "external",
  "registrationAllowed": true,
  "loginWithEmailAllowed": true,
  "duplicateEmailsAllowed": false,
  "resetPasswordAllowed": true,
  "editUsernameAllowed": false,
  "bruteForceProtected": false,
  {{- if .Values.keycloak.testUser.enabled }}
  "users": [
    {
      "username": "{{ .Values.keycloak.testUser.username }}",
      "email": "{{ .Values.keycloak.testUser.email }}",
      "firstName": "Test",
      "lastName": "User",
      "enabled": true,
      "emailVerified": true,
      "credentials": [
        {
          "type": "password",
          "value": "{{ .Values.keycloak.testUser.password }}",
          "temporary": false
        }
      ]
    }
  ],
  {{- else }}
  "users": [],
  {{- end }}
  "clients": [
    {{- $clients := list -}}
    {{- if .Values.apps.docs.enabled -}}
    {{- $clientSecret := include "deriveSecret" (dict "seed" $seed "clientId" "docs-oidc-client") -}}
    {{- $clients = append $clients (printf `{"clientId": "docs", "name": "docs", "enabled": true, "clientAuthenticatorType": "client-secret", "secret": "%s", "redirectUris": ["https://docs.%s/*"], "webOrigins": ["https://docs.%s"], "standardFlowEnabled": true, "implicitFlowEnabled": false, "directAccessGrantsEnabled": false, "serviceAccountsEnabled": false, "publicClient": false, "frontchannelLogout": true, "protocol": "openid-connect", "attributes": {"post.logout.redirect.uris": "https://docs.%s/*", "user.info.response.signature.alg": "RS256"}, "defaultClientScopes": ["web-origins", "acr", "roles", "profile", "email"], "optionalClientScopes": ["address", "phone", "offline_access"]}` $clientSecret $domain $domain $domain) -}}
    {{- end -}}
    {{- if .Values.apps.meet.enabled -}}
    {{- $clientSecret := include "deriveSecret" (dict "seed" $seed "clientId" "meet-oidc-client") -}}
    {{- $clients = append $clients (printf `{"clientId": "meet", "name": "meet", "enabled": true, "clientAuthenticatorType": "client-secret", "secret": "%s", "redirectUris": ["https://meet.%s/*"], "webOrigins": ["https://meet.%s"], "standardFlowEnabled": true, "implicitFlowEnabled": false, "directAccessGrantsEnabled": false, "serviceAccountsEnabled": false, "publicClient": false, "frontchannelLogout": true, "protocol": "openid-connect", "attributes": {"post.logout.redirect.uris": "https://meet.%s/*", "user.info.response.signature.alg": "RS256"}, "defaultClientScopes": ["web-origins", "acr", "roles", "profile", "email"], "optionalClientScopes": ["address", "phone", "offline_access"]}` $clientSecret $domain $domain $domain) -}}
    {{- end -}}
    {{- if .Values.apps.drive.enabled -}}
    {{- $clientSecret := include "deriveSecret" (dict "seed" $seed "clientId" "drive-oidc-client") -}}
    {{- $clients = append $clients (printf `{"clientId": "drive", "name": "drive", "enabled": true, "clientAuthenticatorType": "client-secret", "secret": "%s", "redirectUris": ["https://drive.%s/*"], "webOrigins": ["https://drive.%s"], "standardFlowEnabled": true, "implicitFlowEnabled": false, "directAccessGrantsEnabled": false, "serviceAccountsEnabled": false, "publicClient": false, "frontchannelLogout": true, "protocol": "openid-connect", "attributes": {"post.logout.redirect.uris": "https://drive.%s/*", "user.info.response.signature.alg": "RS256"}, "defaultClientScopes": ["web-origins", "acr", "roles", "profile", "email"], "optionalClientScopes": ["address", "phone", "offline_access"]}` $clientSecret $domain $domain $domain) -}}
    {{- end -}}
    {{- if .Values.apps.desk.enabled -}}
    {{- $clientSecret := include "deriveSecret" (dict "seed" $seed "clientId" "desk-oidc-client") -}}
    {{- $clients = append $clients (printf `{"clientId": "desk", "name": "desk", "enabled": true, "clientAuthenticatorType": "client-secret", "secret": "%s", "redirectUris": ["https://desk.%s/*"], "webOrigins": ["https://desk.%s"], "standardFlowEnabled": true, "implicitFlowEnabled": false, "directAccessGrantsEnabled": false, "serviceAccountsEnabled": false, "publicClient": false, "frontchannelLogout": true, "protocol": "openid-connect", "attributes": {"post.logout.redirect.uris": "https://desk.%s/*", "user.info.response.signature.alg": "RS256"}, "defaultClientScopes": ["web-origins", "acr", "roles", "profile", "email"], "optionalClientScopes": ["address", "phone", "offline_access"]}` $clientSecret $domain $domain $domain) -}}
    {{- end -}}
    {{- if .Values.apps.conversations.enabled -}}
    {{- $clientSecret := include "deriveSecret" (dict "seed" $seed "clientId" "conversations-oidc-client") -}}
    {{- $clients = append $clients (printf `{"clientId": "conversations", "name": "conversations", "enabled": true, "clientAuthenticatorType": "client-secret", "secret": "%s", "redirectUris": ["https://conversations.%s/*"], "webOrigins": ["https://conversations.%s"], "standardFlowEnabled": true, "implicitFlowEnabled": false, "directAccessGrantsEnabled": false, "serviceAccountsEnabled": false, "publicClient": false, "frontchannelLogout": true, "protocol": "openid-connect", "attributes": {"post.logout.redirect.uris": "https://conversations.%s/*", "user.info.response.signature.alg": "RS256"}, "defaultClientScopes": ["web-origins", "acr", "roles", "profile", "email"], "optionalClientScopes": ["address", "phone", "offline_access"]}` $clientSecret $domain $domain $domain) -}}
    {{- end -}}
    {{ join "," $clients }}
  ],
  "defaultDefaultClientScopes": ["role_list", "profile", "email", "roles", "web-origins", "acr"],
  "defaultOptionalClientScopes": ["offline_access", "address", "phone"]
}
{{- end -}}
