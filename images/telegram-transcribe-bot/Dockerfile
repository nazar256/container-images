# syntax=docker/dockerfile:1.7
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

ARG BOT_SOURCE_URL=https://raw.githubusercontent.com/aviaryan/voice-transcribe-summarize-telegram-bot/27e47aad6cba61482e10b40a9f5c23be23bf86bc/bot.py

WORKDIR /app

RUN addgroup --system app && adduser --system --ingroup app app

COPY requirements.txt ./requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

RUN apt-get update \
    && apt-get install --yes --no-install-recommends patch \
    && rm -rf /var/lib/apt/lists/*

COPY bot.patch ./bot.patch
RUN python - "$BOT_SOURCE_URL" <<'PY'
import pathlib
import sys
import urllib.request

url = sys.argv[1]
target_path = pathlib.Path("/app/bot.py")
with urllib.request.urlopen(url, timeout=30) as response:
    target_path.write_bytes(response.read())
PY
RUN patch /app/bot.py /app/bot.patch && rm /app/bot.patch

COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x /app/entrypoint.sh && chown -R app:app /app

USER app

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["python", "-u", "bot.py"]
