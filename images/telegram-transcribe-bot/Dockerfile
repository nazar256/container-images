# syntax=docker/dockerfile:1.7
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN addgroup --system app && adduser --system --ingroup app app

COPY requirements.txt ./requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

COPY bot.py ./bot.py
COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x /app/entrypoint.sh && chown -R app:app /app

USER app

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["python", "-u", "bot.py"]
