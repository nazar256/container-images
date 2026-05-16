ARG NODE_VERSION=22.14.0
ARG CHROMIUM_VERSION=version-09bef544
FROM docker.io/library/node:${NODE_VERSION}-bookworm-slim AS node

FROM docker.io/linuxserver/chromium:${CHROMIUM_VERSION}

ARG OPENCLAW_VERSION=2026.4.9

ENV HOME=/config \
    OPENCLAW_HOME=/config/.openclaw \
    OPENCLAW_CONFIG_PATH=/config/.openclaw/openclaw.json \
    OPENCLAW_GATEWAY_HOST=openclaw-gateway \
    OPENCLAW_GATEWAY_PORT=3443 \
    CDP_PORT=9222 \
    CHROMIUM_USER_DATA_DIR=/config/chromium/profile \
    CHROME_CLI="" \
    CDP_PROXY_ENABLED=true \
    CDP_PROXY_HOST=0.0.0.0 \
    CDP_PROXY_PORT=9223 \
    CDP_PROXY_BROWSER_WS_PATH=/devtools/browser \
    CDP_PROXY_EXPOSE_JSON_VERSION=true \
    CDP_PROXY_JSON_VERSION_PATH=/json/version \
    CDP_PROXY_CDP_WAIT_TIMEOUT=60 \
    CDP_PROXY_CDP_WAIT_INTERVAL=2 \
    CDP_PROXY_UPSTREAM_TIMEOUT_MS=2000 \
    CDP_PROXY_UPSTREAM_RETRY_ATTEMPTS=5 \
    CDP_PROXY_UPSTREAM_RETRY_DELAY_MS=250

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/include/node /usr/local/include/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules

COPY --chown=root:root root/usr/local/lib/openclaw-cdp-proxy /usr/local/lib/openclaw-cdp-proxy

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && ln -sf ../lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack \
    && npm install --global --omit=dev "openclaw@${OPENCLAW_VERSION}" \
    && npm install --omit=dev --prefix /usr/local/lib/openclaw-cdp-proxy \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=root:root root/custom-cont-init.d/40-openclaw-init /custom-cont-init.d/40-openclaw-init
COPY --chown=root:root root/custom-services/openclaw-node /custom-services.d/openclaw-node
COPY --chown=root:root root/custom-services/openclaw-cdp-proxy /custom-services.d/openclaw-cdp-proxy

RUN chmod 0755 /custom-cont-init.d/40-openclaw-init \
    /custom-services.d/openclaw-node \
    /custom-services.d/openclaw-cdp-proxy
