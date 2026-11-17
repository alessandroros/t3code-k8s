# Upgrading and release process

## For users

```bash
helm upgrade t3 oci://ghcr.io/alessandroros/charts/t3code -n t3code --reuse-values
```

- **Restarts stop running agent turns.** Upgrade when agents are idle.
- **Client compatibility**: T3 rejects pairing between incompatible protocol versions. Keep the desktop/mobile apps updated together with the server.
- **Pinning**: `--version <chart>` pins the chart (and with it the T3 version). `image.digest` pins the exact image build.
- **Rollback**: `helm rollback t3 <revision>`. T3 runs database migrations on start; rolling back across a migration is not guaranteed to work. Back up first (below).

### Backups

Everything lives in two PVCs: `home-t3-t3code-0` (state, logins) and `workspace-t3-t3code-0` (repositories). Snapshot them with your CSI driver or Velero. A consistent copy of `home` needs the pod stopped or a crash-consistent snapshot (SQLite WAL).

PVCs are kept on `helm uninstall` (`persistentVolumeClaimRetentionPolicy: Retain`). Delete them by hand when you really want the data gone.

## For maintainers: how upstream tracking works

```
npm `t3@latest` ──(every 4h)──> upstream-watch.yaml
     │  new stable X.Y.Z and release assets (linux x64/arm64 + SHA256SUMS) exist?
     ▼
scripts/bump-t3.py: appVersion=X.Y.Z, chart patch (or minor) bump, Artifact Hub annotations
     ▼
PR "feat: update T3 Code to X.Y.Z" ──> ci.yaml: lint, unit tests, kubeconform, image build,
     │                                        e2e on kind (restricted PSS, NetworkPolicy, restart)
     ▼ auto-merge (patch only)
main ──> release.yaml: multi-arch image (signed, SBOM) + chart to GHCR OCI + GitHub release
```

The image tag is the T3 version. A weekly rebuild refreshes base-image security fixes under the same tag (new digest); the chart is not re-released for that.

Dependabot (weekly) updates the workflow actions and the Dockerfile base images. `dependabot-automerge.yaml` enables auto-merge on its patch and minor PRs, so they merge once CI passes; major updates are left for review.

### One-time repository setup

1. **Token for the bot**: create a fine-grained PAT (or a GitHub App) with *Contents* and *Pull requests* read/write on this repo, and save it as the `BOT_TOKEN` secret. PRs opened with the default `GITHUB_TOKEN` do not trigger CI.
2. **Branch protection on `main`**: require the `ci` checks (`chart lint…`, `image lint`, `e2e…`) and allow auto-merge in the repo settings.
3. **GHCR visibility**: after the first release, make the `t3code` image and `charts/t3code` packages public (Package settings → Change visibility).
4. **Artifact Hub**: add the repository as kind *Helm charts*, URL `oci://ghcr.io/alessandroros/charts/t3code`, then fill `repositoryID` in `artifacthub-repo.yml`.

### Manual bump

```bash
make bump V=0.1.10   # edits Chart.yaml + regenerates README
git commit -am "feat: update T3 Code to 0.1.10" && git push
```

Or run the `upstream-watch` workflow by hand with the `version` input.
