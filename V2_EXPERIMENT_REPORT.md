# V2_EXPERIMENT_REPORT.md

**Track:** Cursor V2.1 (frozen spec)  
**Base:** `d6a4bd7c17a4a559300f93479a8fb8d0d82d384a`  
**Branch:** `cursor/v2-experiment-bbad`  
**Astra:** not inspected  

## Verdict

**READY_FOR_BLIND_REVIEW**

Mac lifecycle, human acceptance, and release signing remain **HOLD / BLOCKED_PENDING_REAL_MAC_EVIDENCE**. They are documented, not faked.

## Stages

| Stage | Gate |
|---|---|
| 0 | `BASELINE_FROZEN` |
| 1 | source lab complete (see per-file classifications) |
| 2 | `ARCHITECTURE_FROZEN` |
| 3–5 | models + identity + recovery + tests authored (`SOURCE_LAYER` / `IDENTITY_LAYER` / `RECOVERY_LAYER` — compile/test NOT RUN on Mac) |
| 6 | ChatGPT/Claude/Grok **adapters only**; Cursor/Gemini **no UI**; Codex **HOLD** |
| 7 | `PASS_WITH_CONDITIONS` |
| 8 | `BLOCKED_PENDING_REAL_MAC_EVIDENCE` |
| 9 | `HOLD` |
| 10 | `HOLD` (no merge/publish) |

## Provider outcomes

| Provider | Outcome |
|---|---|
| ChatGPT | `FALLBACK` (keep wham) |
| Claude | `FALLBACK` (keep web; statusline challenger) |
| Grok | `PASS` (keep current meters) |
| Cursor | `HOLD` |
| Gemini | `HOLD` |
| Codex | `HOLD` |
| Copilot | `REJECT` as product provider |

## Constraints preserved

No Basic Mode, no public-rule estimates, no fabricated resetAt, no major UI redesign, no Cursor/Gemini cards, no merge, no publish.
