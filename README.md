# t3code-k8s

Run the [T3 Code](https://t3.codes) server on Kubernetes: a Helm chart plus a container image that track upstream releases automatically.

> **Unofficial.** T3 Code is made by [Ping Labs](https://github.com/pingdotgg/t3code). This project only packages it for Kubernetes and is not affiliated with or endorsed by them.

T3 Code is a control plane for coding agents (Claude Code, Codex, OpenCode, …). Its server owns your projects, threads, git state, terminals and agent logins; the desktop, mobile and web apps are clients. Running the server on your cluster means your context lives in one place and every device connects to it.

```bash
helm install t3 oci://ghcr.io/alessandroros/charts/t3code -n t3code --create-namespace
kubectl -n t3code exec -it t3-t3code-0 -c t3code -- t3-pair --label my-laptop
```

Then sign in the agents once (`claude auth login`, `codex login` via `kubectl exec`) and pair your devices.

## Contents

| Path | What |
|---|---|
| [`charts/t3code`](charts/t3code) | Helm chart ([values reference](charts/t3code/README.md)) |
| [`image/`](image) | `ghcr.io/alessandroros/t3code` image: Debian + the pinned, checksum-verified T3 release, non-root |
| [`docs/access.md`](docs/access.md) | Reaching the server: port-forward, VPN/WireGuard, ingress, Gateway API, Tailscale |
| [`docs/security.md`](docs/security.md) | Threat model and hardening — read before exposing anything |
| [`docs/upgrading.md`](docs/upgrading.md) | How releases track upstream, upgrades, backups |
| [`docs/customizing.md`](docs/customizing.md) | Toolchains, derived images, agents |

## Design in short

- **One replica, persistent volumes.** The T3 server is stateful (SQLite, WebSockets, terminals). `home` keeps state and logins, `workspace` keeps repositories.
- **The image only tracks T3.** Agent CLIs are installed by an initContainer onto the home volume and update themselves, so the image doesn't need a rebuild every time an agent ships.
- **Secure defaults.** Non-root, Pod Security `restricted`, no ServiceAccount token, ClusterIP only. Optional NetworkPolicy keeps agents off your cluster network.
- **Automatic upstream tracking.** A scheduled workflow watches the `t3` npm package; a new stable release opens a PR that is tested end-to-end on kind and released as image + chart.

## Versioning

- Chart `appVersion` = T3 Code version = image tag.
- T3 patch release → chart patch release (auto-merged after CI). T3 minor/major → chart minor release (reviewed by hand).
- Only stable T3 releases are packaged. Nightlies are not.

## Development

```bash
make lint test      # helm lint, shellcheck, hadolint, helm-unittest
make docs           # regenerate the chart README (helm-docs)
make e2e            # build image, kind cluster, install, smoke test
make bump V=0.1.10  # what upstream-watch does
```

## License

MIT for this repository. T3 Code is MIT licensed by its authors.
