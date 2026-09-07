# CODEX_APP_SERVER_POC.md

**Stage:** 1B  
**Live spawn of `codex app-server`:** NOT RUN (binary absent).

## Official local interface (documented)

Transport: `codex app-server --stdio` (JSONL JSON-RPC). Clients must `initialize` then:

- `account/read` — account identity (do not persist/print email/tokens)
- `account/rateLimits/read` — ChatGPT/Codex rate limit snapshot
- notify `account/rateLimits/updated` — sparse merge; refetch snapshot for authority

Source: OpenAI `codex-rs/app-server/README.md` (fetched 2026-09-07).

## Documented snapshot shape (example)

```json
{
  "ordinaryUsageAllowed": true,
  "rateLimits": {
    "primary": { "usedPercent": 25, "windowDurationMins": 15, "resetsAt": 1730947200 },
    "secondary": null,
    "rateLimitReachedType": null
  },
  "rateLimitResetCredits": { "availableCount": 2, "credits": [] }
}
```

| Field | Meaning |
|---|---|
| `usedPercent` | used % in that window (not remaining) |
| `windowDurationMins` | window length (primary is **not** assumed 5h) |
| `resetsAt` | Unix seconds — do not fabricate |
| `accountId` | optional identity |
| `individualLimit` | optional monthly credits; null = unavailable |
| `rateLimitResetCredits` | Codex-specific earned resets — **not** a ChatGPT wham meter |

## Auth / errors / health

- Auth owner: **Codex CLI** (existing ChatGPT login inside Codex). AIUsageBar must not read Codex access tokens.
- Unauthenticated / CLI missing → source health `UNAVAILABLE`, not a fake 0% quota.
- Compliance: **LIKELY_ALLOWED** for consuming local app-server RPC the user already authorized via Codex. **DISALLOWED** to scrape `~/.codex` credentials.

## Classification (source lab)

`PASS_CANDIDATE` as a **Codex/ChatGPT-adjacent official local quota interface**, pending live initialize+read on a Mac with Codex logged in.

`NOT_VERIFIED` live schema against this environment.

Do **not** migrate production ChatGPT off `wham/usage` until Stage 1C is `PROVEN_EQUIVALENT`.
