#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <package> <semver-range>" >&2
  exit 2
fi

package="$1"
version_range="$2"
versions_json="$(npm view "${package}@${version_range}" version --json)"

VERSION_RANGE="$version_range" node -e '
const versions = JSON.parse(process.argv[1]);
const candidates = (Array.isArray(versions) ? versions : [versions])
  .filter((version) => typeof version === "string" && /^\d+\.\d+\.\d+$/.test(version))
  .sort((left, right) => {
    const a = left.split(".").map(Number);
    const b = right.split(".").map(Number);
    return a[0] - b[0] || a[1] - b[1] || a[2] - b[2];
  });

if (candidates.length === 0) {
  console.error(`No stable version matched ${process.env.VERSION_RANGE}`);
  process.exit(1);
}

process.stdout.write(candidates.at(-1));
' "$versions_json"
