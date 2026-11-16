# Security

## Threat model

T3 Code runs coding agents that **execute arbitrary commands** with the credentials you give them (provider logins, git tokens, API keys). Treat the pod as a remote shell that belongs to you.

| Asset | Where | Who can get it |
|---|---|---|
| Control of the agents (shell, files, git) | anyone holding a valid pairing link or session | whoever can reach the port **and** has a token |
| Provider logins (Claude, Codex, …) | `home` volume (`/home/t3`) | anyone with `exec` on the pod or access to the volume |
| Your code | `workspace` volume | same as above, plus the agents themselves |
| One-time owner pairing token | printed in the pod log at startup | anyone with `kubectl logs` in the namespace |

## What the chart does by default

- Runs as UID/GID 1000, `runAsNonRoot`, no privilege escalation, all capabilities dropped, `RuntimeDefault` seccomp. Passes the Pod Security **restricted** profile (tested in CI).
- Does **not** mount a ServiceAccount token: agents cannot call the Kubernetes API.
- Exposes only a `ClusterIP` service.
- No secrets in values: credentials come from an `existingSecret` you create, or from interactive logins stored on the volume.

## What you should do

1. **Never expose T3 on the public internet.** Use a VPN (WireGuard, Tailscale) or an internal-only ingress. Pairing codes are the only lock on the port.
2. **Enable the NetworkPolicy** (`networkPolicy.enabled=true`). It restricts who can reach the port and blocks egress to private ranges, so a misbehaving agent cannot reach other services in your cluster or LAN. Add exceptions with `networkPolicy.egress.extraTo` (internal git server, proxy). It needs a CNI that enforces policies (Calico, Cilium, kindnet ≥ kind 0.24, …; plain Flannel does not).
3. **Use a dedicated namespace** and restrict `pods/exec`, `pods/log` and Secrets in it with RBAC.
4. **Scope credentials**: fine-grained GitHub tokens or deploy keys per repository, not your personal all-access token.
5. **Pair per device** (`t3-pair --label <device>`), and revoke what you no longer use: `t3 auth session list` / `t3 auth session revoke <id>`, `t3 auth pairing list` / `revoke`.
6. **Stronger isolation**: set `runtimeClassName` to `gvisor` or `kata` if your cluster has them.
7. **TLS**: browsers treat plain `http://` on a non-localhost address as insecure; some features need a secure context. Prefer an ingress with a certificate (internal CA or ACME DNS-01), even on a VPN.

## Not supported on purpose

- Docker-in-Docker / privileged pods. If agents must build images, use a rootless BuildKit or kaniko service the agents talk to, and accept that this widens what the agent can do.
- `sudo` in the image.

## Reporting

Security issues in this chart or image: open a private advisory on GitHub (Security → Report a vulnerability). Issues in T3 Code itself go upstream to pingdotgg/t3code.
