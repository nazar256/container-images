ARG BASE_IMAGE=docker.io/linuxserver/chromium:latest
FROM ${BASE_IMAGE}

ARG OPENCLAW_VERSION=2026.3.2

ENV HOME=/config \
    OPENCLAW_HOME=/config/.openclaw \
    OPENCLAW_CONFIG_PATH=/config/.openclaw/openclaw.json \
    OPENCLAW_GATEWAY_HOST=openclaw-gateway \
    OPENCLAW_GATEWAY_PORT=3443 \
    CDP_PORT=9222 \
    CHROMIUM_USER_DATA_DIR=/config/chromium/profile \
    CHROME_CLI="--remote-debugging-address=127.0.0.1 --remote-debugging-port=9222 --user-data-dir=/config/chromium/profile"

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl nodejs npm \
    && npm config set strict-ssl false \
    && npm install --global --omit=dev "openclaw@${OPENCLAW_VERSION}" \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=root:root root/custom-cont-init.d/40-openclaw-init /custom-cont-init.d/40-openclaw-init
COPY --chown=root:root root/custom-services.d/openclaw-node/run /custom-services.d/openclaw-node/run

RUN chmod 0755 /custom-cont-init.d/40-openclaw-init /custom-services.d/openclaw-node/run
