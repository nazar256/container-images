# telegram-transcribe-bot image

Telegram bot for voice-note transcription using Groq STT, with allowlist access control.

Upstream source (vendored and adapted in this repository):

- <https://github.com/aviaryan/voice-transcribe-summarize-telegram-bot>

`bot.py` is committed in this repository to keep builds deterministic and independent from upstream changes.

## Runtime environment

Required:

- `TELEGRAM_BOT_TOKEN`
- `GROQ_API_KEY`
- `AUTHORIZED_USERS` (comma-separated Telegram user IDs, for example `12345,67890`)

Optional:

- `ENABLE_SUMMARY` (`false` by default; set `true` to enable summary mode and text-message summary handler)
- `GROQ_STT_MODEL` (`whisper-large-v3-turbo` by default)

Secrets-file support via entrypoint:

- `TELEGRAM_BOT_TOKEN_FILE`
- `GROQ_API_KEY_FILE`

If both `*_FILE` and direct variable are set for the same secret, container exits with error.

## Build locally

```bash
docker build -t telegram-transcribe-bot:local -f images/telegram-transcribe-bot/Dockerfile images/telegram-transcribe-bot
```

## Run locally with plain env vars

```bash
docker run --rm \
  -e TELEGRAM_BOT_TOKEN="<telegram-bot-token>" \
  -e GROQ_API_KEY="<groq-api-key>" \
  -e AUTHORIZED_USERS="12345,67890" \
  -e ENABLE_SUMMARY="false" \
  -e GROQ_STT_MODEL="whisper-large-v3-turbo" \
  telegram-transcribe-bot:local
```

## Run with Docker secrets-style files

```bash
docker run --rm \
  -e AUTHORIZED_USERS="12345,67890" \
  -e ENABLE_SUMMARY="false" \
  -e TELEGRAM_BOT_TOKEN_FILE="/run/secrets/telegram_bot_token" \
  -e GROQ_API_KEY_FILE="/run/secrets/groq_api_key" \
  -v "$PWD/secrets:/run/secrets:ro" \
  telegram-transcribe-bot:local
```

## Pull from GHCR

```bash
docker pull ghcr.io/<owner>/telegram-transcribe-bot:latest
```

## Pull from Docker Hub

```bash
docker pull <dockerhub-username>/telegram-transcribe-bot:latest
```
