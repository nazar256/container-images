#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <owner/repository>" >&2
  exit 2
fi

release_url="$(curl -fsSL -o /dev/null -w '%{url_effective}' \
  "https://github.com/$1/releases/latest")"
version="${release_url##*/v}"

if ! [[ "$release_url" =~ /releases/tag/v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Failed to resolve a stable release for $1: $release_url" >&2
  exit 1
fi

printf '%s' "$version"
