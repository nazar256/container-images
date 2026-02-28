# Upstream source mapping

This image does not commit upstream application code directly.

Build-time source:

- Repository: https://github.com/aviaryan/voice-transcribe-summarize-telegram-bot
- File downloaded during build: `bot.py`
- Pinned commit in `Dockerfile`: `27e47aad6cba61482e10b40a9f5c23be23bf86bc`

Local repository adaptation:

- `images/telegram-transcribe-bot/bot.patch` is applied during image build.
- Main behavior changes provided by the patch:
  - allowlist from `AUTHORIZED_USERS` environment variable
  - optional summary flow via `ENABLE_SUMMARY` (default `false`)
  - STT model from `GROQ_STT_MODEL` (default `whisper-large-v3-turbo`)
  - container secret-file support through `*_FILE` env handling
