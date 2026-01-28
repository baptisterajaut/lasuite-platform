{{/*
Generate a deterministic secret from seed and client ID
Usage: {{ include "deriveSecret" (dict "seed" .Values.secretSeed "clientId" "postgres") }}
*/}}
{{- define "deriveSecret" -}}
{{- $input := printf "%s:%s" .seed .clientId -}}
{{- $input | sha256sum | trunc 48 -}}
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
