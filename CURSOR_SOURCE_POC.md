# CURSOR_SOURCE_POC.md

**Stage:** 1F

## Desired fields

remaining/used, reset, account, pool, overage, billing, auth, policy.

## Official consumer quota API

**Not found** as a stable public Cursor quota RPC for third-party menu-bar apps. Cursor Cloud MCP in *this* agent exposes run/environment tools, not “current user remaining Autocomplete/Agent quota.”

## Research-only surfaces (not production)

- Local `state.vscdb` / undocumented IDE RPC: frozen spec allows **research**; productionization requires compliance ≠ UNCLEAR silent PASS.
- Scraping Cursor dashboard cookies: WKWebView tier 5; same overnight/WAF problems; **HOLD** unless CONFIRMED_ALLOWED.

## Classification

`HOLD`

No Cursor UI in Stage 6. Compliance for private DB/RPC: `UNCLEAR` → cannot PASS.

Auth owner would be Cursor itself if an official local/official API appears later.
