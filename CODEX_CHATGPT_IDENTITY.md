# CODEX_CHATGPT_IDENTITY.md

**Stage:** 1C

## Required comparison

Same ChatGPT account, same time:

| Axis | Codex `account/rateLimits/read` | AIUsageBar `backend-api/wham/usage` |
|---|---|---|
| Primary duration | `windowDurationMins` (example docs show **15**) | UI treats `primary_window` as 5-hour |
| Secondary | optional `secondary` | `secondary_window` Weekly |
| used vs remaining | `usedPercent` | remaining = 100 − used_percent |
| resetAt | `resetsAt` unix | `reset_at` (ms or ISO depending on field) |
| Extra meters | reset credits, monthly `individualLimit` | none |

## Live evidence

**NOT_PROVEN.** This host cannot run Codex app-server or ChatGPT wham against a real account.

Documented `windowDurationMins: 15` on Codex primary already **contradicts** treating Codex primary as ChatGPT 5-hour without measurement. V2.1 constraint: do not present estimated/equivalent quotas as real.

## Classification

`NOT_PROVEN`

**Production implication:** ChatGPT stays on current wham source. Codex must not replace ChatGPT meters. Codex may later be an **independent** provider only if a dedicated Codex meter identity is proven — still HOLD until live evidence.
