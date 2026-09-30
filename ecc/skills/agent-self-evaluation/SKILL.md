---
name: agent-self-evaluation
description: Use after completing any non-trivial task. The agent self-rates its output on 5
origin: ECC
---

# Agent Self-Evaluation

After completing a complex task, the agent pauses to rate its own output against a structured 5-axis rubric. This is NOT a pass/fail gate — it's a deliberate reflection step that catches omissions, flags overconfidence, and surfaces areas for improvement before the user has to.

## When to Activate

- After writing code that spans 3+ files or 50+ lines
- After completing a multi-step workflow (implement → test → review)
- After a debugging session that involved 3+ attempts
- After producing a design document, architecture decision, or written analysis
- When the user asks "how good was that?" or "rate yourself"

## The 5 Evaluation Axes

| Axis | Question | What it catches |
|---|---|---|
| **Accuracy** | Are the facts, claims, and outputs correct? | Hallucinations, wrong API names, incorrect syntax |
| **Completeness** | Did it cover everything the user asked for? | Missed edge cases, unhandled error paths, forgotten requirements |
| **Clarity** | Is the explanation understandable and well-structured? | Confusing explanations, jargon without definition, rambling |
| **Actionability** | Can the user act on the output immediately? | Vague suggestions, missing steps, no verification path |
| **Conciseness** | Did it use the minimum words/tokens needed? | Redundancy, over-explanation, filler content |

## Scoring Scale

```
5 — Exceptional: no reasonable improvement possible
4 — Good: minor nits only, no substantive gaps
3 — Adequate: meets the request but has a notable weakness on at least one axis
2 — Weak: has a clear gap that affects usability or correctness
1 — Poor: fundamentally misses the request or contains significant errors
```

**The Evidence Rule:** Every score below 5 MUST cite specific evidence. A score of 3 cannot just say "could be better" — it must say exactly what is missing or wrong. **"Show the gap, don't just name it."**

## Workflow

### Step 1: Collect the Raw Material
- The original user request
- Your final response/output
- Any tool outputs that verify correctness (test results, lint output)
- Any user feedback received during the task

### Step 2: Score Each Axis Independently
For each axis: read the question, find evidence, assign 1-5, cite gap if < 5. Do NOT average first then work backwards.

### Step 3: Produce the Evaluation Report

```
- One-line summary
- 5-axis scorecard (score + evidence per axis)
- Overall score (simple average, rounded to 1 decimal)
- 1-3 specific improvements ranked by impact
- Self-check: "Would the user agree with this assessment?"
```

### Step 4: Apply the Improvement
If any axis scored 3 or below: state what you would do differently. If fixable in < 30 seconds, fix it now. If rework needed, flag it explicitly.

## Example: Good Scorecard (4+)

```
Task: Add retry logic to HTTP client

Accuracy:    5 — All API calls correct. Verified: retries use exponential backoff.
Completeness: 4 — Covered happy path + 3 error cases. Missing: timeout handling.
Clarity:      5 — Code comments explain backoff formula.
Actionability:5 — Single merge. No follow-up tasks. Tests pass.
Conciseness:  4 — 47 lines. Retry loop could be extracted to drop ~8 lines.

Overall: 4.6 — One gap (timeout handling). Fix before merging.
```

## Example: Weak Scorecard (2-3)

```
Task: Add retry logic to HTTP client

Accuracy:    2 — Used urllib3 instead of httpx (wrong library for codebase).
Completeness: 3 — Works for GET. POST/PUT not handled.
Clarity:      4 — Code is readable. Good variable names.
Actionability:2 — "Add tests" mentioned but no test file created.
Conciseness:  3 — 120 lines. Config duplicated in 3 places.

Overall: 2.8 — Wrong library used. Needs httpx rewrite.
```

## Anti-Patterns

- **"Everything is a 5"** without evidence cited = self-congratulation, not evaluation
- **Over-penalizing scope creep** — only evaluate what user actually requested
- **Using evaluation to re-litigate** — this is about delivered output, not re-arguing design decisions
- **Mixing personal preference with objective gaps** — "don't like" is not evidence

## Best Practices

- Evaluate the **output**, not the process
- One improvement per weak axis (don't list 5 for one axis)
- Tie improvements to **user impact**
- Be specific about what 'fixed' looks like
- Use tool outputs as evidence (cite test results, lint output)
- If all 5 axes are 5, try harder — perfect scores are rare

## Related Skills

- `agent-eval` — Head-to-head comparison of coding agents
- `verification-loop` — Systematic verification of outputs
- `security-review` — Security-focused code review checklist
