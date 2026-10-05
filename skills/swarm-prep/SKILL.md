---
name: swarm-prep
description: Interview the user about an optimization/discovery problem and turn it into a swarm-ready repo for the swarm-research skill — prompt.md, a trustworthy evaluator that prints one score, a working baseline, a holdout check against score-gaming, and .swarm/config.md. Use when the user says "swarm-prep", "prépare un swarm", "prépare le problème pour le swarm", or states a problem they want to hand to swarm-research.
---

# Swarm Prep — make the problem swarm-ready

The swarm is only as good as its **evaluator** and its **prompt.md**. 25 agents will optimize exactly what the score measures, including its loopholes. Your job: interrogate the problem until it is precise, then build the files and *verify* them. Do not launch the swarm here; hand off to `swarm-research` at the end.

Talk to the user in their language (French by default). Write generated files in English unless the user prefers otherwise (agents perform best in English).

## Rules for the interview
- Ask with **AskUserQuestion** (≤4 questions per call, 2–4 options each, recommended option first labelled "(Recommandé)"). The user can always answer "Other" freely.
- Before asking anything, **look**: if a repo/folder is given, read it (existing code, tests, benchmarks) and pre-fill answers. Never ask what you can find out yourself.
- Propose concrete defaults instead of open questions. Group questions by round; 4–6 rounds max.
- After each round, restate in 2–3 lines what is now fixed, then continue.
- If the problem is **not swarm-suitable**, say so and stop (see Round 0).

## Round 0 — Problem statement & suitability
Ask the user to describe the problem in free text if they haven't. Then check, and tell the user plainly:
- Is there a **numeric score** that can be computed automatically? (No → help define one, or stop: swarms don't fit taste-only problems.)
- Is it **open-ended** (many possible approaches)? If there is one obvious correct answer, a single agent is better.
- Can one evaluation run in **< ~5 min**? Agents evaluate many times; slow evals kill the swarm → plan a fast proxy eval + a full eval for final review.

## Round 1 — Objective & metric
- What exactly is measured (time, accuracy, cost, quality score, size…)? Higher or lower is better?
- Single metric, or combination? If several: propose a weighted score OR primary metric + hard thresholds on the others (e.g. "maximize speed, accuracy must stay ≥ 0.95 else score = 0"). Hard thresholds beat weights.
- Noise: is the measure stable? If not → average N runs, fixed seeds, report mean.
- What score would count as success / a great result?

## Round 2 — Evaluator & anti-gaming
- Does an evaluator already exist? If not, which inputs/datasets/test cases does it use?
- **Holdout**: split the cases into `eval/public` (agents see and use) and `eval/holdout` (kept out of the repo given to agents, e.g. `../<repo>-holdout/` or a git-ignored folder) used only by the Shepherd for final review. Recommend it by default.
- Correctness checks the score must enforce (valid output format, constraint satisfaction, same results as reference…). An invalid solution must get the worst score, not a crash.
- Loopholes to close: hard-coding outputs for known cases, caching across runs, editing the evaluator, reading the holdout, using forbidden libraries, changing hardware settings. List them in prompt.md as forbidden.
- Output contract: the evaluator prints exactly one line `score=<number>` last (plus optional details above).

## Round 3 — Constraints & solution space
- Language/runtime, what files agents may edit (e.g. only `solution/`), dependencies allowed (pip install ok?), internet allowed?, hardware (CPU/GPU, cores), time/memory limits per run.
- Known approaches the user already tried or knows. **These go in prompt.md as background facts only — never as instructions** (the swarm must find its own ideas). Ask if any should be explicitly ruled out.
- Is there a reference paper/repo/state of the art score to mention?

## Round 4 — Baseline
- Existing working solution? Otherwise build the **simplest correct** baseline (not a good one — the swarm improves it).
- It must pass the evaluator's validity checks.

## Round 5 — Swarm settings
Propose defaults, user confirms:
- **Explorer budget**: 25 (paper). Smaller test run: 8–10 recommended for a first try.
- **Max concurrent agents**: with a Claude subscription (Pro/Max) the limit is usage/rate limits, not dollars → recommend 2–3 concurrent; 4–6 only on Max with headroom. Note that a swarm can consume a large part of the weekly quota.
- **Per-agent cap** `SWARM_BUDGET_USD`: keep a value (e.g. 5) as a runaway guard even on subscription.
- **Model** (`SWARM_MODEL`): default = user's default model; optionally a cheaper model for Explorers.
- Stopping: budget exhausted, target score reached, or wall-clock limit.

## Build phase (after the interview)
Show a short summary of all decisions and get one explicit "ok". Then, in the target repo:
1. `prompt.md` with sections: **Problem**, **Score** (formula, direction, validity rules, how to run: exact command), **Constraints** (editable files, deps, hardware, limits), **Forbidden** (evaluator edits, hard-coding, holdout access, …), **Background** (facts, prior attempts, SOTA — no prescriptions), **Deliverable** (where the solution lives).
2. Evaluator script (e.g. `eval/run.py` or `eval.sh`) + public cases; holdout cases outside agents' reach + `eval/holdout_cmd.md` noting how the Shepherd runs it.
3. Baseline solution.
4. `.swarm/config.md`: explorer budget, concurrency, per-agent cap, model, target score, stop conditions, eval commands (public + holdout), baseline score.
5. Run `bash ~/.claude/skills/swarm-research/scripts/init.sh` at the repo root.

## Verification (mandatory before hand-off)
- Run the evaluator on the baseline **twice**: it prints `score=…`, scores are stable (or noise is documented).
- Run it on a deliberately broken solution (wrong output / crash): it must give the worst score, not crash or reward it.
- Time one eval run; record it in config.md. If > 5 min, build a faster proxy now.
- Run the holdout eval on the baseline; record its score.
- Commit on `main`: `baseline | score=<x>`.
- Check that `~/.claude/skills/swarm-research/scripts/spawn.sh` exists; if not, tell the user it must be created before launching.

## Hand-off
Tell the user in 3–4 lines: baseline score, eval time, settings, and the next step: « lance swarm-research » in this repo.
