# Upstream source mapping

This image vendors and adapts code from upstream.

Source baseline:

- Repository: https://github.com/aviaryan/voice-transcribe-summarize-telegram-bot
- File: `bot.py`
- Branch used: `master`

Local repository adaptation:

- `images/telegram-transcribe-bot/bot.py` is committed in this repository.
- Main behavior changes in the vendored file:
  - allowlist from `AUTHORIZED_USERS` environment variable
  - optional summary flow via `ENABLE_SUMMARY` (default `false`)
  - STT model from `GROQ_STT_MODEL` (default `whisper-large-v3-turbo`)
  - container secret-file support through `*_FILE` env handling
