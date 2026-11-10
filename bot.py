"""Telegram-бот, в котором отвечает Claude.

Два режима работы (переменная CLAUDE_BACKEND в .env):

  cli  — через установленный Claude Code (`claude`). Работает по твоей подписке
         Pro/Max, отдельный API-ключ не нужен. Компьютер с ботом должен быть
         включён, а в Claude Code нужно один раз войти (команда `claude`).
         Только для личного пользования.

  api  — через Claude API. Нужен ANTHROPIC_API_KEY с console.anthropic.com
         (оплачивается отдельно, по факту). Подходит, чтобы бот работал 24/7
         на сервере и отвечал не только тебе.

Запуск:  python bot.py
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import shutil
from pathlib import Path

from dotenv import load_dotenv
from telegram import Update
from telegram.constants import ChatAction
from telegram.ext import (
    Application,
    CommandHandler,
    ContextTypes,
    MessageHandler,
    filters,
)

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

logging.basicConfig(
    format="%(asctime)s %(levelname)s %(name)s: %(message)s", level=logging.INFO
)
# Чтобы токен бота не светился в логах вместе с URL запросов.
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpx2").setLevel(logging.WARNING)
log = logging.getLogger("claude-bot")

# ---------------------------------------------------------------- настройки --

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
BACKEND = os.getenv("CLAUDE_BACKEND", "cli").strip().lower()
ALLOWED_USER_IDS = {
    int(x) for x in os.getenv("ALLOWED_USER_IDS", "").replace(" ", "").split(",") if x
}
CLAUDE_MODEL = os.getenv("CLAUDE_MODEL", "").strip()
SYSTEM_PROMPT = os.getenv("SYSTEM_PROMPT", "").strip() or (
    "Ты — Claude, дружелюбный ассистент в Telegram. Отвечай на языке собеседника, "
    "по делу и без воды. Это мессенджер: пиши коротко, обычным текстом, "
    "без Markdown-разметки, если не просят код."
)
CLI_TIMEOUT_SEC = int(os.getenv("CLAUDE_TIMEOUT_SEC", "300"))
MAX_HISTORY_MESSAGES = 40  # для режима api: сколько последних сообщений помнить
TELEGRAM_LIMIT = 4000  # Telegram режет сообщения длиннее 4096 символов

SESSIONS_FILE = BASE_DIR / "sessions.json"  # режим cli: chat_id -> id сессии Claude
WORKDIR = BASE_DIR / "claude_workdir"  # пустая папка, в которой запускается claude


# ------------------------------------------------------------- режим "cli" --


class ClaudeCodeBackend:
    """Отвечает через `claude -p` (Claude Code в неинтерактивном режиме)."""

    def __init__(self) -> None:
        cli = os.getenv("CLAUDE_CLI_PATH", "").strip() or "claude"
        resolved = shutil.which(cli)
        if not resolved:
            raise SystemExit(
                f"Не нашёл команду '{cli}'. Установи Claude Code и проверь "
                "`claude --version`, либо укажи полный путь в CLAUDE_CLI_PATH."
            )
        self.cli = resolved
        WORKDIR.mkdir(exist_ok=True)
        self.sessions: dict[str, str] = self._load_sessions()

    @staticmethod
    def _load_sessions() -> dict[str, str]:
        try:
            return json.loads(SESSIONS_FILE.read_text(encoding="utf-8"))
        except (FileNotFoundError, json.JSONDecodeError):
            return {}

    def _save_sessions(self) -> None:
        SESSIONS_FILE.write_text(
            json.dumps(self.sessions, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    def reset(self, chat_id: int) -> None:
        self.sessions.pop(str(chat_id), None)
        self._save_sessions()

    async def _run(self, text: str, session_id: str | None) -> dict:
        args = [
            self.cli,
            "-p",
            "--output-format", "json",
            # Без инструментов: бот только разговаривает и ничего не делает
            # на твоём компьютере (не читает файлы, не запускает команды).
            "--tools", "",
            "--strict-mcp-config",
            "--system-prompt", SYSTEM_PROMPT,
        ]
        if CLAUDE_MODEL:
            args += ["--model", CLAUDE_MODEL]
        if session_id:
            args += ["--resume", session_id]

        proc = await asyncio.create_subprocess_exec(
            *args,
            cwd=WORKDIR,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        try:
            # Текст передаём через stdin, а не аргументом: так не ломаются
            # кавычки, переносы строк и сообщения, начинающиеся с "-".
            out, err = await asyncio.wait_for(
                proc.communicate(text.encode("utf-8")), timeout=CLI_TIMEOUT_SEC
            )
        except asyncio.TimeoutError:
            proc.kill()
            await proc.wait()
            raise RuntimeError("Claude думал слишком долго, попробуй ещё раз.")

        stdout = out.decode("utf-8", errors="replace").strip()
        try:
            return json.loads(stdout)
        except json.JSONDecodeError:
            details = (err.decode("utf-8", errors="replace") or stdout).strip()
            raise RuntimeError(f"Claude Code вернул ошибку:\n{details[-1500:]}")

    async def ask(self, chat_id: int, text: str) -> str:
        key = str(chat_id)
        session_id = self.sessions.get(key)
        data = await self._run(text, session_id)

        # Сессия могла пропасть (например, её удалили) — начинаем заново.
        if data.get("is_error") and session_id:
            log.warning("Не удалось продолжить сессию %s, начинаю новую", session_id)
            self.reset(chat_id)
            data = await self._run(text, None)

        if data.get("is_error"):
            raise RuntimeError(
                "Claude Code вернул ошибку: "
                + str(data.get("result") or data.get("subtype") or "неизвестно")
                + "\nПроверь, что ты вошёл в аккаунт: запусти `claude` в терминале."
            )

        if data.get("session_id"):
            self.sessions[key] = data["session_id"]
            self._save_sessions()
        return (data.get("result") or "").strip()


# ------------------------------------------------------------- режим "api" --


class ClaudeApiBackend:
    """Отвечает через Claude API (нужен ANTHROPIC_API_KEY)."""

    def __init__(self) -> None:
        import anthropic

        if not os.getenv("ANTHROPIC_API_KEY"):
            raise SystemExit(
                "Для CLAUDE_BACKEND=api нужен ANTHROPIC_API_KEY в .env "
                "(создаётся на console.anthropic.com)."
            )
        self.anthropic = anthropic
        self.client = anthropic.AsyncAnthropic()
        self.model = CLAUDE_MODEL or "claude-opus-5-5"
        self.effort = os.getenv("CLAUDE_EFFORT", "low").strip()
        # Переписка хранится в памяти: после перезапуска бот всё забывает.
        self.history: dict[int, list[dict]] = {}

    def reset(self, chat_id: int) -> None:
        self.history.pop(chat_id, None)

    async def ask(self, chat_id: int, text: str) -> str:
        history = self.history.setdefault(chat_id, [])
        messages = history + [{"role": "user", "content": text}]

        try:
            response = await self.client.beta.messages.create(
                model=self.model,
                max_tokens=16000,
                system=SYSTEM_PROMPT,
                messages=messages,
                output_config={"effort": self.effort},
                # Если модель откажется отвечать, API сам повторит запрос
                # на подходящей запасной модели.
                betas=["server-side-fallback-2026-07-01"],
                fallbacks="default",
            )
        except self.anthropic.AuthenticationError:
            raise RuntimeError("Неверный ANTHROPIC_API_KEY.")
        except self.anthropic.RateLimitError:
            raise RuntimeError("Слишком много запросов, подожди минутку.")
        except self.anthropic.APIStatusError as e:
            raise RuntimeError(f"Ошибка Claude API ({e.status_code}): {e.message}")
        except self.anthropic.APIConnectionError:
            raise RuntimeError("Не удалось связаться с Claude API.")

        if response.stop_reason == "refusal":
            return "Claude отказался отвечать на это сообщение."

        answer = "".join(b.text for b in response.content if b.type == "text").strip()

        # В историю кладём только текст: так переписка остаётся простой и валидной.
        history.append({"role": "user", "content": text})
        history.append({"role": "assistant", "content": answer or "…"})
        if len(history) > MAX_HISTORY_MESSAGES:
            del history[: len(history) - MAX_HISTORY_MESSAGES]
        return answer


# --------------------------------------------------------------- Telegram --


def is_allowed(update: Update) -> bool:
    user = update.effective_user
    return user is not None and user.id in ALLOWED_USER_IDS


async def deny(update: Update) -> None:
    user = update.effective_user
    uid = user.id if user else "?"
    log.info("Отказано пользователю %s", uid)
    if not ALLOWED_USER_IDS:
        await update.effective_message.reply_text(
            f"Бот ещё не настроен. Твой Telegram ID: {uid}\n"
            "Впиши его в ALLOWED_USER_IDS в файле .env и перезапусти бота."
        )
    else:
        await update.effective_message.reply_text("Извини, этот бот приватный.")


def split_message(text: str, limit: int = TELEGRAM_LIMIT) -> list[str]:
    parts = []
    while len(text) > limit:
        cut = text.rfind("\n", 0, limit)
        if cut < limit // 2:
            cut = text.rfind(" ", 0, limit)
        if cut < limit // 2:
            cut = limit
        parts.append(text[:cut])
        text = text[cut:].lstrip()
    if text:
        parts.append(text)
    return parts


async def keep_typing(chat, stop: asyncio.Event) -> None:
    """Показывает «печатает…», пока Claude думает."""
    while not stop.is_set():
        try:
            await chat.send_action(ChatAction.TYPING)
        except Exception:  # не критично, если не получилось
            pass
        try:
            await asyncio.wait_for(stop.wait(), timeout=4)
        except asyncio.TimeoutError:
            pass


async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update):
        return await deny(update)
    await update.effective_message.reply_text(
        "Привет! Я Claude. Просто пиши — я отвечу.\n"
        "/reset — начать разговор заново\n"
        "/id — показать твой Telegram ID"
    )


async def cmd_id(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await update.effective_message.reply_text(
        f"Твой Telegram ID: {update.effective_user.id}"
    )


async def cmd_reset(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update):
        return await deny(update)
    context.application.bot_data["backend"].reset(update.effective_chat.id)
    await update.effective_message.reply_text("Ок, начинаем с чистого листа.")


async def on_text(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update):
        return await deny(update)

    chat_id = update.effective_chat.id
    backend = context.application.bot_data["backend"]
    locks: dict[int, asyncio.Lock] = context.application.bot_data["locks"]
    lock = locks.setdefault(chat_id, asyncio.Lock())

    # Сообщения из одного чата обрабатываем по очереди, чтобы не путать контекст.
    async with lock:
        stop = asyncio.Event()
        typing = asyncio.create_task(keep_typing(update.effective_chat, stop))
        try:
            answer = await backend.ask(chat_id, update.effective_message.text)
        except Exception as e:  # показываем ошибку в чате, а не роняем бота
            log.exception("Ошибка при ответе")
            answer = f"⚠️ {e}"
        finally:
            stop.set()
            await typing

    for part in split_message(answer or "(пустой ответ)"):
        await update.effective_message.reply_text(part)


def main() -> None:
    if not TELEGRAM_BOT_TOKEN:
        raise SystemExit(
            "Нет TELEGRAM_BOT_TOKEN. Скопируй .env.example в .env и впиши токен "
            "от @BotFather."
        )
    if BACKEND == "cli":
        backend = ClaudeCodeBackend()
    elif BACKEND == "api":
        backend = ClaudeApiBackend()
    else:
        raise SystemExit("CLAUDE_BACKEND должен быть 'cli' или 'api'.")

    app = Application.builder().token(TELEGRAM_BOT_TOKEN).concurrent_updates(True).build()
    app.bot_data["backend"] = backend
    app.bot_data["locks"] = {}

    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("id", cmd_id))
    app.add_handler(CommandHandler("reset", cmd_reset))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, on_text))

    if not ALLOWED_USER_IDS:
        log.warning("ALLOWED_USER_IDS пуст — бот никому не отвечает. Напиши ему /id.")
    log.info("Бот запущен (режим: %s). Остановить: Ctrl+C", BACKEND)
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
