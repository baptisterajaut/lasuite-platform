{{/*
Generate a deterministic secret from seed and client ID
*/}}
{{- define "deriveSecret" -}}
{{- $input := printf "%s:%s" .seed .clientId -}}
{{- $input | sha256sum | trunc 48 -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "keycloak-realm.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: lasuite
{{- end -}}
