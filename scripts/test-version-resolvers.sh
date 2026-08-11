#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixtures="$(mktemp -d)"
trap 'rm -rf "$fixtures"' EXIT

cat >"$fixtures/npm" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${FAKE_NPM_VERSIONS:-[\"6.10.2\", \"6.5.1\", \"6.11.0-beta.1\", \"6.9.12\"]}"
EOF

cat >"$fixtures/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s' "${FAKE_RELEASE_URL:-https://github.com/smart-mcp-proxy/mcpproxy-go/releases/tag/v0.42.3}"
EOF

chmod +x "$fixtures/npm" "$fixtures/curl"

resolved_npm="$(PATH="$fixtures:$PATH" \
  "$repo_root/scripts/resolve-npm-version.sh" mcp-proxy '^6.5.1')"
test "$resolved_npm" = "6.10.2"

resolved_github="$(PATH="$fixtures:$PATH" \
  "$repo_root/scripts/resolve-github-release.sh" smart-mcp-proxy/mcpproxy-go)"
test "$resolved_github" = "0.42.3"

if FAKE_NPM_VERSIONS='["7.0.0-beta.1"]' PATH="$fixtures:$PATH" \
    "$repo_root/scripts/resolve-npm-version.sh" mcp-proxy '^6.5.1' >/dev/null 2>&1; then
  echo 'npm resolver accepted a prerelease-only result' >&2
  exit 1
fi

if FAKE_RELEASE_URL='https://example.test/releases/tag/latest' PATH="$fixtures:$PATH" \
    "$repo_root/scripts/resolve-github-release.sh" smart-mcp-proxy/mcpproxy-go >/dev/null 2>&1; then
  echo 'GitHub resolver accepted a malformed release URL' >&2
  exit 1
fi

printf '%s\n' 'version resolver tests passed'
