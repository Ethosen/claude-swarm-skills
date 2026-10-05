#!/usr/bin/env bash
# Spawn one SwarmResearch Search Agent. Run at repo root (via Bash tool, run_in_background).
# Usage: spawn.sh <explorer|optimizer> <branch> <parent[,parent2,...]> "<context>"
# Env:   SWARM_BUDGET_USD (default 3), SWARM_MODEL (optional), SWARM_PERMISSION (default bypassPermissions)
set -euo pipefail

TYPE="$1"; BRANCH="$2"; PARENTS="$3"; CONTEXT="${4:-}"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
BUDGET="${SWARM_BUDGET_USD:-3}"
PERM="${SWARM_PERMISSION:-bypassPermissions}"
MODEL_ARGS=(); [ -n "${SWARM_MODEL:-}" ] && MODEL_ARGS=(--model "$SWARM_MODEL")

git rev-parse --verify -q "refs/heads/$BRANCH" >/dev/null && { echo "branch $BRANCH already exists" >&2; exit 1; }

IFS=',' read -r -a PLIST <<< "$PARENTS"
FIRST="${PLIST[0]}"
git branch "$BRANCH" "$FIRST"
git worktree add -q ".worktrees/$BRANCH" "$BRANCH"

for p in "${PLIST[@]:1}"; do
  git -C ".worktrees/$BRANCH" merge --no-commit --no-ff "$p" || echo "merge of $p has conflicts — agent must resolve"
done

WT=".worktrees/$BRANCH"
OUT=".swarm/runs/$BRANCH.json"
BASE="Your branch name is $BRANCH. Your worktree is $WT (relative to the current directory) — cd into it and work only there."
[ "${#PLIST[@]}" -gt 1 ] && BASE="$BASE Your worktree contains an uncommitted merge of parents ${PARENTS}; resolve it as part of your idea."
[ -n "$CONTEXT" ] && BASE="$BASE Context: $CONTEXT"

case "$TYPE" in
  explorer)
    PROMPT="Follow the instructions in $SKILL_DIR/explorer.md exactly. $BASE"
    claude -p "$PROMPT" --permission-mode "$PERM" --output-format json \
      --max-budget-usd "$BUDGET" "${MODEL_ARGS[@]}" > "$OUT"
    ;;
  optimizer)
    PSID="$(awk -F'\t' -v b="$FIRST" '$1==b{s=$4} END{print s}' .swarm/sessions.tsv)"
    [ -n "$PSID" ] || { echo "no session id for parent $FIRST (has it finished?)" >&2; exit 1; }
    PROMPT="You are now an Optimizer on a NEW branch. Follow the instructions in $SKILL_DIR/optimizer.md exactly. $BASE"
    claude -p "$PROMPT" --resume "$PSID" --fork-session --permission-mode "$PERM" --output-format json \
      --max-budget-usd "$BUDGET" "${MODEL_ARGS[@]}" > "$OUT"
    ;;
  *) echo "type must be explorer|optimizer" >&2; exit 1 ;;
esac

SID="$(grep -o '"session_id" *: *"[^"]*"' "$OUT" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
COST="$(grep -o '"total_cost_usd" *: *[0-9.]*' "$OUT" | head -1 | sed 's/.*: *//')"
printf "%s\t%s\t%s\t%s\t%s\n" "$BRANCH" "$TYPE" "$PARENTS" "$SID" "${COST:-?}" >> .swarm/sessions.tsv

echo "DONE $BRANCH ($TYPE from $PARENTS) session=$SID cost=${COST:-?}"
echo "last commit: $(git log -1 --format=%s "$BRANCH")"
