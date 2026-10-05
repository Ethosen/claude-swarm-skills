---
name: swarm-research
description: SwarmResearch (arXiv 2607.02807) — orchestrate a swarm of Claude Code agents on an open-ended optimization problem with a measurable score. You act as the Shepherd: spawn fresh-context Explorers and session-forking Optimizers, each in its own git branch/worktree, keep a global ledger, maintain diversity of high-level approaches, and adapt parallelism per depth. Use when the user says "swarm research", "swarmresearch", "shepherd", "lance un swarm", or wants autoresearch-style long-running discovery (speed up code, improve a heuristic, beat a benchmark score) without converging on a single idea.
---

# SwarmResearch — you are the Shepherd

Technique from *SwarmResearch: Orchestrating Coding Agents for Open-Ended Discovery* (Virk, Edds, Xia, Zhang — arXiv 2607.02807).
Single long-running agents converge on one high-level approach then only tweak it. SwarmResearch fixes this with:

- **Shepherd** (you): global context, steers the search. **Never writes solution code. Never prescribes ideas.**
- **Search Agents**: headless `claude -p` processes, each on its own branch in `.worktrees/<branch>`, seeing only local context.
  - **Explorer** — fresh context window, implements ONE fundamentally new idea. See [explorer.md](explorer.md).
  - **Optimizer** — forks its parent's session (inherits full conversation), refines that lineage. See [optimizer.md](optimizer.md).
- Steering levers (the ONLY three): **which parent branch**, **which agent type**, **minimal context in the prompt**.

## Phase 0 — Setup (confirm with the user before spending money)

The target repo needs, on `main`:
1. `prompt.md` — problem statement, constraints, what is forbidden (e.g. editing the evaluator), how to run the eval.
2. An **evaluator** command that prints a single numeric score (state if higher or lower is better). Deterministic or averaged; must not be editable by agents (mention it in prompt.md).
3. A **minimal working baseline** solution that the evaluator scores.

If any is missing, or `.swarm/config.md` doesn't exist yet, run the **swarm-prep** skill first (it interviews the user and builds all of this, with an anti-gaming holdout). If `.swarm/config.md` exists, read it and use its settings instead of asking again. Then:
```bash
bash ~/.claude/skills/swarm-research/scripts/init.sh   # run at repo root: git init if needed, .gitignore, .swarm/
```
Agree with the user on: **Explorer budget** (paper default: 25), **$ cap per agent** (`--max-budget-usd`, e.g. 2–3), **max concurrent agents** (e.g. 4–6), model. Write them to `.swarm/config.md`.

> Agents run with `--permission-mode bypassPermissions` (as in the paper) so they can run the evaluator unattended. Tell the user this and that each agent is confined by instructions (not sandbox) to its worktree. If they refuse, use `acceptEdits` + `--allowedTools` for the eval command instead (edit `scripts/spawn.sh`).

## Phase 1 — Spawning

All agents launch from the **repo root** (so `--resume` finds parent sessions) and are told to work only in their worktree.
Run every spawn with the Bash tool and `run_in_background: true` — you are notified when each finishes.

```bash
# Explorer from scratch, or from a parent branch, or multi-parent (comma list → git merge --no-commit)
bash ~/.claude/skills/swarm-research/scripts/spawn.sh explorer r-07 main "<minimal context or empty>"
bash ~/.claude/skills/swarm-research/scripts/spawn.sh explorer r-12 r-03 "<context>"
bash ~/.claude/skills/swarm-research/scripts/spawn.sh explorer r-15 r-03,r-09 "<context>"
# Optimizer: forks the parent's session (parent must have finished)
bash ~/.claude/skills/swarm-research/scripts/spawn.sh optimizer r-13 r-07 "<context>"
```
Branch names: `r-NN`, never reused. Result JSON lands in `.swarm/runs/<branch>.json` (has `session_id`, `result`, `total_cost_usd`); the script appends the session id to `.swarm/sessions.tsv`.

## Phase 2 — The ledger (your global context, nobody else sees it)

After each agent finishes, read its JSON + the last commit on its branch (`git log -1 --format=%s r-NN` → `"<desc> | score=<x>"`) and append one row to `.swarm/ledger.md`:

| branch | type | parent | family | idea (1 line) | score | status |

**family** = the high-level approach (you name it: e.g. "greedy+local search", "DP", "SIMD batching"). Families are what you manage, not individual branches. Also keep a short "Families" section: strengths, weaknesses, best score, last improvement time.

## Phase 3 — Adaptive scaling policy

You are near-greedy by default (the paper found this explicitly). Fight it.

1. **Wide start**: spend ~30–40% of the Explorer budget on a diverse initial population from `main`, launched in **small batches** (2–4) rather than all at once.
2. **Deepen promising families serially**: chains of Optimizers / Explorers on the top 2–3 families, *including under-developed ones*, not only the current best.
3. **Fan-out on plateaus**: when a family stops improving (≈2 consecutive non-improving children), stop deepening it. Spawn fresh Explorers from diverse parents (`main`, other families, multi-parent merges) with plateau context.
4. **Late phase**: concentrate remaining budget on refining the best 1–2 families with Optimizers.
5. Vary width per depth; never use a fixed n×k grid. Keep ≥2 alive families until the final quarter of the budget.
6. Stop when the Explorer budget is spent (Optimizers are cheap extras, still respect the $ cap) or the user says stop.

## Phase 4 — How to write the context (most important rule)

**Do not suggest or instruct what idea to pursue. Give only context that helps them decide on their own.** You may say what NOT to re-explore.

- GOOD: "Your parent scored 0.78, strong on typical cases and speed, but still violates hard constraints on edge cases. Another family reached 0.79 by improving constraint satisfaction, but is less accurate on ordinary cases."
- GOOD (plateau): "Families so far: A (greedy, 0.81, fast, weak on large n), B (DP, 0.79, exact but memory-bound). Both plateaued. Do not re-explore variants of A or B; look for a technique that addresses their limitations."
- BAD: "Implement beam search with a learned scorer and tune beam width in [8,16,32]."

Explorers from `main` often get **no context at all** — that maximizes diversity in the initial population.

## Phase 5 — Report

At the end (or on request): best branch + score, the family tree (ledger), total cost (sum of `total_cost_usd`), what failed and why (from `findings.md` files). Offer to merge the winning branch into a result branch. **Review the winning diff yourself** for evaluator gaming (hard-coded outputs, edited eval files, constraint violations) before declaring a win — the paper notes careful review is costly but necessary.

Cleanup when the user approves: `git worktree prune`, remove `.worktrees/` entries of dead branches. Never delete branches without asking.

## Gotchas
- Never let a Search Agent see `.swarm/ledger.md` or other lineages — shared global memory causes "self-organized collapse" (all agents converge). Only `findings.md` travels along a lineage.
- An Optimizer needs its parent to have **finished** (session must exist). Resume only works because everything launches from repo root.
- Watch total spend; the paper used ~$50/task with 25 Explorers.
- Windows: scripts are POSIX — run them through the Bash tool (Git Bash).
