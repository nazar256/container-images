#!/usr/bin/env bash
set -euo pipefail

warn() {
  printf 'WARNING: %s\n' "$1" >&2
}

die() {
  printf '%s\n' "$1" >&2
  exit 1
}

load_secret_prefer_file() {
  local var_name="$1"
  local file_var_name="${var_name}_FILE"
  local file_path="${!file_var_name:-}"

  if [[ -n "$file_path" ]]; then
    if [[ ! -f "$file_path" ]]; then
      die "Secret file not found: $file_path"
    fi

    tr -d '\r\n' < "$file_path"
    return 0
  fi

  printf '%s' "${!var_name:-}"
}

parse_extra_args() {
  node <<'EOF'
const raw = process.env.CHROME_DEVTOOLS_MCP_EXTRA_ARGS;
const separator = "\u001e";

if (!raw) {
  process.exit(0);
}

let parsed;

try {
  parsed = JSON.parse(raw);
} catch (error) {
  console.error("CHROME_DEVTOOLS_MCP_EXTRA_ARGS must be a JSON array of strings.");
  process.exit(1);
}

if (!Array.isArray(parsed) || parsed.some((item) => typeof item !== "string")) {
  console.error("CHROME_DEVTOOLS_MCP_EXTRA_ARGS must be a JSON array of strings.");
  process.exit(1);
}

const forbiddenPrefixes = [
  "--autoConnect",
  "--auto-connect",
  "--browserUrl",
  "--browser-url",
  "--performanceCrux",
  "--performance-crux",
  "--usageStatistics",
  "--usage-statistics",
  "--wsEndpoint",
  "--ws-endpoint",
  "--wsHeaders",
  "--ws-headers",
  "-u",
  "-w",
];

for (const arg of parsed) {
  if (forbiddenPrefixes.some((prefix) => arg === prefix || arg.startsWith(`${prefix}=`))) {
    console.error(`CHROME_DEVTOOLS_MCP_EXTRA_ARGS may not override required browser connection or telemetry flags: ${arg}`);
    process.exit(1);
  }
}

process.stdout.write(parsed.join(separator));
EOF
}

main() {
  local mcp_proxy_host="${MCP_PROXY_HOST:-0.0.0.0}"
  local mcp_proxy_port="${MCP_PROXY_PORT:-8000}"
  local mcp_proxy_stream_endpoint="${MCP_PROXY_STREAM_ENDPOINT:-/mcp}"
  local mcp_proxy_request_timeout_ms="${MCP_PROXY_REQUEST_TIMEOUT_MS:-300000}"
  local mcp_proxy_connection_timeout_ms="${MCP_PROXY_CONNECTION_TIMEOUT_MS:-60000}"
  local browser_cdp_ws_endpoint="${BROWSER_CDP_WS_ENDPOINT:-ws://openclaw-browser-node:9223/devtools/browser}"
  local browser_cdp_bearer_token
  local mcp_proxy_api_key
  local mcp_proxy_allow_unauthenticated="${MCP_PROXY_ALLOW_UNAUTHENTICATED:-}"
  local serialized_extra_args
  local ws_headers_json
  local -a proxy_args
  local -a chrome_devtools_args
  local -a extra_args=()

  if [[ "$mcp_proxy_stream_endpoint" != /* ]]; then
    die "MCP_PROXY_STREAM_ENDPOINT must start with /. Received: $mcp_proxy_stream_endpoint"
  fi

  browser_cdp_bearer_token="$(load_secret_prefer_file BROWSER_CDP_BEARER_TOKEN)"

  if [[ -z "$browser_cdp_bearer_token" ]]; then
    die 'BROWSER_CDP_BEARER_TOKEN or BROWSER_CDP_BEARER_TOKEN_FILE is required.'
  fi

  ws_headers_json="$({ BROWSER_CDP_BEARER_TOKEN_VALUE="$browser_cdp_bearer_token" node <<'EOF'
const token = process.env.BROWSER_CDP_BEARER_TOKEN_VALUE ?? "";
process.stdout.write(JSON.stringify({ Authorization: `Bearer ${token}` }));
EOF
  })"

  unset BROWSER_CDP_BEARER_TOKEN BROWSER_CDP_BEARER_TOKEN_FILE
  unset browser_cdp_bearer_token

  mcp_proxy_api_key="$(load_secret_prefer_file MCP_PROXY_API_KEY)"
  if [[ -n "$mcp_proxy_api_key" ]]; then
    export MCP_PROXY_API_KEY="$mcp_proxy_api_key"
  elif [[ "$mcp_proxy_allow_unauthenticated" == 'true' ]]; then
    unset MCP_PROXY_API_KEY || true
    warn 'Starting without MCP_PROXY_API_KEY because MCP_PROXY_ALLOW_UNAUTHENTICATED=true. This is for local/debug use only.'
  else
    unset MCP_PROXY_API_KEY || true
    die 'MCP_PROXY_API_KEY or MCP_PROXY_API_KEY_FILE is required unless MCP_PROXY_ALLOW_UNAUTHENTICATED=true.'
  fi
  unset MCP_PROXY_API_KEY_FILE

  if [[ -n "${CHROME_DEVTOOLS_MCP_EXTRA_ARGS:-}" ]]; then
    if ! serialized_extra_args="$(parse_extra_args)"; then
      exit 1
    fi

    if [[ -n "$serialized_extra_args" ]]; then
      IFS=$'\036' read -r -a extra_args <<< "$serialized_extra_args"
    fi
  fi

  proxy_args=(
    --host "$mcp_proxy_host"
    --port "$mcp_proxy_port"
    --server stream
    --streamEndpoint "$mcp_proxy_stream_endpoint"
    --requestTimeout "$mcp_proxy_request_timeout_ms"
    --connectionTimeout "$mcp_proxy_connection_timeout_ms"
  )

  chrome_devtools_args=(
    chrome-devtools-mcp
    --no-usage-statistics
    --no-performance-crux
    "--wsEndpoint=${browser_cdp_ws_endpoint}"
    "--wsHeaders=${ws_headers_json}"
  )

  chrome_devtools_args+=("${extra_args[@]}")

  exec mcp-proxy "${proxy_args[@]}" -- "${chrome_devtools_args[@]}"
}

main "$@"
