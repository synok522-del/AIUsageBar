# COPILOT_REFERENCE.md

**Stage:** 1H — architecture benchmark only. **No Copilot UI.**

## Official documented API

GitHub REST **Copilot usage metrics** are **enterprise/org historical reports**, not a personal remaining-quota badge. Requires enterprise policy enablement. Not a consumer meter for AIUsageBar.

## What the official Copilot UI uses (research)

Unofficial `GET https://api.github.com/copilot_internal/user` returns `quota_snapshots` (chat / completions / premium_interactions) with `percent_remaining`, `entitlement`, `quota_reset_date`. This is **internal**, reverse-engineered from the VS Code extension.

Compliance: `LIKELY_DISALLOWED` / `UNCLEAR` for shipping in AIUsageBar. Frozen spec: private/RE credential reuse is **research only; not production just because it works**.

## Architecture lessons (allowed)

- Separate **meters** (chat vs completions vs premium) — maps to `UsageMeter` + `meterId`.
- `percent_remaining` vs used %.
- Monthly `quota_reset_date` as `billingCycle` / `monthly` window — not “primary=short”.
- `unlimited: true` must not be rendered as 0% remaining.
- Account identity = GitHub user, not “Copilot is logged in”.

## Classification

Reference only. `REJECT` as a V2.1 production provider without a separate authorized official personal quota API.
