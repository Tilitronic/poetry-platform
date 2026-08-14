FROM debian:13-slim@sha256:4e401d95de7083948053197a9c3913343cd06b706bf15eb6a0c3ccd26f436a0e AS builder-tools

ARG USER_UID=1000
ARG USER_GID=1000
ARG NODE_VERSION=24.18.0
ARG OPENCODE_VERSION=1.18.4
ARG PNPM_VERSION=10.33.0
ARG BUN_VERSION=1.3.14
ARG SNIP_VERSION=0.22.0  # standalone CLI binary — different artifact from @yelling_mimic/opencode-snip plugin
ARG DCP_VERSION=3.1.14
ARG OPENSPEC_VERSION=1.7.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install --no-install-recommends -y \
    ca-certificates \
    curl \
    wget \
    git \
    openssh-client \
    python3 \
    python3-pip \
    python3-venv \
    xvfb \
    xclip \
    wl-clipboard \
    ripgrep \
    jq \
    dbus \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 24.18.0 from official binaries (pinned, not from apt repo)
# TARGETARCH may not be set in Podman without --platform; fallback to uname -m
# Fail-fast on unsupported TARGETARCH: without a `*)` arm an unknown arch would
# leave $*_ARCH empty and build a malformed download URL that fails opaquely
# mid-RUN. The non-zero exit aborts the Docker build immediately with a clear
# message. Same arm text in all four *_ARCH blocks below (NODE/MISE/SNIP/UV).
RUN NODE_ARCH=$(case "${TARGETARCH:-$(uname -m)}" in x86_64|amd64) echo "x64" ;; aarch64|arm64) echo "arm64" ;; *) echo "ERROR: unsupported TARGETARCH='${TARGETARCH}'. Supported: amd64, arm64." >&2; exit 1 ;; esac) && \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz" -o /tmp/node.tar.gz && \
    tar xzf /tmp/node.tar.gz -C /usr/local/ --strip-components=1 && \
    rm -f /tmp/node.tar.gz && \
    node --version && npm --version

RUN echo "Installing OpenCode version: ${OPENCODE_VERSION}" && \
    curl -fsSL https://opencode.ai/install -o /tmp/install-opencode.sh && \
    echo "fc3c1b2123f49b6df545a7622e5127d21cd794b15134fc3b66e1ca49f7fb297e  /tmp/install-opencode.sh" | sha256sum -c - && \
    bash /tmp/install-opencode.sh --version "${OPENCODE_VERSION}" --no-modify-path && \
    rm -f /tmp/install-opencode.sh && \
    install -m 0755 /root/.opencode/bin/opencode /usr/local/bin/opencode

RUN npm install -g pnpm@${PNPM_VERSION} bun@${BUN_VERSION} @tarquinen/opencode-dcp@${DCP_VERSION} @fission-ai/openspec@${OPENSPEC_VERSION}

# Install mise v2026.8.0 — JS tool manager (replaces Volta; DIA-030 closure)
# SEC-DOCKER-001: SHA256-verified against the upstream SHASUMS256.txt manifest
# (v2026.8.0: x64 64183603854f319b78658305c545aacae935e0959a3a894b77a0f9416eab047b,
# arm64 6d888ba3d0b5d78f676771a84846885b7f685fb4d1533f2927079eb9b75633a8).
# Same grep|sed|sha256sum -c - shape as the snip/uv installs; extraction uses
# --strip-components=2 mise/bin/mise because the tarball nests the binary under
# a mise/ prefix dir. No mise shims are installed (design dual-path contract).
# MISE_VERSION carries NO leading "v" (repo convention — the URLs below add it).
ARG MISE_VERSION=2026.8.0
RUN MISE_ARCH=$(case "${TARGETARCH:-$(uname -m)}" in x86_64|amd64) echo "x64" ;; aarch64|arm64) echo "arm64" ;; *) echo "ERROR: unsupported TARGETARCH='${TARGETARCH}'. Supported: amd64, arm64." >&2; exit 1 ;; esac) && \
    curl -fsSL "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-${MISE_ARCH}.tar.gz" -o /tmp/mise.tar.gz && \
    curl -fsSL "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/SHASUMS256.txt" -o /tmp/mise.sha256 && \
    grep "mise-v${MISE_VERSION}-linux-${MISE_ARCH}.tar.gz" /tmp/mise.sha256 | sed "s|\./mise-v${MISE_VERSION}-linux-${MISE_ARCH}.tar.gz|/tmp/mise.tar.gz|" | sha256sum -c - && \
    tar xzf /tmp/mise.tar.gz -C /usr/local/bin/ --strip-components=2 mise/bin/mise && \
    rm -f /tmp/mise.tar.gz /tmp/mise.sha256 && \
    mise --version

RUN SNIP_ARCH=$(case "${TARGETARCH:-$(uname -m)}" in x86_64|amd64) echo "amd64" ;; aarch64|arm64) echo "arm64" ;; *) echo "ERROR: unsupported TARGETARCH='${TARGETARCH}'. Supported: amd64, arm64." >&2; exit 1 ;; esac) && \
    curl -fsSL "https://github.com/edouard-claude/snip/releases/download/v${SNIP_VERSION}/snip_${SNIP_VERSION}_linux_${SNIP_ARCH}.tar.gz" -o /tmp/snip.tar.gz && \
    curl -fsSL "https://github.com/edouard-claude/snip/releases/download/v${SNIP_VERSION}/checksums.txt" -o /tmp/checksums.txt && \
    grep "snip_${SNIP_VERSION}_linux_${SNIP_ARCH}.tar.gz" /tmp/checksums.txt | sed "s|snip_${SNIP_VERSION}_linux_${SNIP_ARCH}.tar.gz|/tmp/snip.tar.gz|" | sha256sum -c - && \
    tar xzf /tmp/snip.tar.gz -C /usr/local/bin/ snip && \
    rm -f /tmp/snip.tar.gz /tmp/checksums.txt && \
    snip --version

# Install uv 0.11.29 — fast Python package installer
ARG UV_VERSION=0.11.29
RUN UV_ARCH=$(case "${TARGETARCH:-$(uname -m)}" in x86_64|amd64) echo "x86_64" ;; aarch64|arm64) echo "aarch64" ;; *) echo "ERROR: unsupported TARGETARCH='${TARGETARCH}'. Supported: amd64, arm64." >&2; exit 1 ;; esac) && \
    curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${UV_ARCH}-unknown-linux-gnu.tar.gz" -o /tmp/uv.tar.gz && \
    curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/sha256.sum" -o /tmp/uv.sha256 && \
    grep "uv-${UV_ARCH}-unknown-linux-gnu.tar.gz" /tmp/uv.sha256 | sed "s|uv-${UV_ARCH}-unknown-linux-gnu.tar.gz|/tmp/uv.tar.gz|" | sha256sum -c - && \
    tar xzf /tmp/uv.tar.gz -C /usr/local/bin/ --strip-components=1 "uv-${UV_ARCH}-unknown-linux-gnu/uv" && \
    rm -f /tmp/uv.tar.gz /tmp/uv.sha256 && \
    uv --version

RUN node --version && \
    npm --version && \
    python3 --version && \
    uv venv /tmp/test-venv && \
    rm -rf /tmp/test-venv && \
    opencode --version

COPY scripts/collect-runtime-deps.sh /usr/local/bin/collect-runtime-deps.sh
RUN chmod 0755 /usr/local/bin/collect-runtime-deps.sh

FROM builder-tools AS collector

ARG USER_UID=1000
ARG USER_GID=1000

RUN mkdir -p /opt/runtime-rootfs && \
    /usr/local/bin/collect-runtime-deps.sh /opt/runtime-rootfs \
      opencode node npm npx pnpm bun python3 pip3 Xvfb xclip wl-copy wl-paste git \
      mkdir find grep rg jq cat head tail sed awk tr \
      ls cp mv rm chmod wc sort cut env uname date dirname basename \
      curl wget snip uv mise dbus-send openspec ssh

RUN cd /opt/runtime-rootfs && \
    for dir in bin sbin lib lib64; do \
      if [ -d "${dir}" ] && [ ! -L "${dir}" ]; then \
        mkdir -p "usr/${dir}"; \
        if [ -n "$(ls -A "${dir}" 2>/dev/null)" ]; then \
          cp -a "${dir}"/. "usr/${dir}"/; \
        fi; \
        rm -rf "${dir}"; \
        ln -s "usr/${dir}" "${dir}"; \
      fi; \
    done

# Plugins loaded dynamically via npm (see config/opencode.json plugins array)

RUN mkdir -p /opt/runtime-rootfs/app/.local/share /opt/runtime-rootfs/app/.config/opencode /opt/runtime-rootfs/app/.cache && \
    chown -R ${USER_UID}:${USER_GID} /opt/runtime-rootfs/app && \
    printf 'opencode:x:%s:%s:OpenCode User:/app:/usr/bin/python3\n' "${USER_UID}" "${USER_GID}" >> /opt/runtime-rootfs/etc/passwd && \
    printf 'opencode:x:%s:\n' "${USER_GID}" >> /opt/runtime-rootfs/etc/group

FROM debian:13-slim@sha256:4e401d95de7083948053197a9c3913343cd06b706bf15eb6a0c3ccd26f436a0e AS final

ARG USER_UID=1000
ARG USER_GID=1000

# Install Playwright chromium system dependencies + base runtime
RUN apt-get update && apt-get install --no-install-recommends -y \
    bash \
    libgtk-3-0 \
    libegl1 \
    libnotify4 \
    libgdk-pixbuf-2.0-0 \
    libxcomposite1 \
    libatk1.0-0t64 \
    libatk-bridge2.0-0t64 \
    libepoxy0 \
    libharfbuzz-icu0 \
    libxt6 \
    libxaw7 \
    fonts-noto-color-emoji \
    libfontconfig1 \
    libfreetype6 \
    xfonts-cyrillic \
    xfonts-scalable \
    fonts-liberation \
    fonts-ipafont-gothic \
    fonts-wqy-zenhei \
    fonts-freefont-ttf \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV DISPLAY=:99.0
ENV HOME=/app
ENV XDG_CONFIG_HOME=/app/.config
ENV OPENCODE_CONFIG_DIR=/app/.config/opencode
ENV XDG_DATA_HOME=/app/.local/share
ENV PATH=/usr/local/bin:/usr/bin
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
# Container-only: safe to break system packages, no external Python env to protect
ENV PIP_BREAK_SYSTEM_PACKAGES=1

COPY --from=collector /opt/runtime-rootfs/ /
COPY --chmod=0755 bootstrap.py /usr/local/bin/bootstrap.py

# Install Playwright (chromium only) + crawl4ai via uv (10-50x faster than pip)
RUN uv pip install --system --break-system-packages playwright crawl4ai && \
    python3 -m playwright install chromium && \
    rm -rf /root/.cache/uv

# Docker CLI client + compose plugin — client ONLY, no docker-ce daemon, no
# docker group: the client talks to the host container socket over the
# /var/run/docker.sock bind mount added by bin/opencode-docker (pre-commit
# hook's `docker compose ...` delegation, DIA-121). Version-pinned per the
# F3/TODO convention. Static-bundle install replaces the apt-repo install
# (DIA-121 follow-up): apt-get update to download.docker.com fails TLS cert
# verification in the host network while curl to the same domain succeeds,
# so the docker-ce-cli debs are unreachable; the static bundles and GitHub
# release assets are not. Official static bundles preferred over Debian's
# docker.io: Debian trixie ships 26.1.5 and bundles the daemon; static
# bundles are client-only by extraction (only docker/docker, no
# dockerd/containerd/runc/ctr — keeps the image lean).
# SHA256 pinning: the static bundle dir ships NO sha256sum file (verified
# 2026-08-12: .../stable/x86_64/sha256sum 404s and the index lists only
# tgz files), so the tgz pin below is the hash of the HTTPS download,
# hardcoded per the project pin convention (same shape as the opencode
# installer pin above). Compose IS verified against the release's own
# checksums.txt. ~113MB installed (docker CLI 41MB static + compose 72MB
# Go static) vs ~90MB for the apt pair — slightly larger, the price of
# bypassing the broken apt TLS path.
# ponytail: touch pre-creates the bind target — podman cannot create a
# mountpoint on a --read-only rootfs at start; the placeholder file is
# replaced by the socket bind mount at run time. chown'd to the runtime
# user (USER_UID/USER_GID, same as the USER switch below) so the
# placeholder is owned by whoever runs the docker client if the mount is
# absent (reviewer finding [Minor], DIA-121).
ARG DOCKER_CLI_VERSION=29.7.2
ARG DOCKER_COMPOSE_VERSION=v2.39.1
RUN curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_CLI_VERSION}.tgz" -o /tmp/docker.tgz && \
    echo "803d433f226db4776e1768fd319fc6c6e4935a456acf84fcc0080818b854bc8f  /tmp/docker.tgz" | sha256sum -c - && \
    tar -xzf /tmp/docker.tgz -C /usr/local/bin --strip-components=1 docker/docker && \
    chmod 0755 /usr/local/bin/docker && \
    rm -f /tmp/docker.tgz && \
    curl -fsSL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /tmp/docker-compose && \
    curl -fsSL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/checksums.txt" -o /tmp/compose-checksums.txt && \
    grep "docker-compose-linux-x86_64$" /tmp/compose-checksums.txt | sed "s|docker-compose-linux-x86_64$|/tmp/docker-compose|" | sha256sum -c - && \
    mkdir -p /usr/local/lib/docker/cli-plugins && \
    install -m 0755 /tmp/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose && \
    rm -f /tmp/docker-compose /tmp/compose-checksums.txt && \
    docker --version && docker compose version && \
    touch /var/run/docker.sock && \
    chown ${USER_UID}:${USER_GID} /var/run/docker.sock

USER ${USER_UID}:${USER_GID}

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD opencode --version || exit 1

ENTRYPOINT ["/usr/bin/python3", "/usr/local/bin/bootstrap.py"]
