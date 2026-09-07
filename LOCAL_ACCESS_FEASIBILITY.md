# LOCAL_ACCESS_FEASIBILITY.md

**Stage:** 1A  
**Environment:** Linux Cursor Cloud (`HOME=/home/ubuntu`). Not a signed macOS Developer ID build.

## Classification

`VIABLE_WITH_USER_AUTHORIZATION` for a **future Mac Developer ID** build reading user-authorized local CLI state.  
`NOT_VERIFIED` on this experiment host (no `~/.codex`, `~/.claude`, `~/.gemini`; no `codex`/`claude`/`gemini` binaries).  
`NOT_VIABLE` for **Mac App Store** as currently configured: App Sandbox is **disabled**, distribution is direct Developer ID (README). MAS would require sandbox + security-scoped bookmarks and is out of V2.1 productionization unless Stage 2 reopens distribution.

## Evidence

| Check | Result |
|---|---|
| Developer ID signing | NOT_VERIFIED (Linux; entitlements file empty) |
| App Sandbox | Off (`AIUsageBar.entitlements` empty dict) |
| `~/.codex` | absent |
| `~/.claude` | absent |
| `~/.gemini` | absent |
| `codex` CLI | command not found |
| Security-scoped bookmarks | Requires macOS user gesture — TRUE BLOCKER if production required now; **not** required for 1A classification |
| MAS | Current project is not MAS |

## Security

Do **not** read Codex/Claude/Gemini credential files into AIUsageBar. Local RPC/CLI **stdout quota JSON** is the allowed direction (Stage 1B/1D). Foreign tokens stay with the provider CLI.

## Gate input for Stage 2

Prefer official local RPC/CLI **when the user already runs that CLI**. Do not ship silent filesystem credential scraping.
