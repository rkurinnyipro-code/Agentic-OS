#!/usr/bin/env bash
# Standing goals: goals/<name>.md with lines:
#   predicate: <shell command that exits 0 when goal holds>
#   approved: yes        <- REQUIRED. Predicates run as shell; a human flips this,
#                           never the agent. Unapproved goals are skipped.
#   status: ...  last-pass: ...
set -uo pipefail
cd "$(dirname "$0")/.."
LEDGER="memory/goal-ledger.tsv"; mkdir -p memory; VIOLATIONS=0
for g in goals/*.md; do
  [ -e "$g" ] || continue
  grep -q '^status: retired' "$g" && continue
  grep -q '^approved: yes' "$g" || { echo "skipped (unapproved): $g"; continue; }
  pred=$(grep '^predicate:' "$g" | cut -d' ' -f2-); name=$(basename "$g" .md)
  start=$(date +%s)
  if timeout 60 bash -c "$pred" >/dev/null 2>&1; then r=pass
    sed -i.bak "s/^status:.*/status: satisfied/; s/^last-pass:.*/last-pass: $(date +%F)/" "$g" && rm -f "$g.bak"
  else r=FAIL; VIOLATIONS=$((VIOLATIONS+1))
    sed -i.bak "s/^status:.*/status: VIOLATED/" "$g" && rm -f "$g.bak"; fi
  printf '%s\t%s\t%s\t%ss\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$name" "$r" "$(( $(date +%s) - start ))" >> "$LEDGER"
done
[ "$VIOLATIONS" -gt 0 ] && { grep -l '^status: VIOLATED' goals/*.md; exit 1; }
echo "all standing goals hold"
