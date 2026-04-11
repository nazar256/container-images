ARG NODE_VERSION=22.14.0
FROM docker.io/library/node:${NODE_VERSION}-trixie-slim AS node

ARG CHROMIUM_VERSION=version-09bef544
FROM docker.io/linuxserver/chromium:${CHROMIUM_VERSION}

ARG NODE_VERSION=22.14.0
ARG OPENCLAW_VERSION=2026.4.9

ENV HOME=/config \
    OPENCLAW_HOME=/config/.openclaw \
    OPENCLAW_CONFIG_PATH=/config/.openclaw/openclaw.json \
    OPENCLAW_GATEWAY_HOST=openclaw-gateway \
    OPENCLAW_GATEWAY_PORT=3443 \
    CDP_PORT=9222 \
    CHROMIUM_USER_DATA_DIR=/config/chromium/profile \
    CHROME_CLI="--remote-debugging-address=127.0.0.1 --remote-debugging-port=9222 --user-data-dir=/config/chromium/profile"

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/bin/npm /usr/local/bin/npm
COPY --from=node /usr/local/bin/npx /usr/local/bin/npx
COPY --from=node /usr/local/bin/corepack /usr/local/bin/corepack
COPY --from=node /usr/local/include/node /usr/local/include/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && npm install --global --omit=dev "openclaw@${OPENCLAW_VERSION}" \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=root:root root/custom-cont-init.d/40-openclaw-init /custom-cont-init.d/40-openclaw-init
COPY --chown=root:root root/custom-services.d/openclaw-node/run /custom-services.d/openclaw-node/run

RUN chmod 0755 /custom-cont-init.d/40-openclaw-init /custom-services.d/openclaw-node/run
