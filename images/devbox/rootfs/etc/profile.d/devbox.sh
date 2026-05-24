#!/usr/bin/env bash
set -euo pipefail

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

export GOPATH="${GOPATH:-$HOME/go}"
export GOBIN="${GOBIN:-$HOME/.local/bin}"
export GOMODCACHE="${GOMODCACHE:-$HOME/.cache/go/pkg/mod}"
export GOCACHE="${GOCACHE:-$HOME/.cache/go/build}"

export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$HOME/.cache/terraform/plugin-cache}"

export npm_config_prefix="${npm_config_prefix:-$HOME/.local}"
export npm_config_cache="${npm_config_cache:-$HOME/.cache/npm}"

export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"

export PIPX_HOME="${PIPX_HOME:-$HOME/.local/pipx}"
export PIPX_BIN_DIR="${PIPX_BIN_DIR:-$HOME/.local/bin}"

path_prepend() {
  local dir="$1"
  case ":${PATH}:" in
    *":${dir}:"*) ;;
    *) PATH="${dir}:${PATH}" ;;
  esac
}

path_prepend "${HOME}/.local/bin"
path_prepend "${HOME}/.local/share/mise/shims"
path_prepend "${HOME}/go/bin"
path_prepend "${PNPM_HOME}"

export PATH

