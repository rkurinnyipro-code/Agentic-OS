# Fixpack v1 — 2026-07-08

## Fixed
1. Execute step was dead: worker was a toolless text-completion (`llm`) writing prose;
   git diff was always empty -> eternal FAIL. Now: headless `claude -p` (Sonnet 4.6)
   with Read/Glob/Grep/Edit/Write in the worktree. Override: WORKER_MODEL env.
2. Quiet gate broke after first-ever actionable finding (grep'd whole STATE.md).
   Now gates on fresh triage output only; STATE.md rotated to last 200 lines.
3. All .sh files were mode 100644 (GitHub web UI) -> Permission denied. Zip carries +x;
   after `git add` they commit as 100755.
4. memory/ and goals/ missing -> first write crashed. Created + .gitkeep; scripts mkdir -p.
5. `verify-goals.sh:` (trailing colon) renamed to scripts/verify-goals.sh, WIRED INTO
   loop start: any VIOLATED goal -> exit 4 (contract: "wakes me up").
6. Goal predicates ran arbitrary agent-written shell. Now require `approved: yes`
   (human-flipped) or they're skipped. Closes the self-escalation channel.
7. claude.md -> CLAUDE.md (Claude Code is case-sensitive on mac/Linux).
8. Law #6 violation: conductor ran xhigh inside the loop. Now effort high.
9. Costs were fiction (hardcoded). Conductor/worker/verifier now log real
   `.total_cost_usd` from Claude Code JSON output.
10. macOS portability: date -Is, date -d, %3N, grep -P all replaced (BSD-safe).
11. Worktrees leaked inside repo root, branches collided across days. Now under
    /tmp/agentic-wt (WTBASE env), timestamped branches, removed after ship.
12. `gh pr create` without pushing first hangs interactively (deadly in cron).
    Now explicit `git push -u` first; PR failure logs SHIP-FAILED, not "shipped".
13. Verifier: `git add -N` so new files appear in diff; diff capped 60KB; empty
    diff auto-FAILs without burning a Fable call; jq null-guards on modelUsage;
    malformed work-order JSON -> logged + continue, not crash.
14. guardrails/verify.sh: was npm-only (crashed with no package.json). Now
    npm / python / vacuous-pass-with-warning.

## Apply (from your Agentic-OS clone root)
    git rm 'loop/verify-goals.sh:' claude.md
    unzip -o ~/Downloads/agentic-os-fixpack.zip -x PATCH-NOTES.md
    git add -A && git commit -m "fixpack v1: working execute step + 13 fixes" && git push

## Known limits
- Trust ledger keys off conductor-invented skill names; naming drift fragments history.
- Vacuous guardrail pass on repos with no checks = LLM verifier is the only gate there.
- `--effort` flag support depends on your Claude Code version; if it errors, delete the flag.
