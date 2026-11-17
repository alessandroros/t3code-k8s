# t3code

![Version: 0.1.2](https://img.shields.io/badge/Version-0.1.2-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.10](https://img.shields.io/badge/AppVersion-0.1.10-informational?style=flat-square)

Self-host the T3 Code server (control plane for coding agents like Claude Code, Codex and OpenCode) on Kubernetes. Unofficial.

> **Unofficial.** T3 Code is built by [Ping Labs](https://github.com/pingdotgg/t3code). This chart and its image are a community project and are not affiliated with or endorsed by them.

Run the T3 Code server on your cluster so threads, repositories, terminals and agent logins live in one place, and connect from the desktop, mobile or web client from anywhere on your private network.

## TL;DR

```bash
helm install t3 oci://ghcr.io/alessandroros/charts/t3code -n t3code --create-namespace
kubectl -n t3code exec -it t3-t3code-0 -c t3code -- t3-pair
```

## What you get

- One-replica `StatefulSet` running `t3 serve`, with two volumes:
  - `home` (`/home/t3`): T3 state (SQLite), pairing/sessions, agent logins, agent CLIs
  - `workspace` (`/workspace`): your git checkouts
- Agent CLIs (Claude Code, Codex, … any npm package) installed on the home volume by an initContainer, so the image only tracks the T3 version
- Non-root, Pod Security `restricted` compatible, no ServiceAccount token
- Optional Ingress, Gateway API `HTTPRoute`, `LoadBalancer`, and a `NetworkPolicy` that keeps agents off your cluster network

## Requirements

- Kubernetes >=1.25.0-0, Helm 3.8+ (OCI) or Helm 4
- A `ReadWriteOnce` StorageClass. Avoid NFS for `home`: T3 stores state in SQLite
- A private way in (VPN, Tailscale, internal ingress). **Do not expose T3 on the public internet**: a pairing link gives full control of an agent that runs commands. See [docs/security.md](../../docs/security.md)

## Access

| Scenario | Values |
|---|---|
| Quick test | `kubectl port-forward svc/t3-t3code 3773:80` |
| VPN (WireGuard) + MetalLB/kube-vip | `service.type=LoadBalancer`, `service.loadBalancerIP`, `service.loadBalancerSourceRanges`, `t3.publicUrl` |
| Internal ingress with TLS | `ingress.enabled=true` (+ cert-manager); raise WebSocket timeouts |
| Gateway API | `route.enabled=true`, `route.parentRefs` |

More in [docs/access.md](../../docs/access.md).

## Agent sign-in

Either sign in once interactively (credentials persist on the home volume):

```bash
kubectl -n t3code exec -it t3-t3code-0 -c t3code -- claude auth login
kubectl -n t3code exec -it t3-t3code-0 -c t3code -- codex login
```

or provide keys/tokens from a Secret:

```bash
kubectl -n t3code create secret generic t3-agent-keys \
  --from-literal=CLAUDE_CODE_OAUTH_TOKEN=... --from-literal=GH_TOKEN=...
helm upgrade t3 oci://ghcr.io/alessandroros/charts/t3code -n t3code --reuse-values --set existingSecret=t3-agent-keys
```

## Upgrades

The chart `appVersion` is the T3 Code version, and new T3 releases are picked up automatically (see [docs/upgrading.md](../../docs/upgrading.md)). Restarting the pod stops running agent turns. Keep your desktop/mobile clients reasonably close to the server version: T3 refuses pairing across incompatible protocol versions.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity |
| agents.install | bool | `true` | Install coding-agent CLIs onto the home volume with an initContainer. Agents are not baked into the image: they release almost daily and most update themselves. |
| agents.packages | list | `["@anthropic-ai/claude-code","@openai/codex"]` | npm package specs to install (pin with `@version` if you want). T3 also uses Codex for thread titles unless you switch the title provider. |
| agents.resources | object | `{}` | Resources for the install initContainer |
| agents.strict | bool | `false` | Fail the pod start if an install fails |
| agents.updatePolicy | string | `"missing"` | `missing`: install only absent packages (agents self-update). `always`: reinstall the requested spec on every pod start. |
| commonAnnotations | object | `{}` | Annotations added to every resource |
| commonLabels | object | `{}` | Labels added to every resource |
| containerSecurityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":false}` | Container security context (Pod Security "restricted" compatible) |
| dnsConfig | object | `{}` | DNS config |
| existingSecret | string | `""` | Name of an existing Secret loaded as environment variables (e.g. `ANTHROPIC_API_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`, `OPENAI_API_KEY`, `GH_TOKEN`). Not needed if you sign agents in interactively: logins persist on the home volume. |
| extraContainers | list | `[]` | Extra sidecar containers |
| extraEnv | list | `[]` | Extra environment variables (list of EnvVar) |
| extraEnvFrom | list | `[]` | Extra envFrom sources (list of EnvFromSource) |
| extraInitContainers | list | `[]` | Extra init containers |
| extraObjects | list | `[]` | Extra Kubernetes objects to deploy (templated) |
| extraVolumeMounts | list | `[]` | Extra volume mounts for the t3 container |
| extraVolumes | list | `[]` | Extra volumes |
| fullnameOverride | string | `""` | Override the full resource name |
| hostAliases | list | `[]` | Host aliases |
| image.digest | string | `""` | Image digest (`sha256:...`). Overrides the tag when set |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.registry | string | `"ghcr.io"` | Image registry |
| image.repository | string | `"alessandroros/t3code"` | Image repository |
| image.tag | string | `""` | Image tag. Defaults to the chart appVersion (= T3 Code version) |
| imagePullSecrets | list | `[]` | Image pull secrets |
| ingress.annotations | object | `{}` | Ingress annotations |
| ingress.className | string | `""` | IngressClass name |
| ingress.enabled | bool | `false` | Enable an Ingress. Long-lived WebSockets: raise your controller's timeouts |
| ingress.hosts | list | `[{"host":"t3code.example.lan","paths":[{"path":"/","pathType":"Prefix"}]}]` | Hosts |
| ingress.tls | list | `[]` | TLS |
| livenessProbe | object | `{"enabled":true,"failureThreshold":5,"httpGet":{"path":"/api/auth/session","port":"http"},"periodSeconds":30,"timeoutSeconds":5}` | Liveness probe |
| nameOverride | string | `""` | Override the chart name |
| networkPolicy.egress.deniedCidrs | list | `["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16","100.64.0.0/10","169.254.0.0/16","fc00::/7","fe80::/10"]` | Ranges denied when `restrict` is true |
| networkPolicy.egress.extraTo | list | `[]` | Extra allowed destinations (e.g. an internal git server or proxy) |
| networkPolicy.egress.restrict | bool | `true` | Restrict egress: allow DNS and the public internet, deny private ranges (cluster pods/services, LAN) so agents cannot reach the rest of your cluster |
| networkPolicy.enabled | bool | `false` | Create a NetworkPolicy (needs a CNI that enforces it) |
| networkPolicy.ingress.from | list | `[]` | Allowed sources for the T3 port. Empty = any source. Typically your ingress controller namespace and/or your VPN CIDR. |
| nodeSelector | object | `{}` | Node selector |
| persistence.home.accessModes | list | `["ReadWriteOnce"]` | Access modes |
| persistence.home.annotations | object | `{}` | PVC annotations |
| persistence.home.enabled | bool | `true` | Persist /home/t3: T3 state (SQLite), provider logins, agents, caches. Disabling it loses everything on restart. |
| persistence.home.existingClaim | string | `""` | Use an existing PVC |
| persistence.home.size | string | `"20Gi"` | Size |
| persistence.home.storageClass | string | `""` | StorageClass (`-` for none, empty for cluster default). Avoid NFS: T3 uses SQLite |
| persistence.workspace.accessModes | list | `["ReadWriteOnce"]` | Access modes |
| persistence.workspace.annotations | object | `{}` | PVC annotations |
| persistence.workspace.enabled | bool | `true` | Persist /workspace: your repositories (one project per git checkout) |
| persistence.workspace.existingClaim | string | `""` | Use an existing PVC |
| persistence.workspace.size | string | `"50Gi"` | Size |
| persistence.workspace.storageClass | string | `""` | StorageClass (`-` for none, empty for cluster default) |
| persistentVolumeClaimRetentionPolicy | object | `{"whenDeleted":"Retain","whenScaled":"Retain"}` | What happens to the PVCs when the StatefulSet is deleted or scaled (`Retain` keeps your data on `helm uninstall`) |
| podAnnotations | object | `{}` | Pod annotations |
| podLabels | object | `{}` | Pod labels |
| podSecurityContext | object | `{"fsGroup":1000,"fsGroupChangePolicy":"OnRootMismatch","runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod security context |
| priorityClassName | string | `""` | Priority class |
| readinessProbe | object | `{"enabled":true,"failureThreshold":3,"httpGet":{"path":"/api/auth/session","port":"http"},"periodSeconds":10,"timeoutSeconds":5}` | Readiness probe |
| resources | object | `{"limits":{"memory":"6Gi"},"requests":{"cpu":"500m","memory":"2Gi"}}` | Resources. The server is light; agents, builds and tests are not. |
| route.annotations | object | `{}` | Route annotations |
| route.enabled | bool | `false` | Enable a Gateway API HTTPRoute |
| route.filters | list | `[]` | Filters |
| route.hostnames | list | `[]` | Hostnames |
| route.matches | list | `[{"path":{"type":"PathPrefix","value":"/"}}]` | Extra rule matches (default: all paths) |
| route.parentRefs | list | `[]` | Gateways to attach to |
| runtimeClassName | string | `""` | RuntimeClass (e.g. `gvisor` or `kata` for stronger sandboxing of agents) |
| service.annotations | object | `{}` | Service annotations |
| service.externalTrafficPolicy | string | `""` | External traffic policy (`Local` preserves client IPs) |
| service.labels | object | `{}` | Service labels |
| service.loadBalancerClass | string | `""` | Load balancer class |
| service.loadBalancerIP | string | `""` | Load balancer IP (if supported) |
| service.loadBalancerSourceRanges | list | `[]` | Allowed source ranges for type LoadBalancer |
| service.nodePort | string | `nil` | NodePort (type NodePort only) |
| service.port | int | `80` | Service port |
| service.type | string | `"ClusterIP"` | Service type (`LoadBalancer` with an internal IP is handy for VPN access) |
| serviceAccount.annotations | object | `{}` | ServiceAccount annotations |
| serviceAccount.automountServiceAccountToken | bool | `false` | Mount the ServiceAccount token. Keep false: agents run arbitrary commands and must not talk to the Kubernetes API. |
| serviceAccount.create | bool | `true` | Create a ServiceAccount |
| serviceAccount.name | string | `""` | ServiceAccount name (generated if empty) |
| shm.enabled | bool | `true` | Mount a memory-backed /dev/shm (needed by T3's headless browser) |
| shm.sizeLimit | string | `"1Gi"` | Size limit (counts against the memory limit) |
| startupProbe | object | `{"enabled":true,"failureThreshold":60,"httpGet":{"path":"/api/auth/session","port":"http"},"periodSeconds":5}` | Startup probe |
| t3.extraArgs | list | `[]` | Extra arguments appended to `t3 serve` |
| t3.logLevel | string | `"info"` | Log level (`trace`, `debug`, `info`, `warn`, `error`) |
| t3.pairTtl | string | `"10m"` | Default TTL of pairing links created with `t3-pair` |
| t3.port | int | `3773` | Container port of the T3 HTTP/WebSocket server |
| t3.publicUrl | string | `""` | Public URL clients use to reach the server (e.g. `https://t3.home.lan`). Used to print correct pairing links (`t3-pair`). Leave empty to derive it from `ingress`/`route` when enabled. |
| t3.telemetry | string | `nil` | Set `T3CODE_TELEMETRY_ENABLED`. `null` keeps the upstream default |
| t3.workspaceDir | string | `"/workspace"` | Working directory for provider sessions (inside the workspace volume) |
| terminationGracePeriodSeconds | int | `60` | Grace period. Restarting stops running agent turns. |
| tests.image | string | `"curlimages/curl:8.11.1"` | Image for `helm test` |
| tmpVolume | object | `{"enabled":true,"sizeLimit":"5Gi"}` | Mount an emptyDir on /tmp |
| tolerations | list | `[]` | Tolerations |
| updateStrategy | object | `{"type":"RollingUpdate"}` | StatefulSet update strategy |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
