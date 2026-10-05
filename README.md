# claude-swarm-skills

Two [Claude Code](https://claude.com/claude-code) skills that turn Claude into a **research swarm** for open-ended optimization problems, based on the paper
[*SwarmResearch: Orchestrating Coding Agents for Open-Ended Discovery*](https://arxiv.org/abs/2607.02807) (Virk, Edds, Xia, Zhang, 2026).

| Skill | What it does |
|---|---|
| [`swarm-prep`](skills/swarm-prep/SKILL.md) | Interviews you about your problem and builds a swarm-ready repo: `prompt.md`, an evaluator that prints one score, a baseline, a hidden holdout set against score-gaming, and swarm settings. |
| [`swarm-research`](skills/swarm-research/SKILL.md) | Claude becomes the **Shepherd**: it launches and steers many headless Claude Code agents, each on its own git branch, and keeps exploring different high-level approaches until the budget is spent. |

## Why

Long-running coding agents (autoresearch-style) improve a score for hours, but they tend to **lock onto one high-level idea** and spend the rest of the time on small tweaks. Better approaches never get tried.

SwarmResearch fixes this through how the work is organized:

- **Shepherd** (orchestrator): sees a global ledger of every attempt and its score, groups attempts into *families* of approaches, and decides where to search next. It never writes solution code and **never tells agents which idea to try**. It only picks a parent branch and an agent type, and gives minimal context.
- **Explorers**: start with a fresh context window and implement **one fundamentally new idea** on their own branch.
- **Optimizers**: fork their parent agent's full session and refine that lineage.
- **Isolation**: each agent works in its own `git worktree` and only sees its own lineage's `findings.md`. Sharing global memory makes all agents converge on the same idea ("self-organized collapse").
- **Adaptive scaling**: starts wide, goes deep on promising families, fans out with fresh Explorers when a family plateaus. There is no fixed n×k grid to tune.

In the paper, this matched or beat state-of-the-art LLM-guided evolution and multi-agent methods on 13 of 15 tasks (math, systems, competitive heuristics), with about 7.7% orchestration overhead.

## Good fits

Any problem with an **automatic numeric score** and **many possible approaches**:
- making code faster (kernels, inference, decoding, compilers)
- heuristics and optimization (scheduling, routing, packing, contest problems)
- improving a metric on a fixed benchmark

Not a good fit: tasks with one obvious answer, or quality you can only judge by eye.

## Install

```bash
git clone https://github.com/Ethosen/claude-swarm-skills
cp -r claude-swarm-skills/skills/* ~/.claude/skills/
```

Search agents run headless with `--permission-mode bypassPermissions`, as in the paper, so they can run the evaluator unattended. To let the Shepherd launch them, add this rule to `~/.claude/settings.json`:

```json
"permissions": { "allow": ["Bash(bash ~/.claude/skills/swarm-research/scripts/spawn.sh:*)"] }
```

> ⚠️ Bypass mode means agents can run **any command without asking you**. Only an instruction keeps them inside their worktree; nothing enforces it. Run swarms on a disposable machine, VM or container, never on a repo or machine holding secrets. You can set `SWARM_PERMISSION=acceptEdits` and edit `spawn.sh` to add `--allowedTools` for a safer setup.

Requirements: Claude Code CLI (`claude`), git, bash (Git Bash on Windows).

## Usage

1. In your project folder: `/swarm-prep`, then describe your problem. Answer the questions and confirm the plan. It builds and checks the evaluator and the baseline.
2. Then: "run swarm-research" (or `/swarm-research`). The Shepherd launches agents, keeps `.swarm/ledger.md` up to date and reports the best branch at the end.

Settings (in `.swarm/config.md` or as env vars):

| Variable | Default | Meaning |
|---|---|---|
| Explorer budget | 25 (try 8–10 first) | number of Explorer agents |
| Concurrency | 2–3 | agents in parallel (on a Pro/Max subscription, usage limits are the real constraint) |
| `SWARM_BUDGET_USD` | 3 | per-agent spend cap, a guard against runaway agents |
| `SWARM_MODEL` | your default | model used by search agents |
| `SWARM_PERMISSION` | `bypassPermissions` | permission mode used by search agents |

## Layout

```
skills/
  swarm-prep/SKILL.md          interview + build + verify
  swarm-research/
    SKILL.md                   Shepherd playbook
    explorer.md                instructions given to Explorers
    optimizer.md               instructions given to Optimizers
    scripts/init.sh            prepares the repo (.swarm/, .gitignore)
    scripts/spawn.sh           creates branch + worktree, launches `claude -p`
```

## Credits

The technique comes from Yuvraj Virk, Zack Edds, Chunqiu Steven Xia and Lingming Zhang, [arXiv:2607.02807](https://arxiv.org/abs/2607.02807). This repo is an independent implementation as Claude Code skills and is not affiliated with the authors or with Anthropic.

## License

MIT
