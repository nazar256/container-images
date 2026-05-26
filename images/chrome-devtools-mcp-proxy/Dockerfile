# syntax=docker/dockerfile:1

FROM docker.io/library/node:22-bookworm-slim

ARG MCP_PROXY_VERSION=6.5.1
ARG CHROME_DEVTOOLS_MCP_VERSION=1.0.1

ENV HOME=/home/node \
    NODE_ENV=production \
    MCP_PROXY_HOST=0.0.0.0 \
    MCP_PROXY_PORT=8000 \
    MCP_PROXY_STREAM_ENDPOINT=/mcp \
    MCP_PROXY_REQUEST_TIMEOUT_MS=300000 \
    MCP_PROXY_CONNECTION_TIMEOUT_MS=60000 \
    BROWSER_CDP_WS_ENDPOINT=ws://openclaw-browser-node:9223/devtools/browser \
    CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS=1 \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1

WORKDIR /home/node

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl procps tini \
    && npm install -g --omit=dev --no-audit --no-fund \
        "mcp-proxy@${MCP_PROXY_VERSION}" \
        "chrome-devtools-mcp@${CHROME_DEVTOOLS_MCP_VERSION}" \
    && mcp-proxy --help >/dev/null \
    && chrome-devtools-mcp --help >/dev/null \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /root/.npm

COPY --chown=node:node entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

USER node

EXPOSE 8000

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
