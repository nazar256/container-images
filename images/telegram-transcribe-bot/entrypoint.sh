#!/usr/bin/env sh
set -eu

load_secret() {
  var_name="$1"
  file_var_name="${var_name}_FILE"

  file_path="$(eval "printf %s \"\${$file_var_name-}\"")"
  current_value="$(eval "printf %s \"\${$var_name-}\"")"

  if [ -n "$current_value" ] && [ -n "$file_path" ]; then
    echo "Both $var_name and $file_var_name are set; use only one." >&2
    exit 1
  fi

  if [ -n "$file_path" ]; then
    if [ ! -f "$file_path" ]; then
      echo "Secret file not found: $file_path" >&2
      exit 1
    fi
    export "$var_name=$(cat "$file_path")"
  fi
}

load_secret TELEGRAM_BOT_TOKEN
load_secret GROQ_API_KEY

exec "$@"
