# opencode-telegram-bot image

Container image for `@grinev/opencode-telegram-bot` CLI.

## Build locally

```bash
docker build \
  -t opencode-telegram-bot:0.9.2 \
  --build-arg BOT_VERSION=0.9.2 \
  -f images/opencode-telegram-bot/Dockerfile \
  images/opencode-telegram-bot
```

## Smoke check

```bash
docker run --rm --entrypoint opencode-telegram opencode-telegram-bot:0.9.2 --help
docker run --rm --entrypoint sh opencode-telegram-bot:0.9.2 -ceu 'test -d /home/node/.config/opencode-telegram-bot'
```

## Run locally

```bash
docker run --rm \
  -e TELEGRAM_BOT_TOKEN=... \
  -e TELEGRAM_ALLOWED_USER_ID=... \
  -e OPENCODE_MODEL_PROVIDER=... \
  -e OPENCODE_MODEL_ID=... \
  -e OPENCODE_API_URL=http://localhost:4096 \
  opencode-telegram-bot:0.9.2
```

Optional voice/STT variables:

- `STT_API_URL`
- `STT_API_KEY`
- `STT_MODEL`

## Pull from GHCR

```bash
docker pull ghcr.io/<owner>/opencode-telegram-bot:latest
```

## Pull from Docker Hub

```bash
docker pull <dockerhub-username>/opencode-telegram-bot:latest
```
