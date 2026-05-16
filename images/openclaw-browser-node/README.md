# openclaw-browser-node image

Chromium + OpenClaw node host image built on top of LinuxServer Chromium.

## Design choices

- Base image defaults to `docker.io/linuxserver/chromium` and is pinned by build arg `CHROMIUM_VERSION` (default: `version-09bef544`).
- Node.js is pinned by build arg `NODE_VERSION` (default: `22.14.0`) to satisfy current OpenClaw runtime requirements.
- OpenClaw CLI is installed from npm and pinned by build arg `OPENCLAW_VERSION` (default: `2026.4.9`).
- Node connectivity defaults to `OPENCLAW_GATEWAY_HOST=openclaw-gateway` and `OPENCLAW_GATEWAY_PORT=3443`.
- Chromium CDP is enabled for the interactive browser with `--remote-debugging-address=127.0.0.1`, `--remote-debugging-port=${CDP_PORT}`, and the persistent `CHROMIUM_USER_DATA_DIR` profile.
- Raw Chromium CDP stays loopback-only inside the container. Exposing raw CDP on `0.0.0.0` is forbidden and the init step fails closed if `CHROME_CLI` attempts it.
- A supervised authenticated CDP WebSocket proxy starts in the same container and forwards only authenticated discovery/WebSocket traffic to the local Chromium CDP endpoint.
- The current LinuxServer Chromium base image launches `/usr/bin/chromium` via `wrapped-chromium` (with `/usr/bin/chromium-browser` as the compatibility entrypoint), so this image injects CDP flags through `CHROME_CLI` instead of replacing the launcher.

## Build locally

```bash
podman build \
  -t openclaw-browser-node:local \
  --build-arg CHROMIUM_VERSION=version-09bef544 \
  --build-arg NODE_VERSION=22.14.0 \
  --build-arg OPENCLAW_VERSION=2026.4.9 \
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
  -e CDP_PROXY_HOST=0.0.0.0 \
  -e CDP_PROXY_BEARER_TOKEN_FILE=/run/secrets/browser_cdp_token \
  --secret browser_cdp_token,type=mount \
  openclaw-browser-node:local
```

The LinuxServer Chromium web UI is available on `https://localhost:3001`.

The authenticated CDP proxy is network-visible on `ws://localhost:9223/devtools/browser` by default when you publish port `9223`. Raw Chromium CDP remains private at `http://127.0.0.1:${CDP_PORT}` inside the container and is not intended to be published.

## Runtime environment

- `OPENCLAW_GATEWAY_HOST` (default: `openclaw-gateway`)
- `OPENCLAW_GATEWAY_PORT` (default: `3443`)
- `OPENCLAW_GATEWAY_TOKEN` (required unless using `OPENCLAW_GATEWAY_TOKEN_FILE`)
- `OPENCLAW_GATEWAY_TOKEN_FILE` (optional secret file path)
- `CDP_PORT` (default: `9222`, Chromium raw CDP port on loopback only)
- `CHROMIUM_USER_DATA_DIR` (default: `/config/chromium/profile`)
- `CHROME_CLI` (optional override; when unset the container builds a default value with `--remote-debugging-address=127.0.0.1`, `--remote-debugging-port=${CDP_PORT}`, and `--user-data-dir=${CHROMIUM_USER_DATA_DIR}`. Overrides must preserve those exact CDP/profile flags or startup fails closed)
- `OPENCLAW_CONFIG_PATH` (default: `/config/.openclaw/openclaw.json`)
- `OPENCLAW_RUNTIME_USER` (default: `abc`, runtime user name used inside the container)
- `OPENCLAW_RUNTIME_GROUP` (default: `abc`, runtime group name used inside the container)
- `CDP_PROXY_ENABLED` (default: `true`)
- `CDP_PROXY_HOST` (default: `0.0.0.0`)
- `CDP_PROXY_PORT` (default: `9223`)
- `CDP_PROXY_BROWSER_WS_PATH` (default: `/devtools/browser`)
- `CDP_PROXY_EXPOSE_JSON_VERSION` (default: `true`)
- `CDP_PROXY_JSON_VERSION_PATH` (default: `/json/version`)
- `CDP_PROXY_BEARER_TOKEN_FILE` (preferred secret-file path for proxy auth)
- `CDP_PROXY_BEARER_TOKEN` (optional env fallback when a file is not provided)
- `CDP_PROXY_PUBLIC_SCHEME` (optional explicit external scheme override for rewritten `webSocketDebuggerUrl`, e.g. `wss`)
- `CDP_PROXY_PUBLIC_HOST` (optional explicit external host override for rewritten `webSocketDebuggerUrl`)
- `CDP_PROXY_PUBLIC_PORT` (optional explicit external port override for rewritten `webSocketDebuggerUrl`)
- `CDP_PROXY_CDP_WAIT_TIMEOUT` (default: `60`, maximum number of seconds the service waits for Chromium CDP before exiting with an error)
- `CDP_PROXY_CDP_WAIT_INTERVAL` (default: `2`, retry interval in seconds while waiting for Chromium CDP)
- `CDP_PROXY_UPSTREAM_TIMEOUT_MS` (default: `2000`, timeout for proxy requests to Chromium)
- `CDP_PROXY_UPSTREAM_RETRY_ATTEMPTS` (default: `5`, retry count when Chromium is temporarily unavailable)
- `CDP_PROXY_UPSTREAM_RETRY_DELAY_MS` (default: `250`, delay between retry attempts)

## CDP endpoint model

- Stable browser WebSocket endpoint: `ws://<browser-service>:<CDP_PROXY_PORT>/devtools/browser`
- Auth: `Authorization: Bearer <token>` on every HTTP request and WebSocket upgrade
- Optional authenticated discovery endpoint: `http://<browser-service>:<CDP_PROXY_PORT>/json/version`
- The proxy rewrites `webSocketDebuggerUrl` to the stable authenticated proxy endpoint above instead of returning Chromium’s internal dynamic browser websocket URL.
- Raw CDP integration point: internal only at `http://127.0.0.1:<CDP_PORT>` from inside the container.

Clients that need Chrome DevTools MCP should run MCP outside this image and connect through the authenticated browser WebSocket proxy using a `--wsEndpoint` plus `--wsHeaders` style configuration, not an unauthenticated `--browser-url`.

## Security model

- Raw Chromium CDP binds only to `127.0.0.1:<CDP_PORT>` inside the browser container.
- Other containers must not use raw Chromium CDP directly.
- The only network-visible CDP-related endpoint is the authenticated proxy on `CDP_PROXY_HOST:CDP_PROXY_PORT`.
- The proxy requires bearer authentication on both HTTP and WebSocket traffic.
- Token file configuration is preferred for Docker secrets. Avoid putting long-lived tokens directly in environment variables when a file-based secret is available.
- Do not expose raw Chromium CDP on `0.0.0.0`.

## Example client shape

- WebSocket endpoint: `ws://<browser-service>:9223/devtools/browser`
- Header: `Authorization: Bearer <secret>`

## Pull from GHCR

```bash
docker pull ghcr.io/<owner>/openclaw-browser-node:latest
```

## Pull from Docker Hub

```bash
docker pull <dockerhub-username>/openclaw-browser-node:latest
```
