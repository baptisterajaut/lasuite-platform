{{/*
Generate a deterministic secret from seed and client ID
Usage: {{ include "deriveSecret" (dict "seed" .Values.secretSeed "clientId" "postgres") }}
Optional: {{ include "deriveSecret" (dict "seed" .Values.secretSeed "clientId" "key" "length" 12) }}
Note: Default length is 50 (Django SECRET_KEY requires >= 50 chars)
*/}}
{{- define "deriveSecret" -}}
{{- $input := printf "%s:%s" .seed .clientId -}}
{{- $length := .length | default 50 -}}
{{- $input | sha256sum | trunc (int $length) -}}
{{- end -}}

{{/*
Get a secret value: use override if provided, otherwise derive from seed
Usage: {{ include "getSecret" (dict "root" . "id" "docs-db") }}
Optional length: {{ include "getSecret" (dict "root" . "id" "livekit-api-key" "length" 12) }}

Override via secretOverrides in values:
  secretOverrides:
    docs-db: "my_custom_password"
    docs-oidc-client: "my_client_secret"
*/}}
{{- define "getSecret" -}}
{{- $overrides := .root.Values.secretOverrides | default dict -}}
{{- $override := index $overrides .id -}}
{{- if $override -}}
{{- $override -}}
{{- else -}}
{{- include "deriveSecret" (dict "seed" .root.Values.secretSeed "clientId" .id "length" (.length | default 50)) -}}
{{- end -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "platform-configuration.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: lasuite
{{- end -}}

{{/*
Reflector annotations for secret replication
Usage: {{ include "reflector.annotations" "lasuite-docs,lasuite-meet" }}
*/}}
{{- define "reflector.annotations" -}}
reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: {{ . | quote }}
reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: {{ . | quote }}
{{- end -}}
