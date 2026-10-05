#!/usr/bin/env bash
# Prepare the current repo for a SwarmResearch run. Run at repo root.
set -euo pipefail

[ -d .git ] || { git init -q && echo "git repo initialized"; }

for f in prompt.md; do
  [ -f "$f" ] || echo "WARNING: $f missing on main — create it before spawning agents"
done

touch .gitignore
for pat in ".worktrees/" ".swarm/"; do
  grep -qxF "$pat" .gitignore || echo "$pat" >> .gitignore
done

mkdir -p .swarm/runs .worktrees
[ -f .swarm/ledger.md ] || cat > .swarm/ledger.md <<'EOF'
# SwarmResearch ledger (Shepherd only)

## Runs
| branch | type | parent | family | idea | score | status |
|---|---|---|---|---|---|---|

## Families
EOF
[ -f .swarm/sessions.tsv ] || printf "branch\ttype\tparent\tsession_id\tcost_usd\n" > .swarm/sessions.tsv

if [ -z "$(git log --oneline -1 2>/dev/null)" ]; then
  git add -A && git commit -qm "baseline | score=?" && echo "baseline committed"
fi
echo "ready: $(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD)"
