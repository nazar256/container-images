# openclaw-browser-node image

Chromium + OpenClaw node host image built on top of LinuxServer Chromium.

## Design choices

- Base image is `docker.io/linuxserver/chromium` with the version pinned by build arg `CHROMIUM_VERSION` (default: `version-09bef544`).
- OpenClaw CLI is installed from npm and pinned by build arg `OPENCLAW_VERSION` (default: `2026.3.2`).
- Node connectivity defaults to `OPENCLAW_GATEWAY_HOST=openclaw-gateway` and `OPENCLAW_GATEWAY_PORT=3443`.
- CDP is enabled for the interactive Chromium instance using `CHROME_CLI` with loopback binding and a persistent non-default user data dir.

## Build locally

```bash
podman build \
  -t openclaw-browser-node:local \
  --build-arg CHROMIUM_VERSION=version-09bef544 \
  --build-arg OPENCLAW_VERSION=2026.3.2 \
  -f images/openclaw-browser-node/Dockerfile \
  images/openclaw-browser-node
```

## Run locally

```bash
podman run -d \
  --name openclaw-browser-node \
  --shm-size=1g \
  -p 3001:3001 \
  -v openclaw-browser-node-config:/config \
  -e OPENCLAW_GATEWAY_HOST=openclaw-gateway \
  -e OPENCLAW_GATEWAY_PORT=3443 \
  -e OPENCLAW_GATEWAY_TOKEN=replace-me \
  openclaw-browser-node:local
```

The LinuxServer Chromium web UI is available on `https://localhost:3001`.

## Runtime environment

- `OPENCLAW_GATEWAY_HOST` (default: `openclaw-gateway`)
- `OPENCLAW_GATEWAY_PORT` (default: `3443`)
- `OPENCLAW_GATEWAY_TOKEN` (required unless using `OPENCLAW_GATEWAY_TOKEN_FILE`)
- `OPENCLAW_GATEWAY_TOKEN_FILE` (optional secret file path)
- `CDP_PORT` (default: `9222`)
- `CHROMIUM_USER_DATA_DIR` (default: `/config/chromium/profile`)
- `CHROME_CLI` (default includes loopback CDP and persistent user data dir)
- `OPENCLAW_CONFIG_PATH` (default: `/config/.openclaw/openclaw.json`)

## Pull from GHCR

```bash
docker pull ghcr.io/<owner>/openclaw-browser-node:latest
```

## Pull from Docker Hub

```bash
docker pull <dockerhub-username>/openclaw-browser-node:latest
```
