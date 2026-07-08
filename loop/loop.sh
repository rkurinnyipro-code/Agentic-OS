#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
MAX_ITERS="${MAX_ITERS:-10}"
DAILY_BUDGET_USD="${DAILY_BUDGET_USD:-5}"
CHEAP="${CHEAP:-openrouter/deepseek/deepseek-v4-flash}"
WORKER_MODEL="${WORKER_MODEL:-claude-sonnet-4-6}"
WTBASE="${WTBASE:-/tmp/agentic-wt}"

mkdir -p memory goals "$WTBASE"
./scripts/cost-check.sh --budget "$DAILY_BUDGET_USD" || exit 3

# STANDING GOALS: a VIOLATED goal wakes the human (contract) before anything runs
if ! ./scripts/verify-goals.sh >> memory/STATE.md 2>&1; then
  echo "GOAL VIOLATED — see memory/STATE.md and goals/" >&2
  exit 4
fi

for ((i=1; i<=MAX_ITERS; i++)); do
  # 1 TRIAGE: gate on FRESH output only, then append (old bug: grep'd whole history)
  T=$(mktemp)
  { git log --oneline -20; gh issue list --limit 20 2>/dev/null || true; \
    gh run list --limit 10 2>/dev/null || true; } \
    | llm -m "$CHEAP" -s "$(cat triage.md)" > "$T" || true
  ./scripts/log-cost.sh triage 0.01
  cat "$T" >> memory/STATE.md
  tail -n 200 memory/STATE.md > memory/STATE.tmp && mv memory/STATE.tmp memory/STATE.md
  if ! grep -qi "status: *actionable" "$T"; then rm -f "$T"; echo quiet; exit 0; fi
  rm -f "$T"

  # 2 CONDUCT: Fable, effort HIGH inside loops (law #6), fresh context, read-only
  claude -p "$(cat conductor.md)
STATE: $(tail -c 8000 memory/STATE.md)
TRUST: $(./scripts/trust-log.sh --render)
CONTRACT: $(cat contract.md)" \
    --model claude-fable-5 --effort high --allowedTools "Read" \
    --output-format json > /tmp/c.json
  ./scripts/log-cost.sh conductor "$(jq -r '.total_cost_usd // 0.35' /tmp/c.json)"

  # 2a ROUTE-TOLERANCE: never iterate on a model you didn't choose
  SERVED=$(jq -r '(.modelUsage // {}) | keys | .[0] // "claude-fable-5"' /tmp/c.json)
  if [[ "$SERVED" != *fable* ]]; then echo "rerouted: $SERVED" >> memory/STATE.md; exit 2; fi

  # 2b PARSE: strip md fences, validate JSON; garbage -> queue, don't crash
  jq -r '.result' /tmp/c.json | sed '/^```/d' > work-order.json
  if ! jq -e '.action and .skill' work-order.json >/dev/null 2>&1; then
    echo "- MALFORMED work-order iter $i" >> memory/STATE.md; continue
  fi
  SKILL=$(jq -r .skill work-order.json); ACTION=$(jq -r .action work-order.json)
  [[ "$ACTION" == stop  ]] && exit 0
  [[ "$ACTION" == queue ]] && { echo "- queued: $SKILL — $(jq -r .item work-order.json)" >> memory/STATE.md; continue; }

  # 3 EXECUTE: headless claude WITH file tools, isolated worktree OUTSIDE the repo
  BR="loop/$SKILL-$(date +%s)"
  WT="$WTBASE/$BR"; mkdir -p "$(dirname "$WT")"
  git worktree add "$WT" -b "$BR" >/dev/null
  WJ=$(cd "$WT" && claude -p "$(cat "$OLDPWD/workers/implement.md")
WORK ORDER: $(cat "$OLDPWD/work-order.json")" \
    --model "$WORKER_MODEL" --effort medium \
    --allowedTools "Read,Glob,Grep,Edit,Write" \
    --permission-mode acceptEdits --output-format json) || true
  ./scripts/log-cost.sh worker "$(jq -r '.total_cost_usd // 0.10' <<<"$WJ" 2>/dev/null || echo 0.10)"

  # 4 VERIFY: fresh Fable, no tools, sees only spec + diff (-N exposes new files; cap 60KB)
  DIFF=$(cd "$WT" && git add -AN && git diff | head -c 60000)
  if [ -z "$DIFF" ]; then
    V="FAIL: empty diff — worker changed nothing"
  else
    VJ=$(claude -p "$(cat workers/verify.md)
SPEC: $(jq -r .spec work-order.json)
DONE_WHEN: $(jq -r '(.done_when // []) | join("; ")' work-order.json)
DIFF: $DIFF" \
      --model claude-fable-5 --effort high --allowedTools "" --output-format json)
    ./scripts/log-cost.sh verifier "$(jq -r '.total_cost_usd // 0.40' <<<"$VJ")"
    V=$(jq -r .result <<<"$VJ")
  fi

  # 5 GATE: deterministic final vote; ship only at auto tier; push BEFORE pr (else gh hangs)
  if [[ "$V" == PASS* ]] && ( cd "$WT" && "$OLDPWD/guardrails/verify.sh" ); then
    ./scripts/trust-log.sh "$SKILL" pass
    if [[ "$(./scripts/trust-log.sh --tier "$SKILL")" == auto ]]; then
      if ( cd "$WT" && git add -A && git commit -qm "loop: $SKILL" \
           && git push -qu origin "$BR" && gh pr create --fill ); then
        echo "- shipped: $SKILL ($BR)" >> memory/STATE.md
        git worktree remove --force "$WT" 2>/dev/null || true
      else
        echo "- SHIP-FAILED: $SKILL in $WT" >> memory/STATE.md
      fi
    else
      ( cd "$WT" && git add -A && git commit -qm "loop: $SKILL [review]" )
      echo "- review ($(./scripts/trust-log.sh --tier "$SKILL")): $SKILL in $WT" >> memory/STATE.md
    fi
  else
    ./scripts/trust-log.sh "$SKILL" fail
    echo "- FAILED: $SKILL — ${V%%
*} — in $WT" >> memory/STATE.md
  fi
  ./scripts/cost-check.sh --budget "$DAILY_BUDGET_USD" || exit 3
done
exit 1   # iteration cap without stop: check STATE.md
