# CLAUDE_STATUSLINE_POC.md

**Stage:** 1D

## Official local quota state (PUSH)

Claude Code statusline scripts receive JSON on stdin. Official docs (`code.claude.com/docs/en/statusline`) include:

```json
"rate_limits": {
  "five_hour": { "used_percentage": 23.5, "resets_at": 1738425600 },
  "seven_day": { "used_percentage": 41.2, "resets_at": 1738857600 }
}
```

- `used_percentage` 0–100 consumed
- `resets_at` Unix **seconds**
- `rate_limits` **may be absent** (non-subscribers, or before first API response). Each window independently optional.
- **Missing `rate_limits` ≠ auth failure** (frozen V2.1 constraint)

## Bridge design (not implemented in Stage 1)

- Opt-in: user points Claude Code `statusLine.command` at a small local listener AIUsageBar exposes, **or** a user-visible “paste/pipe” is rejected (no manual estimate mode).
- Reversible: removing the statusline command restores Claude Code default; AIUsageBar falls back to existing `sessionKey` + `claude.ai` usage HTTP.
- Timing: updates only when Claude Code runs a turn — overnight idle without Claude Code → STALE_BUT_VALID then EXPIRED, not fabricated refresh.

## vs current production

Current: `GET /api/organizations/{id}/usage` with `five_hour` / `seven_day` **utilization**. Same semantic windows; different transport and freshness.

## Classification

`FALLBACK_CANDIDATE` — official fields exist, but PUSH/opt-in/absent-fields and “Claude Code must be running” make it unsuitable as the **only** source.

Web session usage remains the production fallback.

Compliance: **LIKELY_ALLOWED** for consuming user-configured statusline output. **DISALLOWED** default-reading Claude Code OAuth files.
