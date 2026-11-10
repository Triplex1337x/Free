# Плагины и библиотеки с GitHub

В проекте уже всё настроено: открой папку проекта в Claude Code (`claude` в терминале или облачную сессию на claude.ai/code), и он сам предложит поставить плагины, а библиотеки Python поставятся при старте сессии.

## Что подключено сейчас

Файл `.claude/settings.json`:

| Плагин | Зачем |
|---|---|
| `pyright-lsp` | Claude видит ошибки типов и опечатки в Python-коде сразу, как их пишет |
| `commit-commands` | команды `/commit`, `/commit-push-pr` |
| `security-guidance` | предупреждает, если Claude пишет небезопасный код |
| `context7` | Claude подтягивает свежую документацию библиотек (Telethon и любых других) |

Все они из официального каталога [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official), там больше 300 плагинов.

Хук `.claude/hooks/install-deps.sh` при каждом старте сессии ставит всё из `requirements.txt` (и `pyright` для плагина выше).

## Как добавить ещё

### Плагин из официального каталога

В Claude Code напиши `/plugin`, открой вкладку **Discover** и выбери. Или командой:

```bash
claude plugin install имя-плагина@claude-plugins-official --scope project
```

`--scope project` записывает плагин в `.claude/settings.json`, так что он будет у тебя на любом компьютере и в облаке после `git push`.

### Плагин из любого GitHub-репозитория

Репозиторий должен быть «маркетплейсом» (в нём есть файл `.claude-plugin/marketplace.json`):

```bash
claude plugin marketplace add владелец/репозиторий
claude plugin install имя-плагина@имя-маркетплейса --scope project
```

Или вручную в `.claude/settings.json`:

```json
"extraKnownMarketplaces": {
  "мой-маркетплейс": { "source": { "source": "github", "repo": "владелец/репозиторий" } }
},
"enabledPlugins": {
  "имя-плагина@мой-маркетплейс": true
}
```

### MCP-сервер (подключение к сервису: GitHub, Notion, базы данных…)

```bash
claude mcp add --scope project имя -- npx -y пакет-сервера
```

Создастся `.mcp.json` в корне проекта. Ключи API туда не пиши, передавай через переменные окружения.

### Отдельный навык (skill)

Скопируй папку навыка (в ней лежит `SKILL.md`) в `.claude/skills/имя-навыка/`.

### Библиотека Python

Допиши строку в `requirements.txt`, хук поставит её сам. С PyPI:

```
requests>=2.32
```

Прямо с GitHub:

```
git+https://github.com/владелец/репозиторий.git@main
```

## Безопасность

Плагины и MCP-серверы запускают код на твоём компьютере. Ставь только из репозиториев, которым доверяешь. Особенно здесь: у ассистента есть доступ к твоему Telegram.
