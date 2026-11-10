"""Claude пишет людям в Telegram от твоего имени — по твоей команде.

Как пользоваться: в своём Telegram открой «Избранное» (Saved Messages) и напиши:

    клод, напиши Артёму: скинь ДЗ пж
        → отправит Артёму ровно «скинь ДЗ пж»

    клод, ответь Артёму, что буду в 5, и извинись за опоздание
        → Claude прочитает вашу переписку, сам сочинит ответ в твоём стиле
          и покажет черновик. Отправит, когда ответишь «+».

    +  /  да          → отправить черновик
    -  /  нет         → отменить черновик
    удали             → удалить последнее отправленное сообщение у обоих

Работает через твой аккаунт Telegram (Telethon) и твой Claude Code (подписка,
без API-ключа). Запуск: python assistant.py
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import shutil
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv
from telethon import TelegramClient, events

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

logging.basicConfig(format="%(asctime)s %(levelname)s: %(message)s", level=logging.INFO)
logging.getLogger("telethon").setLevel(logging.WARNING)
log = logging.getLogger("assistant")

# ---------------------------------------------------------------- настройки --

API_ID = os.getenv("TELEGRAM_API_ID", "").strip()
API_HASH = os.getenv("TELEGRAM_API_HASH", "").strip()
SESSION_FILE = BASE_DIR / "telegram"  # создастся telegram.session — НИКОМУ не давай

# С чего должна начинаться команда в «Избранном» (остальные заметки не трогаем).
TRIGGERS = [
    t.strip().lower()
    for t in os.getenv("TRIGGERS", "клод,claude,!").split(",")
    if t.strip()
]
# Когда спрашивать подтверждение: always — всегда, compose — только если текст
# сочинил Claude (по умолчанию), never — никогда.
CONFIRM = os.getenv("CONFIRM", "compose").strip().lower()
CLAUDE_MODEL = os.getenv("CLAUDE_MODEL", "").strip()
CLAUDE_TIMEOUT_SEC = int(os.getenv("CLAUDE_TIMEOUT_SEC", "180"))
DIALOGS_LIMIT = 150  # сколько последних чатов показывать Claude для поиска получателя
HISTORY_LIMIT = 20  # сколько последних сообщений читать, чтобы сочинить ответ

MARK = "🤖"  # так начинаются ответы ассистента, чтобы он не реагировал сам на себя
YES = {"+", "да", "ок", "ok", "отправь", "отправляй", "го", "давай", "yes"}
NO = {"-", "нет", "отмена", "не надо", "no", "стоп"}
UNDO = {"удали", "отзови", "удали последнее", "undo"}


# ----------------------------------------------------------- Claude Code ---


class ClaudeError(RuntimeError):
    pass


async def ask_claude(system_prompt: str, prompt: str) -> str:
    """Один запрос к Claude через `claude -p`. Возвращает текст ответа."""
    cli = shutil.which(os.getenv("CLAUDE_CLI_PATH", "").strip() or "claude")
    if not cli:
        raise ClaudeError(
            "не нашёл команду claude. Установи Claude Code или укажи CLAUDE_CLI_PATH."
        )
    workdir = BASE_DIR / "claude_workdir"
    workdir.mkdir(exist_ok=True)

    args = [
        cli, "-p",
        "--output-format", "json",
        "--tools", "",  # никаких инструментов: Claude только думает и пишет текст
        "--strict-mcp-config",
        "--no-session-persistence",
        "--system-prompt", system_prompt,
    ]
    if CLAUDE_MODEL:
        args += ["--model", CLAUDE_MODEL]

    proc = await asyncio.create_subprocess_exec(
        *args,
        cwd=workdir,
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        out, err = await asyncio.wait_for(
            proc.communicate(prompt.encode("utf-8")), timeout=CLAUDE_TIMEOUT_SEC
        )
    except asyncio.TimeoutError:
        proc.kill()
        await proc.wait()
        raise ClaudeError("Claude не ответил вовремя, попробуй ещё раз.")

    try:
        data = json.loads(out.decode("utf-8", errors="replace"))
    except json.JSONDecodeError:
        details = err.decode("utf-8", errors="replace").strip()[-800:]
        raise ClaudeError(f"Claude Code упал: {details or 'нет подробностей'}")
    if data.get("is_error"):
        raise ClaudeError(
            f"Claude Code вернул ошибку: {data.get('result') or data.get('subtype')}. "
            "Проверь, что ты вошёл в аккаунт (запусти `claude` в терминале)."
        )
    return (data.get("result") or "").strip()


def extract_json(text: str) -> dict:
    """Достаёт JSON-объект из ответа, даже если Claude обернул его в текст."""
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end <= start:
        raise ClaudeError("Claude ответил не по формату, переформулируй команду.")
    try:
        return json.loads(text[start : end + 1])
    except json.JSONDecodeError:
        raise ClaudeError("Claude ответил не по формату, переформулируй команду.")


PARSE_SYSTEM = """Ты разбираешь команды владельца Telegram-аккаунта. Он пишет, кому и что \
отправить. Тебе дают список его чатов (id | имя | @username | тип) и команду.

Верни ТОЛЬКО JSON, без пояснений:
{"action": "send" | "unclear",
 "chat_id": <id из списка или null>,
 "mode": "verbatim" | "compose",
 "text": "<точный текст для verbatim>",
 "instruction": "<что нужно сказать, для compose>",
 "question": "<вопрос владельцу, если unclear>"}

Правила:
- Имена в команде склоняются (Артёму, Артему, Артёма = Артём). Учитывай ники и сокращения.
- Если подходят несколько чатов или ни одного — action "unclear", в question перечисли \
варианты или спроси, кого он имел в виду.
- mode "verbatim", если владелец дал готовый текст (после двоеточия, в кавычках, \
«напиши ему: ...»). Тогда text — ровно этот текст, без изменений и без кавычек.
- mode "compose", если он описал смысл («ответь, что...», «извинись», «спроси, как дела», \
«ответь ему что-нибудь»). Тогда instruction — суть того, что надо написать.
- Ничего не придумывай про получателя: chat_id бери только из списка."""

COMPOSE_SYSTEM = """Ты пишешь сообщение в Telegram от имени владельца аккаунта. \
Пиши от первого лица, как будто это пишет он сам: его стиль, длина, регистр, сленг и \
эмодзи — смотри на его прошлые сообщения в переписке («Я:»). Не упоминай, что ты ИИ. \
Никаких кавычек, пояснений и вариантов — верни только текст сообщения."""


# ---------------------------------------------------------------- Telegram --


@dataclass
class Draft:
    entity: object
    name: str
    text: str


@dataclass
class Sent:
    entity: object
    name: str
    message_id: int


def kind_of(dialog) -> str:
    if dialog.is_user:
        return "бот" if getattr(dialog.entity, "bot", False) else "человек"
    return "группа" if dialog.is_group else "канал"


class Assistant:
    def __init__(self, client: TelegramClient) -> None:
        self.client = client
        self.draft: Draft | None = None
        self.last_sent: Sent | None = None
        self.lock = asyncio.Lock()

    async def say(self, text: str) -> None:
        await self.client.send_message("me", f"{MARK} {text}")

    async def handle(self, raw: str) -> None:
        text = raw.strip()
        low = text.lower().rstrip("!.")

        if self.draft and low in YES:
            draft, self.draft = self.draft, None
            return await self.send(draft.entity, draft.name, draft.text)
        if self.draft and low in NO:
            self.draft = None
            return await self.say("Ок, не отправляю.")
        if low in UNDO:
            return await self.undo()

        command = self.strip_trigger(text)
        if command is None:
            return  # обычная заметка в «Избранном», не команда
        if not command:
            return await self.say("Слушаю. Например: «клод, напиши Артёму: скинь ДЗ пж»")

        self.draft = None  # новая команда отменяет старый черновик
        await self.run_command(command)

    @staticmethod
    def strip_trigger(text: str) -> str | None:
        low = text.lower()
        for trigger in TRIGGERS:
            if low.startswith(trigger):
                return text[len(trigger) :].lstrip(" ,:—-").strip()
        return None

    async def run_command(self, command: str) -> None:
        # 1. Список чатов, чтобы Claude понял, кто такой «Артём».
        chats: dict[int, tuple[object, str]] = {}
        lines = []
        async for d in self.client.iter_dialogs(limit=DIALOGS_LIMIT):
            if getattr(d.entity, "is_self", False):
                continue
            if d.is_channel and not d.is_group:
                continue  # в каналы писать нельзя (если ты не админ) — пропускаем
            username = getattr(d.entity, "username", None)
            chats[d.id] = (d.entity, d.name)
            lines.append(
                f"{d.id} | {d.name} | {'@' + username if username else '-'} | {kind_of(d)}"
            )

        plan = extract_json(
            await ask_claude(
                PARSE_SYSTEM, "Чаты:\n" + "\n".join(lines) + f"\n\nКоманда: {command}"
            )
        )

        if plan.get("action") != "send":
            return await self.say(plan.get("question") or "Не понял, кому писать. Уточни.")
        try:
            entity, name = chats[int(plan.get("chat_id"))]
        except (KeyError, TypeError, ValueError):
            return await self.say("Не нашёл такого чата. Напиши имя точнее.")

        # 2. Готовый текст или сочиняем сами.
        if plan.get("mode") == "compose":
            text = await self.compose(entity, name, plan.get("instruction") or command)
            needs_confirm = CONFIRM in ("always", "compose")
        else:
            text = (plan.get("text") or "").strip()
            needs_confirm = CONFIRM == "always"
        if not text:
            return await self.say("Не понял, что именно написать. Уточни.")

        if needs_confirm:
            self.draft = Draft(entity, name, text)
            return await self.say(
                f"Черновик → {name}:\n\n{text}\n\nОтправить? «+» — да, «-» — нет."
            )
        await self.send(entity, name, text)

    async def compose(self, entity, name: str, instruction: str) -> str:
        history = []
        async for m in self.client.iter_messages(entity, limit=HISTORY_LIMIT):
            if not m.message:
                continue
            if m.out:
                author = "Я"
            else:
                sender = await m.get_sender()
                author = getattr(sender, "first_name", None) or name
            history.append(f"{author}: {m.message}")
        history.reverse()

        prompt = (
            f"Переписка с «{name}» (старые сверху):\n"
            + ("\n".join(history) or "(пока пусто)")
            + f"\n\nЧто нужно написать: {instruction}"
        )
        return await ask_claude(COMPOSE_SYSTEM, prompt)

    async def send(self, entity, name: str, text: str) -> None:
        msg = await self.client.send_message(entity, text)
        self.last_sent = Sent(entity, name, msg.id)
        log.info("Отправлено → %s", name)
        await self.say(f"Отправил → {name}:\n\n{text}\n\n(«удали» — удалить у обоих)")

    async def undo(self) -> None:
        if not self.last_sent:
            return await self.say("Пока нечего удалять.")
        sent, self.last_sent = self.last_sent, None
        await self.client.delete_messages(sent.entity, [sent.message_id], revoke=True)
        await self.say(f"Удалил последнее сообщение в чате «{sent.name}».")


async def main() -> None:
    if not API_ID or not API_HASH:
        raise SystemExit(
            "Нет TELEGRAM_API_ID / TELEGRAM_API_HASH. Получи их на my.telegram.org "
            "(API development tools) и впиши в .env."
        )

    client = TelegramClient(str(SESSION_FILE), int(API_ID), API_HASH)
    await client.start()  # при первом запуске спросит номер телефона и код из Telegram
    me = await client.get_me()
    assistant = Assistant(client)

    @client.on(events.NewMessage(outgoing=True))
    async def on_message(event) -> None:
        # Реагируем только на то, что ты пишешь сам себе в «Избранное».
        if event.chat_id != me.id:
            return
        text = event.raw_text or ""
        if not text or text.startswith(MARK):
            return
        async with assistant.lock:
            try:
                await assistant.handle(text)
            except ClaudeError as e:
                await assistant.say(f"⚠️ {e}")
            except Exception as e:  # не роняем ассистента из-за одной ошибки
                log.exception("Ошибка")
                await assistant.say(f"⚠️ Что-то пошло не так: {e}")

    log.info("Готово! Пиши команды в «Избранное», например: клод, напиши Артёму: привет")
    await assistant.say(
        "Я на связи. Пиши: «клод, напиши Артёму: скинь ДЗ пж» "
        "или «клод, ответь Артёму, что буду в 5»."
    )
    await client.run_until_disconnected()


if __name__ == "__main__":
    asyncio.run(main())
