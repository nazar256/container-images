import os
import tempfile
from typing import Set

from dotenv import load_dotenv
from groq import Groq
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes, MessageHandler, filters

load_dotenv()


def parse_bool(value: str, default: bool = False) -> bool:
  if value is None:
    return default
  return value.strip().lower() in {"1", "true", "yes", "on"}


def parse_authorized_users(value: str) -> Set[int]:
  if not value:
    return set()

  users: Set[int] = set()
  for raw_id in value.split(","):
    candidate = raw_id.strip()
    if not candidate:
      continue
    try:
      users.add(int(candidate))
    except ValueError as exc:
      raise ValueError(f"Invalid user id in AUTHORIZED_USERS: {candidate}") from exc
  return users


TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_STT_MODEL = os.getenv("GROQ_STT_MODEL", "whisper-large-v3-turbo")
ENABLE_SUMMARY = parse_bool(os.getenv("ENABLE_SUMMARY", "false"), default=False)
AUTHORIZED_USERS = parse_authorized_users(os.getenv("AUTHORIZED_USERS", ""))

if not TELEGRAM_BOT_TOKEN:
  raise RuntimeError("TELEGRAM_BOT_TOKEN is required")
if not GROQ_API_KEY:
  raise RuntimeError("GROQ_API_KEY is required")
if not AUTHORIZED_USERS:
  raise RuntimeError("AUTHORIZED_USERS must contain at least one Telegram user id")


groq_client = Groq(api_key=GROQ_API_KEY)


def is_authorized(update: Update) -> bool:
  user = update.effective_user
  return user is not None and user.id in AUTHORIZED_USERS


async def reject_unauthorized(update: Update) -> None:
  if update.message:
    await update.message.reply_text("⛔ You are not authorized to use this bot.")


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
  if not is_authorized(update):
    await reject_unauthorized(update)
    return

  mode_text = "enabled" if ENABLE_SUMMARY else "disabled"
  await update.message.reply_text(
      "👋 Voice transcription bot is running.\n"
      f"Summary mode: {mode_text}.\n"
      "Send a voice note and I will transcribe it."
  )


async def transcribe_audio(file_path: str) -> str:
  with open(file_path, "rb") as file:
    transcription = groq_client.audio.transcriptions.create(
        file=(file_path, file.read()),
        model=GROQ_STT_MODEL,
    )
  return transcription.text.strip()


async def generate_summary(text: str) -> str:
  completion = groq_client.chat.completions.create(
      model="llama-3.3-70b-versatile",
      messages=[
          {"role": "system", "content": "Generate a concise summary of the following text."},
          {"role": "user", "content": text},
      ],
      max_completion_tokens=2048,
  )
  return completion.choices[0].message.content.strip()


async def handle_voice(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
  if not is_authorized(update):
    await reject_unauthorized(update)
    return

  if not update.message or not update.message.voice:
    return

  temp_path = ""
  status_message = await update.message.reply_text("🎵 Processing your voice note...")
  try:
    voice_file = await update.message.voice.get_file()
    with tempfile.NamedTemporaryFile(suffix=".ogg", delete=False) as temp_file:
      await voice_file.download_to_drive(temp_file.name)
      temp_path = temp_file.name

    transcription = await transcribe_audio(temp_path)

    if ENABLE_SUMMARY:
      summary = await generate_summary(transcription)
      await status_message.edit_text(
          "📝 Transcription:\n"
          f"{transcription}\n\n"
          "📌 Summary:\n"
          f"{summary}"
      )
    else:
      await status_message.edit_text("📝 Transcription:\n" f"{transcription}")
  except Exception as exc:
    await status_message.edit_text(f"❌ Error: {exc}")
  finally:
    if temp_path and os.path.exists(temp_path):
      os.unlink(temp_path)


async def handle_text(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
  if not is_authorized(update):
    await reject_unauthorized(update)
    return

  if not ENABLE_SUMMARY or not update.message or not update.message.text:
    return

  status_message = await update.message.reply_text("📝 Generating summary...")
  try:
    summary = await generate_summary(update.message.text)
    await status_message.edit_text("📌 Summary:\n" f"{summary}")
  except Exception as exc:
    await status_message.edit_text(f"❌ Error: {exc}")


async def error_handler(update: object, context: ContextTypes.DEFAULT_TYPE) -> None:
  print(f"Update {update} caused error {context.error}")


def build_application() -> Application:
  application = Application.builder().token(TELEGRAM_BOT_TOKEN).build()
  application.add_handler(CommandHandler("start", start))
  application.add_handler(MessageHandler(filters.VOICE, handle_voice))
  if ENABLE_SUMMARY:
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))
  application.add_error_handler(error_handler)
  return application


if __name__ == "__main__":
  app = build_application()
  app.run_polling(allowed_updates=Update.ALL_TYPES, drop_pending_updates=True)
