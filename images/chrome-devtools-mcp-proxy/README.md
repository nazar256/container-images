# chrome-devtools-mcp-proxy image

Container image for running one long-lived `chrome-devtools-mcp` stdio backend behind `punkpeye/mcp-proxy` as a Streamable HTTP MCP service.

## Why this image exists

This image exists to avoid running `chrome-devtools-mcp` directly as a MetaMCP `STDIO` server, which can leave too many retained `chrome-devtools-mcp` child processes behind and eventually cause OOM.

Expected topology:

```text
MetaMCP -> chrome-devtools-mcp-proxy /mcp -> chrome-devtools-mcp -> OpenClaw browser CDP proxy -> Chromium
```

The image configures `mcp-proxy` in stream-only mode without `--stateless`, so the exposed MCP transport is Streamable HTTP on `/mcp` while the backend stdio process stays long-lived.

Incoming `mcp-proxy` API-key authentication is required by default. Startup fails closed unless `MCP_PROXY_API_KEY` or `MCP_PROXY_API_KEY_FILE` is set, or you explicitly opt into local/debug unauthenticated mode with `MCP_PROXY_ALLOW_UNAUTHENTICATED=true`.

## Build locally

```bash
docker build \
  -t chrome-devtools-mcp-proxy:local \
  --build-arg MCP_PROXY_VERSION=6.5.1 \
  --build-arg CHROME_DEVTOOLS_MCP_VERSION=1.0.1 \
  -f images/chrome-devtools-mcp-proxy/Dockerfile \
  images/chrome-devtools-mcp-proxy
```

## Smoke check

```bash
docker run --rm --entrypoint sh chrome-devtools-mcp-proxy:local -ceu '
  command -v node >/dev/null &&
  command -v npm >/dev/null &&
  command -v mcp-proxy >/dev/null &&
  command -v chrome-devtools-mcp >/dev/null &&
  test -x /usr/local/bin/docker-entrypoint.sh
'

docker run --rm --entrypoint mcp-proxy chrome-devtools-mcp-proxy:local --help >/dev/null
docker run --rm --entrypoint chrome-devtools-mcp chrome-devtools-mcp-proxy:local --help >/dev/null

mkdir -p .tmp

if docker run --rm chrome-devtools-mcp-proxy:local >.tmp/chrome-devtools-mcp-proxy-missing-token.log 2>&1; then
  echo 'expected missing-token startup failure' >&2
  exit 1
fi
grep -q 'BROWSER_CDP_BEARER_TOKEN' .tmp/chrome-devtools-mcp-proxy-missing-token.log

if docker run --rm \
  -e BROWSER_CDP_BEARER_TOKEN=dummy-browser-cdp-token \
  chrome-devtools-mcp-proxy:local >.tmp/chrome-devtools-mcp-proxy-missing-api-key.log 2>&1; then
  echo 'expected missing-api-key startup failure' >&2
  exit 1
fi
grep -q 'MCP_PROXY_API_KEY' .tmp/chrome-devtools-mcp-proxy-missing-api-key.log
```

## Run locally

Use a private Docker network shared with MetaMCP and `openclaw-browser-node`.

```bash
docker run -d \
  --name chrome-devtools-mcp-proxy \
  --network internal-mcp \
  -e BROWSER_CDP_WS_ENDPOINT=ws://openclaw-browser-node:9223/devtools/browser \
  -e BROWSER_CDP_BEARER_TOKEN_FILE=/run/secrets/browser_cdp_token \
  -e MCP_PROXY_API_KEY_FILE=/run/secrets/metamcp_mcp_proxy_api_key \
  -v /run/secrets/browser_cdp_token:/run/secrets/browser_cdp_token:ro \
  -v /run/secrets/metamcp_mcp_proxy_api_key:/run/secrets/metamcp_mcp_proxy_api_key:ro \
  ghcr.io/nazar256/chrome-devtools-mcp-proxy:latest
```

The service listens on `0.0.0.0:8000` and exposes only the Streamable HTTP MCP endpoint at `/mcp`.

## Runtime environment variables

| Variable | Default | Notes |
| --- | --- | --- |
| `MCP_PROXY_HOST` | `0.0.0.0` | Listen host for `mcp-proxy`. |
| `MCP_PROXY_PORT` | `8000` | Listen port for `mcp-proxy`. |
| `MCP_PROXY_STREAM_ENDPOINT` | `/mcp` | Streamable HTTP endpoint path. Must start with `/`. |
| `MCP_PROXY_API_KEY` | unset | Required incoming API key for `mcp-proxy` unless `MCP_PROXY_ALLOW_UNAUTHENTICATED=true`. Sent by clients as `X-API-Key`. |
| `MCP_PROXY_API_KEY_FILE` | unset | Preferred Docker-secret file for `MCP_PROXY_API_KEY`. If both are set, file wins. |
| `MCP_PROXY_ALLOW_UNAUTHENTICATED` | unset | Local/debug-only escape hatch. Only the exact value `true` allows startup without an incoming API key, and the container logs a warning when used. |
| `MCP_PROXY_REQUEST_TIMEOUT_MS` | `300000` | `mcp-proxy --requestTimeout`. |
| `MCP_PROXY_CONNECTION_TIMEOUT_MS` | `60000` | `mcp-proxy --connectionTimeout`. |
| `BROWSER_CDP_WS_ENDPOINT` | `ws://openclaw-browser-node:9223/devtools/browser` | Required `chrome-devtools-mcp --wsEndpoint` target. |
| `BROWSER_CDP_BEARER_TOKEN` | unset | Browser CDP proxy bearer token fallback. |
| `BROWSER_CDP_BEARER_TOKEN_FILE` | unset | Preferred Docker-secret file for browser CDP token. If both are set, file wins. |
| `CHROME_DEVTOOLS_MCP_EXTRA_ARGS` | unset | Optional JSON array of extra `chrome-devtools-mcp` args, for example `["--headless=true"]`. Arguments that override browser connection or telemetry flags are rejected. |

The image always adds these `chrome-devtools-mcp` defaults:

- `--no-usage-statistics`
- `--no-performance-crux`
- `--wsEndpoint=${BROWSER_CDP_WS_ENDPOINT}`
- `--wsHeaders={"Authorization":"Bearer <token>"}`

The image does not use `--browser-url` in the default path.

## Secret-file examples

Browser CDP token via Docker secret file:

```bash
docker run -d \
  --name chrome-devtools-mcp-proxy \
  --network internal-mcp \
  -e BROWSER_CDP_BEARER_TOKEN_FILE=/run/secrets/browser_cdp_token \
  -e MCP_PROXY_API_KEY_FILE=/run/secrets/metamcp_mcp_proxy_api_key \
  -v /run/secrets/browser_cdp_token:/run/secrets/browser_cdp_token:ro \
  -v /run/secrets/metamcp_mcp_proxy_api_key:/run/secrets/metamcp_mcp_proxy_api_key:ro \
  ghcr.io/nazar256/chrome-devtools-mcp-proxy:latest
```

Required incoming API key via Docker secret file:

```bash
docker run -d \
  --name chrome-devtools-mcp-proxy \
  --network internal-mcp \
  -e BROWSER_CDP_BEARER_TOKEN_FILE=/run/secrets/browser_cdp_token \
  -e MCP_PROXY_API_KEY_FILE=/run/secrets/metamcp_mcp_proxy_api_key \
  -v /run/secrets/browser_cdp_token:/run/secrets/browser_cdp_token:ro \
  -v /run/secrets/metamcp_mcp_proxy_api_key:/run/secrets/metamcp_mcp_proxy_api_key:ro \
  ghcr.io/nazar256/chrome-devtools-mcp-proxy:latest
```

## MetaMCP upstream config shape

```yaml
type: STREAMABLE_HTTP
url: http://chrome-devtools-mcp-proxy:8000/mcp
headers:
  X-API-Key: <required-api-key>
```

Unauthenticated startup is disabled by default. For local debugging only, you may set `MCP_PROXY_ALLOW_UNAUTHENTICATED=true`, but production deployments should always send `X-API-Key`.

## Browser CDP config shape

```bash
BROWSER_CDP_WS_ENDPOINT=ws://openclaw-browser-node:9223/devtools/browser
BROWSER_CDP_BEARER_TOKEN_FILE=/run/secrets/browser_cdp_token
```

## Security notes

- Do not expose this service publicly.
- Do not add a public Traefik router for this service unless a separate auth model is intentionally added.
- Do not use raw Chromium CDP.
- Do not use unauthenticated `--browser-url`.
- Keep this service on private Docker networking with MetaMCP and the browser node.
- Do not rely on private Docker networking as the only auth boundary; keep incoming `mcp-proxy` API-key auth enabled.
- `chrome-devtools-mcp` only accepts `--wsHeaders` as a CLI argument, so the browser bearer token is visible in the backend process arguments inside the container. Restrict container access accordingly.

Local/debug-only unauthenticated startup example:

```bash
docker run -d \
  --name chrome-devtools-mcp-proxy \
  --network internal-mcp \
  -e MCP_PROXY_ALLOW_UNAUTHENTICATED=true \
  -e BROWSER_CDP_BEARER_TOKEN_FILE=/run/secrets/browser_cdp_token \
  -v /run/secrets/browser_cdp_token:/run/secrets/browser_cdp_token:ro \
  ghcr.io/nazar256/chrome-devtools-mcp-proxy:latest
```

This mode intentionally logs a warning and should not be used for shared or production networks.

## Operational notes

- Monitor process count.
- Monitor memory.
- Expected steady state is one `mcp-proxy` process and one `chrome-devtools-mcp` backend process.
- If process count grows with sessions, stop and investigate.

Recommended verification after repeated MetaMCP sessions:

```bash
docker exec chrome-devtools-mcp-proxy \
  ps -eo pid,ppid,rss,etimes,args | grep -E 'mcp-proxy|chrome-devtools-mcp' | grep -v grep
```

Expected result:

- one `mcp-proxy` process
- one `chrome-devtools-mcp` backend process
- process count does not grow after repeated MetaMCP sessions
- memory usage plateaus instead of growing with each session

## Pull from GHCR

```bash
docker pull ghcr.io/nazar256/chrome-devtools-mcp-proxy:latest
```

## Pull from Docker Hub

```bash
docker pull <dockerhub-username>/chrome-devtools-mcp-proxy:latest
```
