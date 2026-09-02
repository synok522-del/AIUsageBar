# Sprint 17F-013 — SuperGrok Weekly RPC Source Discovery

**Date:** 2026-09-02  
**Mode:** READ-ONLY / PROBE discovery  
**GitHub Push to main:** NO  
**Merge:** NO  
**Production Weekly UI:** NOT implemented  
**Classification:** `WEEKLY_RPC_SOURCE_PARTIALLY_IDENTIFIED`  
**Verdict:** `READY_FOR_WEEKLY_LIVE_PROBE`

Live session numbers were **not** fetched in this environment. Do **not** treat this as `LIVE_VERIFIED`.

## Git Boundary

| Item | Value |
|---|---|
| Base Branch | `review/17f-010c-grok-session-self-recovery` |
| Base SHA | `68c505edc44457e8796562b33b04e0fe2edca777` |
| Probe Branch | `probe/17f-013-supergrok-weekly-rpc-discovery` |
| Probe SHA | `d707905e145f685454b531b9492dda7b83710d39` |
| Working Tree | discovery report only; production Grok quota UI unchanged |
| origin/main | `b1fcda95150592dbb28d7790a3126c0d06ff72de` |

17F-012 is evidence only (`/rest/grok/credits` still 404). This branch is **not** based on 17F-012.

## Known Human Ground Truth

| Plan | SuperGrok Lite ACTIVE |
| Used | 53% |
| Remaining | 47% |
| Reset | 2026-09-05 15:11 +08:00 ≈ `2026-09-05T07:11:00Z` |
| Breakdown | Chat 36% · App Builder 16% · Imagine 1% (36+16+1=53) |
| Short Window | `POST /rest/rate-limits` · 2 hours · ~99% remaining · **separate dimension** |

## Frontend Discovery

Fetched 2026-09-02 from `https://grok.com/` (129 initial JS chunks) plus protobuf descriptors in:

- `https://cdn.grok.com/_next/static/chunks/3hookqcngkk7-.js` — generated `@bufbuild` `fileDesc` for `grok_api_v2` / `prod_mc_billing` / `billing_product`
- `https://cdn.grok.com/_next/static/chunks/3148rhw4x45yq.js` — Usage UI + Connect-ES **gRPC-Web** transport (`connect-es/2.1.1`)

The older chunk name `32g78bk5hhe1q.js` is **no longer** the billing bundle (now ~70KB, unrelated).

### Relevant symbols

- `GrokBuildBilling.method.getGrokCreditsConfig`
- `ConsumerUiSvc.method.getRemainingResets`
- `ConsumerUiSvc.method.getPrepaidBenefits`
- `creditUsagePercent`, `productUsage`, `currentPeriod`, `UsagePeriodType.WEEKLY`
- `GROK_CREDITS_LIVE_QUERY_OPTIONS`
- `createQueryOptions(..., {}, {transport})` — **empty request object**

### RPC framework (evidence, not assumed)

**gRPC-Web over protobuf**, implemented by Connect-ES `createGrpcWebTransport` (minified as `$` in `3148rhw4x45yq.js`).

Evidence:

- Request headers: `Content-Type: application/grpc-web+proto`, `X-Grpc-Web: 1`, `X-User-Agent: connect-es/2.1.1`
- 5-byte gRPC-Web envelope (`flags` + big-endian length) wrapping a protobuf payload
- Trailer frame with flag `0x80`
- Fetch options include `{redirect:"error"}` (no Cookie-stealing redirects)
- Default `fetch` credentials = same-origin → **grok.com cookies** (same class as 17F-010C)
- `useBinaryFormat` defaults **true** → binary proto, matching Chrome Hex Viewer

This is **not** Connect protocol (`application/connect+proto`).  
This is **not** the connectors REST JSON proxy (`q` map). `GrokBuildBilling` / `ConsumerUiSvc` are **absent** from that map, so they fall through to gRPC-Web.

ConnectRpcProvider is created as:

```text
("grok-web", "", { useConnectorsRestProxy: true, interceptors: [...] })
```

`baseUrl` is `""`. URL builder:

```js
e.toString().replace(/\/?$/, `/${t.parent.typeName}/${t.name}`)
```

Relative URL on `https://grok.com`:

```text
/{package.Service}/{Method}
```

## RPC Inventory

### GetGrokCreditsConfig

- **Route:** `POST https://grok.com/grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig`
- **HTTP method:** POST
- **Protocol:** gRPC-Web + protobuf (`application/grpc-web+proto`)
- **Service:** `grok_api_v2.GrokBuildBilling`
- **Request:** `grok_api_v2.GetGrokCreditsConfigRequest`
  - `bool exclude_legacy_monthly_usage = 1` (optional)
  - Official UI query uses `{}` → **empty protobuf body**
  - Envelope for empty message: `00 00 00 00 00`
- **Response:** `grok_api_v2.GetGrokCreditsConfigResponse`
  - `GrokCreditsConfig config = 1`
- **Relevant fields (`GrokCreditsConfig`):**
  - `float credit_usage_percent = 1` — aggregate used %
  - `google.protobuf.Timestamp billing_period_start = 4`
  - `google.protobuf.Timestamp billing_period_end = 5` — subscription/billing, **not** the Usage-card weekly reset
  - `repeated ProductUsage product_usage = 7`
  - `UsagePeriod current_period = 8` (`type`, `start`, `end`)
- **ProductUsage:** `billing_product.Product product = 1`, `float usage_percent = 2`
- **Product enum:** CHAT=4, IMAGINE=5, APP_BUILDER=7
- **UsagePeriodType:** UNSPECIFIED=0, MONTHLY=1, WEEKLY=2
- **Confidence:** High for route/schema/UI binding. Live 53/47/reset **not** verified here.

### GetRemainingResets

- **Route:** `POST https://grok.com/prod_mc_billing.ConsumerUiSvc/GetRemainingResets`
- **HTTP method:** POST
- **Protocol:** same gRPC-Web + proto
- **Request:** `prod_mc_billing.ConsumerGetRemainingResetsReq` (empty)
- **Response:** `ConsumerGetRemainingResetsResp` → `repeated ConsumerResetToken tokens = 10`
  - `token_id`, `validity_start`, `validity_end`
- **Relevant fields:** redeemable **reset tokens**, not weekly used %
- **UI:** `settings.usage.reset-redeem-*` (optional extra resets)
- **Confidence:** High that this is **not** the 53%/weekly reset source

### GetPrepaidBenefits

- **Route:** `POST https://grok.com/prod_mc_billing.ConsumerUiSvc/GetPrepaidBenefits`
- **HTTP method:** POST
- **Protocol:** same gRPC-Web + proto
- **Request:** `ConsumerGetPrepaidBenefitsReq` (empty)
- **Response:** `repeated PrepaidBenefit benefits` (id, adjustment, min_ui_amount, end)
- **Feature flag:** `ENABLE_PREPAID_BENEFITS`
- **Relevant fields:** top-up discounts/bonuses, not weekly included usage
- **Confidence:** High that this is **not** the Weekly % source

### Other relevant RPC (not in Kenny’s named Network list)

`ConsumerUiSvc.GetGrokUsageInfo` has a parallel `GrokUsageInfo` (`credit_usage_percent`, `product_usage`, `current_period`). The **Usage page card** binds TanStack Query to **`getGrokCreditsConfig`**, not `getGrokUsageInfo`. Treat GetGrokUsageInfo as a possible duplicate backend, not the observed UI source.

## Weekly Usage Source

- **Method:** `grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig`
- **Field:** `response.config.credit_usage_percent` (float)
- **UI:** `Math.round(creditUsagePercent)` then `"{{value}}% used"`
- **Evidence:** `3148rhw4x45yq.js` select mapper returns `creditUsagePercent: t.creditUsagePercent` from `e.config`; `PH` uses that as `usagePercent`
- **Confidence:** High (static). Live 53% **NOT VERIFIED**

## Weekly Remaining Derivation

The official Usage **included-limit card does not read a remaining field**.

Human 47% is consistent with:

```text
remaining_display ≈ 100 − round(credit_usage_percent)
```

53 used → 47 remaining.

There is a **bar leftover** `Math.max(0, 100 - sum(segment widths))` used only for CSS rounding of the stacked bar, not a second RPC.

**Confidence:** High that remaining is derived, not a separate RPC. Exact rounding vs Kenny’s 47% needs live floats.

## Weekly Reset Source

- **Not** `GetRemainingResets.tokens[*].validity_end`
- **Not** `billing_period_end` for the Usage card date (that field is used on a different SuperGrok billing summary `Pa`)
- **Not** `/rest/rate-limits` 2-hour `resetAt`

Usage card `PH`:

```js
Intl.DateTimeFormat(locale, { dateStyle: "long", timeStyle: "short" }).format(new Date(currentPeriod.end))
```

`usageResetCopy` also uses `currentPeriod.end`.

If `current_period.type === WEEKLY` (enum 2), the label is “Weekly … Limit”.

Human `2026-09-05 15:11 +08` should match `config.current_period.end` as a protobuf Timestamp.

**Confidence:** High for field identity. Live timestamp **NOT VERIFIED**.

## Product Breakdown Source

Same RPC: `config.product_usage[]`.

Labels in `PO`:

| Enum | Value | UI string |
|---|---|---|
| GROK_CHAT | 4 | Chat |
| GROK_APP_BUILDER | 7 | App Builder |
| GROK_IMAGINE | 5 | Imagine |

Display percents: largest-remainder rounding of each `usage_percent` (zeros dropped). They are **not** required to be summed in the UI to produce the headline 53%; the headline is the aggregate field.

## Frontend Calculation

**A (direct aggregate) for the 53% used figure:** `credit_usage_percent`, then `Math.round`.

**Not B as the source of 53%.** Product rows are a separate list. 36+16+1 equaling 53 is consistent with the data but is **not** how the headline is computed.

Remaining 47% is **C**: `100 − displayed used` (or equivalent), not a protobuf field.

## Authentication Requirements

- Same-origin grok.com WebKit cookies (`sso` + CF / session cookies), as in 17F-010C
- No extra CSRF header in the gRPC-Web header builder
- `credentials` default same-origin; REST proxy path uses `credentials:"include"` but billing RPCs do not use that proxy
- `redirect: "error"` — keep 010C off-site Cookie strip
- Empty body is enough; optional `exclude_legacy_monthly_usage` unused by the Usage query
- Browser-only: **no**. Any HTTP client that can send grok.com cookies and gRPC-Web framing can call it
- Account-specific: yes (per-user credits)

Do **not** log Cookie / sso / sso-rw / Authorization / full account payloads.

## Free vs SuperGrok Behavior

Frontend **gates the query**:

- `useIsUsagePoolEnabled` / `useUsagePoolEligible` require SuperGrok Lite/User/Plus/Pro **or** X Premium, plus signed-in non-team user and subscription UI not hidden
- Otherwise TanStack uses `skipToken` — **the RPC is not even called**
- `isGatedOff(config)` can still hide period data after a response

17F-011/012: Free `/rest/grok/credits` 404; SuperGrok Lite still 404 on that REST path. Weekly UI exists only after SuperGrok Lite is active.

**Do not enable Weekly for Free** unless a live Free probe shows a meaningful `GrokCreditsConfig` (unexpected given skipToken).

## Production Feasibility

| Question | Assessment |
|---|---|
| Stable enough for AIUsageBar? | Candidate yes: named service/method in generated descriptors |
| Authenticated with 010C session? | Should be: same cookies, grok.com origin |
| grok.com cookies only? | Yes (no documented bearer for this web path) |
| Protobuf in Swift? | Feasible: small message set; empty request; parse `config` subtree |
| Request body? | Empty proto + 5-byte envelope |
| CSRF? | Not in gRPC-Web header helper |
| Special headers? | `Content-Type: application/grpc-web+proto`, `X-Grpc-Web: 1` |
| Redirects? | Transport uses `redirect: "error"` |
| Compression? | Client throws if compressed output flag set |
| Browser-only? | No |
| Account-specific? | Yes |
| Free-account RPC behavior | Unknown live; UI skips the call |

`/rest/rate-limits` stays the **short window** source.

`/rest/grok/credits` stays **not** the Weekly source.

## Security Review

- No secrets in this report
- No cookie jar persistence
- No Cloudflare bypass
- No production Grok UI / notification / menu-bar Weekly
- Probe branch must not merge to `main`

## Remaining Live Verification

Only Kenny’s Mac / SuperGrok Lite session:

1. While Usage shows ~53/47/reset/breakdown, capture **one** `GetGrokCreditsConfig` (status, content-type, **no** cookie dump).
2. Decode `config.credit_usage_percent`, `current_period.{type,end}`, `product_usage` for CHAT / APP_BUILDER / IMAGINE.
3. Confirm approximate match to the official UI (usage may move after the screenshot).
4. Optionally confirm Free still does not call this RPC / returns empty or gated config.
5. Confirm `/rest/rate-limits` still reports the 2-hour window independently.

### Minimal live request (empty unary)

```http
POST /grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig HTTP/1.1
Host: grok.com
Content-Type: application/grpc-web+proto
X-Grpc-Web: 1
Cookie: <in-memory grok.com cookies only>
```

Body: 5 bytes `00 00 00 00 00`

Log only semantic floats/timestamps/enums.

## Classification

`WEEKLY_RPC_SOURCE_PARTIALLY_IDENTIFIED`

Route, protocol, request, and UI field mapping are identified from **current** frontend descriptors. Official 53/47/reset/breakdown are **not** live-reconciled in this run.

## Final Verdict

`READY_FOR_WEEKLY_LIVE_PROBE`

One focused human probe of `GetGrokCreditsConfig` is enough to accept or reject this source. Do not reverse-engineer unrelated Grok features next.
