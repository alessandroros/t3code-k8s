# syntax=docker/dockerfile:1.7
#
# Unofficial container image for the T3 Code headless server.
# T3 Code: https://github.com/pingdotgg/t3code (MIT) by Ping Labs.
#
# The T3 version is pinned by build arg and verified against the release's
# SHA256SUMS. CI passes T3_VERSION from charts/t3code/Chart.yaml (appVersion),
# which is the single source of truth.

ARG NODE_VERSION=22
ARG DEBIAN_SUITE=bookworm

############################
# Fetch + verify T3 release
############################
FROM debian:${DEBIAN_SUITE}-slim AS fetch
ARG T3_VERSION
ARG TARGETARCH
ARG T3_RELEASE_BASE_URL=https://github.com/pingdotgg/t3code/releases/download
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /fetch
RUN set -eux; \
    test -n "${T3_VERSION}" || { echo "T3_VERSION build arg is required" >&2; exit 1; }; \
    case "${TARGETARCH}" in \
      amd64) arch=x64 ;; \
      arm64) arch=arm64 ;; \
      *) echo "unsupported arch ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    archive="t3-${T3_VERSION}-linux-${arch}.tar.gz"; \
    curl -fsSL -o SHA256SUMS "${T3_RELEASE_BASE_URL}/v${T3_VERSION}/SHA256SUMS"; \
    curl -fsSL -o "${archive}" "${T3_RELEASE_BASE_URL}/v${T3_VERSION}/${archive}"; \
    awk -v f="${archive}" '{ n=$2; sub(/^\*/, "", n); if (n == f) print $1 "  " n }' SHA256SUMS > check.txt; \
    test -s check.txt || { echo "${archive} not listed in SHA256SUMS" >&2; exit 1; }; \
    sha256sum -c check.txt; \
    mkdir -p /opt/t3; \
    # Same layout as the official npm launcher: strip the top-level directory.
    tar -xzf "${archive}" -C /opt/t3 --strip-components=1; \
    test -x /opt/t3/t3; \
    /opt/t3/t3 --version

############################
# Runtime
############################
FROM node:${NODE_VERSION}-${DEBIAN_SUITE}-slim AS runtime
ARG T3_VERSION
ARG TARGETARCH

LABEL org.opencontainers.image.title="t3code" \
      org.opencontainers.image.description="Unofficial image of the T3 Code headless server, for Kubernetes" \
      org.opencontainers.image.source="https://github.com/alessandroros/t3code-k8s" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${T3_VERSION}" \
      io.t3code.upstream="https://github.com/pingdotgg/t3code"

# Tools coding agents commonly expect. Language toolchains are NOT included:
# install them on the home volume or build a derived image (see docs/customizing.md).
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash ca-certificates curl git git-lfs gnupg jq less locales make \
      openssh-client procps python3 ripgrep tini tzdata unzip xz-utils zip; \
    # GitHub CLI from GitHub's apt repository
    install -d -m 0755 /etc/apt/keyrings; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli.gpg; \
    chmod 0644 /etc/apt/keyrings/githubcli.gpg; \
    echo "deb [arch=${TARGETARCH} signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends gh; \
    sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen; \
    rm -rf /var/lib/apt/lists/*

# Replace the base image's "node" user (UID 1000) with "t3" (UID/GID 1000).
RUN set -eux; \
    userdel -r node; \
    groupadd --gid 1000 t3; \
    useradd --uid 1000 --gid 1000 --create-home --home-dir /home/t3 --shell /bin/bash t3; \
    mkdir -p /workspace; chown 1000:1000 /workspace

COPY --from=fetch /opt/t3 /opt/t3
RUN ln -s /opt/t3/t3 /usr/local/bin/t3
COPY --chmod=0755 rootfs/usr/local/bin/ /usr/local/bin/

ENV HOME=/home/t3 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    T3CODE_HOME=/home/t3/.t3 \
    T3CODE_PORT=3773 \
    T3_WORKSPACE=/workspace \
    # Agents installed with npm land on the home volume (persistent, user-owned).
    NPM_CONFIG_PREFIX=/home/t3/.local \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    PATH=/home/t3/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

USER 1000:1000
WORKDIR /workspace
EXPOSE 3773
VOLUME ["/home/t3", "/workspace"]

ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/bin/t3-entrypoint"]
