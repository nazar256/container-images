# Vendored source

This image vendors and adapts code from:

- Repository: https://github.com/aviaryan/voice-transcribe-summarize-telegram-bot
- File: `bot.py`
- Branch used: `master`

Main adaptations for container runtime in this repo:

- allowlist from `AUTHORIZED_USERS` environment variable
- optional summary flow via `ENABLE_SUMMARY` (default `false`)
- STT model from `GROQ_STT_MODEL` (default `whisper-large-v3-turbo`)
- container secret-file support through `*_FILE` env handling
