#!/usr/bin/env bash
set -euo pipefail

if [ ! -d "images" ]; then
  exit 0
fi

for dir in images/*; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")

  case "$name" in
    _template|.*)
      continue
      ;;
  esac

  printf '%s\n' "$name"
done | sort
