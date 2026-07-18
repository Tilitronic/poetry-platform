FROM debian:13-slim@sha256:4e401d95de7083948053197a9c3913343cd06b706bf15eb6a0c3ccd26f436a0e AS builder-tools

ARG USER_UID=1000
ARG USER_GID=1000
ARG NODE_VERSION=24.18.0
ARG OPENCODE_VERSION=1.17.7
ARG PNPM_VERSION=10.33.0
ARG BUN_VERSION=1.3.14
ARG SNIP_VERSION=0.22.0  # standalone CLI binary — different artifact from @yelling_mimic/opencode-snip plugin
ARG DCP_VERSION=3.1.14
ARG OPENSPEC_VERSION=1.6.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install --no-install-recommends -y \
    ca-certificates \
    curl \
    wget \
    git \
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
RUN NODE_ARCH=$(case "${TARGETARCH:-$(uname -m)}" in x86_64|amd64) echo "x64" ;; aarch64|arm64) echo "arm64" ;; esac) && \
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

RUN node --version && \
    npm --version && \
    python3 --version && \
    python3 -m venv /tmp/test-venv && \
    rm -rf /tmp/test-venv && \
    opencode --version

RUN SNIP_ARCH=$(case "${TARGETARCH:-$(uname -m)}" in x86_64|amd64) echo "amd64" ;; aarch64|arm64) echo "arm64" ;; esac) && \
    curl -fsSL "https://github.com/edouard-claude/snip/releases/download/v${SNIP_VERSION}/snip_${SNIP_VERSION}_linux_${SNIP_ARCH}.tar.gz" -o /tmp/snip.tar.gz && \
    curl -fsSL "https://github.com/edouard-claude/snip/releases/download/v${SNIP_VERSION}/checksums.txt" -o /tmp/checksums.txt && \
    grep "snip_${SNIP_VERSION}_linux_${SNIP_ARCH}.tar.gz" /tmp/checksums.txt | sed "s|snip_${SNIP_VERSION}_linux_${SNIP_ARCH}.tar.gz|/tmp/snip.tar.gz|" | sha256sum -c - && \
    tar xzf /tmp/snip.tar.gz -C /usr/local/bin/ snip && \
    rm -f /tmp/snip.tar.gz /tmp/checksums.txt && \
    snip --version

# Install uv 0.11.29 — fast Python package installer
ARG UV_VERSION=0.11.29
RUN UV_ARCH=$(case "${TARGETARCH:-$(uname -m)}" in x86_64|amd64) echo "x86_64" ;; aarch64|arm64) echo "aarch64" ;; esac) && \
    curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${UV_ARCH}-unknown-linux-gnu.tar.gz" -o /tmp/uv.tar.gz && \
    curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/sha256.sum" -o /tmp/uv.sha256 && \
    grep "uv-${UV_ARCH}-unknown-linux-gnu.tar.gz" /tmp/uv.sha256 | sed "s|uv-${UV_ARCH}-unknown-linux-gnu.tar.gz|/tmp/uv.tar.gz|" | sha256sum -c - && \
    tar xzf /tmp/uv.tar.gz -C /usr/local/bin/ --strip-components=1 "uv-${UV_ARCH}-unknown-linux-gnu/uv" && \
    rm -f /tmp/uv.tar.gz /tmp/uv.sha256 && \
    uv --version

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
      curl wget snip uv dbus-send openspec

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

USER ${USER_UID}:${USER_GID}

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD opencode --version || exit 1

ENTRYPOINT ["/usr/bin/python3", "/usr/local/bin/bootstrap.py"]
