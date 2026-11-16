# Customizing

## Agents

Agent CLIs are npm packages installed into `/home/t3/.local` (on the home volume) by the `install-agents` initContainer:

```yaml
agents:
  packages:
    - "@anthropic-ai/claude-code"
    - "@openai/codex"
    - opencode-ai
  updatePolicy: missing   # agents update themselves; "always" reinstalls on every start
```

Pin versions with `"@openai/codex@0.162.1"` + `updatePolicy: always` if you want reproducibility over freshness. Agents that are not on npm can be installed from a shell in the pod into `~/.local/bin`: it is on `PATH` and persists.

## Language toolchains

The image ships git, gh, Node.js 22, Python 3, ripgrep, jq, make and the usual CLI tools, but no compilers or SDKs: every project needs different ones. Options:

1. **Install on the home volume** (no rebuild, survives restarts): user-level installers that write under `$HOME` work, e.g. `uv`, `rustup`, `nvm`, `sdkman`, Go tarballs in `~/.local`.
2. **Derived image** (reproducible, recommended for teams):

   ```dockerfile
   FROM ghcr.io/alessandroros/t3code:0.1.9
   USER root
   RUN apt-get update && apt-get install -y --no-install-recommends build-essential golang \
    && rm -rf /var/lib/apt/lists/*
   USER 1000:1000
   ```

   Then set `image.registry`/`image.repository`/`image.tag` to your image.

## Git

Mount a gitconfig and use a credential from a Secret:

```yaml
existingSecret: t3-agent-keys        # contains GH_TOKEN
extraVolumes:
  - name: gitconfig
    configMap: {name: t3-gitconfig}
extraVolumeMounts:
  - name: gitconfig
    mountPath: /home/t3/.gitconfig
    subPath: .gitconfig
```

`gh` picks up `GH_TOKEN`; run `gh auth setup-git` once in the pod to use it for `git push` over HTTPS.

## Extra T3 settings

Any `T3CODE_*` environment variable can be set through `extraEnv` (for example OpenTelemetry export with `T3CODE_OTLP_TRACES_URL`). Extra `t3 serve` flags go in `t3.extraArgs`.
