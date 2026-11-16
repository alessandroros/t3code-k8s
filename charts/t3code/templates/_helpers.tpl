{{/* Chart name */}}
{{- define "t3code.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Fully qualified app name */}}
{{- define "t3code.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "t3code.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Selector labels */}}
{{- define "t3code.selectorLabels" -}}
app.kubernetes.io/name: {{ include "t3code.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Common labels */}}
{{- define "t3code.labels" -}}
helm.sh/chart: {{ include "t3code.chart" . }}
{{ include "t3code.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: t3code
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Common annotations block, merged with resource-specific ones.
Renders nothing when empty. Usage (at metadata level, 2-space indent):
  {{- with include "t3code.annotations" (dict "root" . "extra" .Values.x.annotations) }}{{ . | nindent 2 }}{{ end }}
*/}}
{{- define "t3code.annotations" -}}
{{- $all := merge (deepCopy (default (dict) .extra)) (deepCopy (default (dict) .root.Values.commonAnnotations)) -}}
{{- if $all -}}
annotations:
  {{- toYaml $all | nindent 2 }}
{{- end -}}
{{- end -}}

{{- define "t3code.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "t3code.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* Container image reference */}}
{{- define "t3code.image" -}}
{{- $repo := .Values.image.repository -}}
{{- if .Values.image.registry -}}
{{- $repo = printf "%s/%s" .Values.image.registry .Values.image.repository -}}
{{- end -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" $repo .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" $repo (default .Chart.AppVersion .Values.image.tag | toString) -}}
{{- end -}}
{{- end -}}

{{/* Public URL: explicit, else derived from ingress/route */}}
{{- define "t3code.publicUrl" -}}
{{- if .Values.t3.publicUrl -}}
{{- .Values.t3.publicUrl | trimSuffix "/" -}}
{{- else if and .Values.ingress.enabled .Values.ingress.hosts -}}
{{- $host := (index .Values.ingress.hosts 0).host -}}
{{- $tls := false -}}
{{- range .Values.ingress.tls }}{{- if has $host .hosts }}{{- $tls = true -}}{{- end }}{{- end -}}
{{- printf "%s://%s" (ternary "https" "http" $tls) $host -}}
{{- else if and .Values.route.enabled .Values.route.hostnames -}}
{{- printf "https://%s" (index .Values.route.hostnames 0) -}}
{{- end -}}
{{- end -}}

{{/* PVC storageClassName ("-" means empty string) */}}
{{- define "t3code.storageClass" -}}
{{- if . -}}
{{- if eq "-" . -}}
storageClassName: ""
{{- else -}}
storageClassName: {{ . | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Render a probe from values, dropping the "enabled" key */}}
{{- define "t3code.probe" -}}
{{- toYaml (omit . "enabled") -}}
{{- end -}}
