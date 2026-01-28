{{/*
Generate Keycloak realm JSON
*/}}
{{- define "keycloak-realm.json" -}}
{{- $seed := .Values.secretSeed | required "secretSeed is required" -}}
{{- $realm := .Values.realm -}}
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
  {{- if .Values.testUser.enabled }}
  "users": [
    {
      "username": "{{ .Values.testUser.username }}",
      "email": "{{ .Values.testUser.email }}",
      "firstName": "Test",
      "lastName": "User",
      "enabled": true,
      "emailVerified": true,
      "credentials": [
        {
          "type": "password",
          "value": "{{ .Values.testUser.password }}"
        }
      ]
    }
  ],
  {{- else }}
  "users": [],
  {{- end }}
  "clients": [
    {{- $clients := list -}}
    {{- range .Values.appsEnabled }}
    {{- $appName := . -}}
    {{- $clientSecret := include "deriveSecret" (dict "seed" $seed "clientId" (printf "%s-oidc-client" $appName)) -}}
    {{- $client := printf `{
      "clientId": "%s",
      "name": "%s",
      "enabled": true,
      "clientAuthenticatorType": "client-secret",
      "secret": "%s",
      "redirectUris": ["https://%s.%s/*"],
      "webOrigins": ["https://%s.%s"],
      "standardFlowEnabled": true,
      "implicitFlowEnabled": false,
      "directAccessGrantsEnabled": false,
      "serviceAccountsEnabled": false,
      "publicClient": false,
      "frontchannelLogout": true,
      "protocol": "openid-connect",
      "attributes": {
        "post.logout.redirect.uris": "https://%s.%s/*",
        "user.info.response.signature.alg": "RS256"
      },
      "defaultClientScopes": ["web-origins", "acr", "roles", "profile", "email"],
      "optionalClientScopes": ["address", "phone", "offline_access"]
    }` $appName $appName $clientSecret $appName $domain $appName $domain $appName $domain -}}
    {{- $clients = append $clients $client -}}
    {{- end }}
    {{ join "," $clients }}
  ],
  "defaultDefaultClientScopes": ["role_list", "profile", "email", "roles", "web-origins", "acr"],
  "defaultOptionalClientScopes": ["offline_access", "address", "phone"]
}
{{- end -}}
