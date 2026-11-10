#!/usr/bin/env bash
# Ставит библиотеки проекта при старте сессии Claude Code.
# Новые библиотеки (в том числе прямо с GitHub) добавляй в requirements.txt.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"

if [ -f requirements.txt ]; then
  python3 -m pip install -q --use-pep517 -r requirements.txt 2>&1 | tail -n 5 || echo "pip: не удалось поставить requirements.txt" >&2
fi

# Языковой сервер для плагина pyright-lsp
if ! command -v pyright-langserver >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  npm install -g pyright >/dev/null 2>&1 || echo "npm: не удалось поставить pyright" >&2
fi
exit 0
