#!/usr/bin/env bash
set -euo pipefail

# An empty password both unlocks an existing passwordless login keyring and
# creates it on first use.  The daemon publishes Secret Service on the private
# session bus created by dbus-run-session in docker-entrypoint.sh.
keyring_environment="$(printf '\n' | gnome-keyring-daemon --unlock --components=secrets)"
while IFS= read -r assignment; do
  case "$assignment" in
    GNOME_KEYRING_CONTROL=*|SSH_AUTH_SOCK=*) export "$assignment" ;;
  esac
done <<< "$keyring_environment"

exec "$@"
