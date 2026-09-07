# V2_ARCHITECTURE_DECISION.md

**Stage:** 2 — Architecture Decision Freeze  
**Gate:** `ARCHITECTURE_FROZEN`  
**Based on:** Stage 0 baseline + Stage 1 lab (this experiment). Astra ignored.

---

## 1. Per-provider production decision

| Provider | Production source | Fallback | UI in V2.1 | Outcome |
|---|---|---|---|---|
| ChatGPT | Current `session` + `wham/usage` | none until Codex 1C `PROVEN_EQUIVALENT` | keep existing | `FALLBACK` (keep working unofficial HTTPS; Codex not proven equivalent) |
| Codex | — | — | **no** | `HOLD` (independent meter unproven) |
| Claude | Current `claude.ai` org usage | statusline PUSH opt-in later | keep existing | `FALLBACK` (web remains; statusline is challenger) |
| Grok | Current rate-limits + GetGrokCreditsConfig | none better | keep existing | `PASS` (shipping official-enough site APIs already in product) |
| Cursor | — | — | **no** | `HOLD` |
| Gemini Apps | — | — | **no** | `HOLD` |
| Gemini CLI | — | — | **no** | `HOLD` (≠ Apps) |
| Copilot | — | — | **no** | `REJECT` as product provider |

HOLD/REJECT does **not** fail V2.1.

---

## 2. Account / meter identity

```
cacheKey = provider + accountKey + meterId + window
```

- `accountKey`: opaque; ChatGPT = session-token fingerprint (hash, never raw); Claude = organization id; Grok = sso fingerprint. If unavailable → do not reuse another account’s cache (`accountKey unavailable` rule).
- `meterId`: stable string (`chatgpt.primary_window`, `claude.five_hour`, `grok.short`, `grok.weekly`, …).
- `window`: semantic enum, **not** primary==short.

Frozen windows used in V2 models:

`rolling5Hour`, `rolling7Day`, `rollingCustom`, `weekly`, `monthly`, `billingCycle`, `unknown`

---

## 3. Validity vs freshness

| State | Meaning |
|---|---|
| `FRESH` | Successful fetch in the last `freshnessTTL` (default **120s**) |
| `STALE_BUT_VALID` | Last success older than TTL but `asOf` still before `expiresAt` (or no expiry) **and** identity unchanged |
| `EXPIRED` | `expiresAt` passed **or** age > `expiredTTL` (default **6h**) |
| `INVALID` | Parse failure, identity mismatch, or policy forbids display |

Missing field: omit that meter; do **not** treat as 401.

---

## 4. Notification meter selection (frozen)

- Notify only the **currently displayed PRIMARY meter** for that provider (today: ChatGPT/Claude/Grok session/short remaining %, not a newly discovered weekly meter).
- Once per `provider+accountKey+meterId+window` while remaining ≤ 20% after crossing from above.
- Account switch must reset that identity (no inherited notified flag).

---

## 5. Recovery / backoff / circuit breaker (frozen parameters)

States: `HEALTHY` → `RECOVERING` → `BACKOFF` → `REQUIRES_USER_ACTION`

| Parameter | Value |
|---|---|
| Scope | `provider + accountKey` |
| Max concurrent recoveries | 1 per scope |
| Restore attempts per fetch failure | **1** |
| Retry fetches after restore | **1** |
| Cooldown after failed recovery | **15s** (`BACKOFF`) |
| Circuit: failures in **10 min** | **3** → latch `REQUIRES_USER_ACTION` |
| Timer hidden login | **forbidden** |
| Success | **fresh usage request + valid parse + identity when available** — not cookie presence, not WK READY |
| Logout / account replace | invalidate generation; drop in-flight |

---

## 6. Local access / compliance / distribution

- Do not read foreign CLI credential files.
- Codex app-server / Claude statusline: opt-in local IPC only after Stage 6 authorization (not in this freeze for production ChatGPT/Claude).
- Distribution remains direct Developer ID; Sandbox stays off unless a later stage reopens MAS.
- Compliance UNCLEAR → HOLD, never silent PASS.

---

## 7. Mechanically testable definitions

1. **Reliable source:** returns `UsageSnapshot` with ≥1 meter, `accountKey` or explicit `accountKeyUnavailable`, no fabricated `resetAt`.
2. **Same-meter equivalence:** same `provider+accountKey+meterId+window` remaining within **2** percentage points **and** reset within **5 min**, measured same minute — required before replacing a source.
3. **STALE_BUT_VALID / EXPIRED:** as §3.
4. **Missing field:** meter omitted; snapshot may still be FRESH.
5. **accountKey unavailable:** cache miss; no cross-account reuse.
6. **Lifecycle evidence:** Mac-only for overnight/sleep; Linux must record `NOT_RUN` not PASS.

---

## 8. Stage 6 migration authorization

Implement **adapters** over **existing** ChatGPT/Claude/Grok fetchers so the source layer is real, without changing endpoints or visual language. Do **not** add Cursor/Gemini cards.

---

**Gate:** `PASS` / `ARCHITECTURE_FROZEN`
