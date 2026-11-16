# CLAUDE.md

Packages the T3 Code server (github.com/pingdotgg/t3code, npm package `t3`) for Kubernetes.
Unofficial, not affiliated with Ping Labs. Read `README.md` and `docs/` before changing behaviour.

## Layout

- `image/` — container image (Debian + pinned, checksum-verified T3 release, non-root UID 1000).
  Helper scripts in `image/rootfs/usr/local/bin/`: `t3-entrypoint`, `t3-install-agents`, `t3-pair`.
- `charts/t3code/` — Helm chart (StatefulSet). Unit tests in `tests/`, extra lint values in `ci/`.
- `scripts/e2e.sh` — install/smoke/debug on a throwaway cluster (kind). `scripts/bump-t3.py` — version bump.
- `.github/workflows/` — `ci.yaml` (lint, unittest, kubeconform, e2e on kind), `release.yaml`
  (multi-arch image + chart to GHCR, signed), `upstream-watch.yaml` (polls npm, opens bump PRs).

## Design decisions (don't change without discussing)

- **The image tracks only the T3 version.** No agent CLIs baked in. Image tag = T3 version.
  A weekly rebuild refreshes base-image fixes under the same tag; the chart is not re-released for that.
- **Agents are installed by the `install-agents` initContainer** onto the home volume
  (`/home/t3/.local`, `NPM_CONFIG_PREFIX`). They self-update; `agents.updatePolicy` is `missing` | `always`.
- **Exactly 1 replica.** T3 is stateful (SQLite, WebSockets, terminals). StatefulSet with two PVCs:
  `home` (state, logins, agents) and `workspace` (repos). PVCs retained on uninstall.
- **`appVersion` = T3 version = image tag.** `Chart.yaml` `appVersion` is the single source of truth
  (Makefile, CI and release read it). Only stable `X.Y.Z` upstream releases are packaged.
  T3 patch → chart patch (auto-merged); T3 minor/major → chart minor (reviewed by hand).
- **Secure defaults**: non-root, Pod Security `restricted`, no SA token, ClusterIP only, optional
  NetworkPolicy blocking egress to private ranges. Never expose on the public internet (see `docs/security.md`).
  No Docker-in-Docker, no privileged pods, no `sudo` in the image.

## Commands

```bash
make lint            # helm lint --strict (default + ci/*.yaml), shellcheck, hadolint
make test            # helm unittest --strict
make docs            # regenerate charts/t3code/README.md (helm-docs) — CI fails if stale
make template        # render with default values
make image           # docker build for appVersion -> t3code-ci:ci (host arch)
make e2e             # image + kind cluster "t3" + scripts/e2e.sh install && smoke
scripts/e2e.sh debug # dump state on failure (NS=t3-e2e)
make clean           # delete the kind cluster
make bump V=X.Y.Z    # what upstream-watch does
```

Tools: docker, kind, helm (+ plugin helm-unittest), helm-docs, shellcheck, hadolint, python3.

## Chart conventions

- Every value in `values.yaml` has a `# --` comment above it (helm-docs renders it into the README).
  After editing values or comments, run `make docs` and commit the regenerated `README.md`.
- `values.schema.json` uses `additionalProperties: false`: **update it in the same change as
  `values.yaml`**, or installs with the new key fail.
- Any change under `charts/t3code/` needs a chart `version` bump in `Chart.yaml` (CI enforces it on PRs).
  Add/adjust `artifacthub.io/changes` accordingly.
- Add helm-unittest cases in `charts/t3code/tests/` for new template behaviour; if a value is
  exercised only in CI lint, put it in `ci/full-values.yaml`.

## Rules

- No secrets in the repo. Credentials come from `existingSecret` or interactive logins on the volume.
  Personal values files (e.g. `values-*.yaml` at the repo root) are gitignored.
- Pairing tokens must never appear in output or logs: redact `token=…` (see `scripts/e2e.sh debug`).
- Commits and PR titles follow Conventional Commits; small commits, one logical change each.
