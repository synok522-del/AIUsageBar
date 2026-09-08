# S01C — ChatGPT web vs Codex rateLimits equivalence

**Sprint:** S01C (Cursor V2 lab)  
**Track:** Cursor V2  
**Helper:** `ChatGPTCodexEquivalence` (pure, in-memory; not wired to UI or `ChatGPTService`)

## Verdict

**`NOT_PROVEN`**

## Why live evidence is missing

This environment has no same-account capture of ChatGPT `wham/usage` together with Codex `account/rateLimits/read` (T-1C-L1). No live JSON was invented. `S01C-live-capture.json` is **absent**.

The helper therefore defaults to `NOT_PROVEN` when live evidence is absent (T-1C-08). Similar remaining percentages are **not** treated as proof. A single candidate-equivalent pair is **never** auto-`PROVEN_EQUIVALENT` (T-1C-06).

## What would be required later

| ID | Evidence |
|---|---|
| T-1C-L1 | Same-account ChatGPT `wham/usage` and Codex `rateLimits` captured together, at least two consistent samples, remaining within 1 point, `resetAt` within 120s, same accountKey, overlapping window class, matching meter presence |
| T-1C-L2 | This file updated only after that capture exists |

Until then, ChatGPT production stays on Keychain cookie → session → `wham/usage`. Do not migrate.

## Candidate predicate (not a lab verdict)

All of the following are required for a *candidate* equivalent pair:

- same `accountKey`
- overlapping window class (`short` ↔ V1 `primary_window` / Codex `codex.primary_window`; `weekly` ↔ V1 `secondary_window` / Codex `codex.secondary_window`)
- remaining within 1 percentage point
- `resetAt` within 120 seconds
- neither side missing a meter the other has (snapshot compare)

Failing any of these is not equivalent. Conflicting multi-sample sets can be `PROVEN_DIFFERENT` without promoting this file.
