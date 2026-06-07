# syntax=docker/dockerfile:1

FROM docker.io/library/node:22-bookworm-slim

ARG MCPPROXY_VERSION=0.33.5
ARG UV_VERSION=0.7.13
ARG TARGETARCH

ENV HOME=/home/mcpproxy \
    NODE_ENV=production \
    MCPPROXY_LISTEN=0.0.0.0:8080 \
    MCPPROXY_DATA_DIR=/var/lib/mcpproxy \
    MCPPROXY_CONFIG= \
    MCPPROXY_REQUIRE_MCP_AUTH=true \
    MCPPROXY_ENABLE_SOCKET=false \
    MCPPROXY_TELEMETRY=false \
    PIP_BREAK_SYSTEM_PACKAGES=1

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        procps \
        python3 \
        python3-pip \
        tini; \
    target_arch="${TARGETARCH}"; \
    if [ -z "$target_arch" ]; then \
        target_arch="$(dpkg --print-architecture)"; \
    fi; \
    case "$target_arch" in \
        amd64|arm64) mcpproxy_arch="$target_arch" ;; \
        x86_64) mcpproxy_arch="amd64" ;; \
        aarch64) mcpproxy_arch="arm64" ;; \
        *) echo "unsupported target architecture: ${target_arch}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/smart-mcp-proxy/mcpproxy-go/releases/download/v${MCPPROXY_VERSION}/mcpproxy-${MCPPROXY_VERSION}-linux-${mcpproxy_arch}.tar.gz" \
        | tar -xz -C /usr/local/bin mcpproxy; \
    chmod 0755 /usr/local/bin/mcpproxy; \
    python3 -m pip install --no-cache-dir "uv==${UV_VERSION}"; \
    groupadd --gid 10001 mcpproxy; \
    useradd --uid 10001 --gid 10001 --home-dir /home/mcpproxy --create-home --shell /usr/sbin/nologin mcpproxy; \
    mkdir -p /etc/mcpproxy /var/lib/mcpproxy /usr/local/lib/mcpproxy/wrappers; \
    chown -R mcpproxy:mcpproxy /home/mcpproxy /etc/mcpproxy /var/lib/mcpproxy; \
    mcpproxy --version; \
    node --version; \
    npm --version; \
    npx --version; \
    python3 --version; \
    uv --version; \
    uvx --version; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /root/.cache /root/.npm

COPY --chown=root:root docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY --chown=root:root wrappers/run-nextcloud-mcp /usr/local/lib/mcpproxy/wrappers/run-nextcloud-mcp

RUN chmod 0755 \
        /usr/local/bin/docker-entrypoint.sh \
        /usr/local/lib/mcpproxy/wrappers/run-nextcloud-mcp

USER mcpproxy
WORKDIR /var/lib/mcpproxy

EXPOSE 8080

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
