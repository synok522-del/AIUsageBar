# GROK_SOURCE_POC.md

**Stage:** 1E

## Current production (challenger baseline = this SHA)

| Meter | Source | Notes |
|---|---|---|
| Short window | `POST https://grok.com/rest/rate-limits` `{"modelName":"grok-3"}` | Cookie from live WebKit grok.com jar, Keychain fallback |
| Weekly (paid) | `POST …/GetGrokCreditsConfig` gRPC-Web | Remaining = 100 − round(clamp(used)); reset = `current_period.end` only |
| UI | One row | Weekly if valid; else short-window |

Frozen facts:

- `credit_usage_percent` is **used** percent, not remaining.
- `billing_period_end ≠ weekly reset`.
- grok-3 must not be labeled Fast without evidence.

## New local/official challenger

No Codex-equivalent local Grok quota RPC was found. xAI consumer usage remains site/session HTTP.

Classification of **new** source: `HOLD` (none viable in this lab).

Classification of **current** source: `PASS_CANDIDATE` (already shipping; account-specific; parse locked by tests on this SHA). Overnight session recovery remains Stage 5 coordinator + existing restorer, not a new usage endpoint.

## vs Usage UI

Not re-verified live. Prior 17F work on this lineage treated SuperGrok Weekly protobuf as the paid weekly meter. No Stage 1 live contradiction.
