# openclaw-browser-node image

Chromium + OpenClaw node host image built on top of LinuxServer Chromium.

## Design choices

- Base image defaults to `docker.io/linuxserver/chromium` and is pinned by build arg `CHROMIUM_VERSION` (default: `version-09bef544`).
- Node.js is pinned by build arg `NODE_VERSION` (default: `22.14.0`) to satisfy current OpenClaw runtime requirements.
- OpenClaw CLI is installed from npm and pinned by build arg `OPENCLAW_VERSION` (default: `2026.4.9`).
- Chrome DevTools MCP is installed from npm and pinned by build arg `CHROME_DEVTOOLS_MCP_VERSION` (default: `0.23.0`).
- Node connectivity defaults to `OPENCLAW_GATEWAY_HOST=openclaw-gateway` and `OPENCLAW_GATEWAY_PORT=3443`.
- Chromium CDP is enabled for the interactive browser with loopback-only binding and the persistent `CHROMIUM_USER_DATA_DIR` profile.
- A supervised Streamable HTTP MCP endpoint starts in the same container and proxies to the local Chromium CDP endpoint.

## Build locally

```bash
podman build \
  -t openclaw-browser-node:local \
  --build-arg CHROMIUM_VERSION=version-09bef544 \
  --build-arg NODE_VERSION=22.14.0 \
  --build-arg OPENCLAW_VERSION=2026.4.9 \
  --build-arg CHROME_DEVTOOLS_MCP_VERSION=0.23.0 \
  -f images/openclaw-browser-node/Dockerfile \
  images/openclaw-browser-node
```

## Run locally

```bash
podman run -d \
  --name openclaw-browser-node \
  --shm-size=1g \
  -p 3001:3001 \
  -p 9223:9223 \
  -v openclaw-browser-node-config:/config \
  -e OPENCLAW_GATEWAY_HOST=openclaw-gateway \
  -e OPENCLAW_GATEWAY_PORT=3443 \
  -e OPENCLAW_GATEWAY_TOKEN=replace-me \
  openclaw-browser-node:local
```

The LinuxServer Chromium web UI is available on `https://localhost:3001`.

The default external DevTools MCP endpoint is `http://localhost:9223/mcp`.

Raw Chromium CDP stays private inside the container at `http://127.0.0.1:9222` by default and is not intended to be published externally.

## Runtime environment

- `OPENCLAW_GATEWAY_HOST` (default: `openclaw-gateway`)
- `OPENCLAW_GATEWAY_PORT` (default: `3443`)
- `OPENCLAW_GATEWAY_TOKEN` (required unless using `OPENCLAW_GATEWAY_TOKEN_FILE`)
- `OPENCLAW_GATEWAY_TOKEN_FILE` (optional secret file path)
- `CDP_PORT` (default: `9222`)
- `CHROMIUM_USER_DATA_DIR` (default: `/config/chromium/profile`)
- `CHROME_CLI` (optional override; when unset the container builds a default value that keeps CDP on `127.0.0.1` and reuses `CHROMIUM_USER_DATA_DIR`)
- `OPENCLAW_CONFIG_PATH` (default: `/config/.openclaw/openclaw.json`)
- `OPENCLAW_RUNTIME_USER` (default: `abc`, runtime user name used inside the container)
- `OPENCLAW_RUNTIME_GROUP` (default: `abc`, runtime group name used inside the container)
- `OPENCLAW_DEVTOOLS_MCP_ENABLED` (default: `true`)
- `OPENCLAW_DEVTOOLS_MCP_HOST` (default: `0.0.0.0`)
- `OPENCLAW_DEVTOOLS_MCP_PORT` (default: `9223`)
- `OPENCLAW_DEVTOOLS_MCP_PATH` (default: `/mcp`)
- `OPENCLAW_DEVTOOLS_MCP_MAX_SESSIONS` (default: `16`)
- `OPENCLAW_DEVTOOLS_MCP_SESSION_TIMEOUT_MS` (default: `300000`, set to `0` to disable inactivity cleanup)
- `OPENCLAW_DEVTOOLS_MCP_AUTH_BEARER_TOKEN` (default: empty / disabled)
- `OPENCLAW_DEVTOOLS_MCP_DISABLE_USAGE_STATISTICS` (default: `true`, maps to `chrome-devtools-mcp --no-usage-statistics`)
- `OPENCLAW_DEVTOOLS_MCP_DISABLE_PERFORMANCE_CRUX` (default: `true`, maps to `chrome-devtools-mcp --no-performance-crux`)
- `OPENCLAW_DEVTOOLS_MCP_DISABLE_UPDATE_CHECKS` (default: `true`, exports `CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS=1`)

## MCP endpoint

- Listen host: `OPENCLAW_DEVTOOLS_MCP_HOST` (`0.0.0.0` by default)
- Listen port: `OPENCLAW_DEVTOOLS_MCP_PORT` (`9223` by default)
- Path: `OPENCLAW_DEVTOOLS_MCP_PATH` (`/mcp` by default)
- Intended external integration point: the Streamable HTTP MCP endpoint above
- Raw CDP integration point: internal only at `http://127.0.0.1:9222` by default from inside the container, or `http://127.0.0.1:<CDP_PORT>` when overridden

## Pull from GHCR

```bash
docker pull ghcr.io/<owner>/openclaw-browser-node:latest
```

## Pull from Docker Hub

```bash
docker pull <dockerhub-username>/openclaw-browser-node:latest
```
