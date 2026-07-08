#!/usr/bin/env bash
set -e
if [ -f package.json ]; then
  npm run typecheck --if-present
  npm test --if-present
  npm run lint --if-present
elif [ -f pyproject.toml ] || [ -f requirements.txt ]; then
  if command -v ruff >/dev/null 2>&1; then ruff check .; fi
  if [ -d tests ] && command -v pytest >/dev/null 2>&1; then pytest -q; fi
else
  echo "guardrails: no checks configured — vacuous pass" >&2
fi
