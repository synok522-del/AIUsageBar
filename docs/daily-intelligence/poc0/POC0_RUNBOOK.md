# POC-0 — Can a separate ChatGPT scheduled task make an unattended structured external write?

Scope: exactly this one question. No POC-1..3, no production schema, the 06:00
「每日工作清單」 task is not touched.

## Test-side resources (created by Claude)

| Resource | Where | Purpose |
|---|---|---|
| Schema `dwi_poc` | Supabase project `hmwurhfsvvgbwnfsvucu` (the only project on the account) | Isolated; no FKs, no grants to `anon`/`authenticated`, RLS on, no policies ⇒ not reachable via the public API |
| `dwi_poc.invocations` | ″ | Server-side log of **every** request: method, tool, user-agent, auth result, outcome |
| `dwi_poc.writes` | ″ | The committed test row(s); `source` = `chatgpt_mcp` or `claude_selftest` |
| `dwi_poc.token` | ″ | SHA-256 of the access token (plaintext is never stored or committed) |
| Edge Function `dwi-poc0-mcp` | ″ | Minimal stateless MCP server (Streamable HTTP). One tool, `record_poc_write`, which accepts **only** the fixed payload |

Source: `edge-function/index.ts`. Access: `?k=<token>` in the URL (ChatGPT custom
connectors reliably support "no auth" + URL; a static bearer header is not assumed).
Blast radius if the token leaks: someone can insert the fixed test row into `dwi_poc.writes`.

Fixed payload:
```json
{"test_id": "CHATGPT-EXIT-001", "title": "ChatGPT unattended external write test"}
```

## Mechanism under test

**ChatGPT custom MCP connector (Developer mode, "Apps/Connectors")** used from a
**ChatGPT scheduled Task**.

Not used: custom GPT Actions — there is no evidence that Tasks can run inside a custom GPT,
so they are not assumed. Whether connectors are available *inside scheduled Tasks at all*
is precisely the unknown this POC answers; "tool not offered in the task" is a valid FAIL.

## How each required distinction is observed

| # | Question | Evidence (independent of ChatGPT's own claim where possible) |
|---|---|---|
| 1 | Scheduled task executed | ChatGPT task run entry / notification at the scheduled time (user) |
| 2 | Tool actually invoked | `dwi_poc.invocations` row `outcome='write_attempt'` within the run window (server) |
| 3 | Confirmation requested | User observation + timing: if the `write_attempt` timestamp matches a user tap rather than the schedule time, it was not unattended |
| 4 | Row committed | `dwi_poc.writes` row with `source='chatgpt_mcp'` in the run window (server) |
| 5 | Independent read-back | Claude runs `verify.sql` and compares to the fixed payload |

Contamination guard: any write before the schedule time (e.g. during setup) is excluded by
the run window; the setup steps say not to call the tool.

## PASS / FAIL
PASS = all of: run occurred at schedule time · no user interaction at execution time ·
`write_attempt` logged · `chatgpt_mcp` row committed in window · read-back equals payload.

FAIL = any of: confirmation requested · connector/tool unavailable in the task · tool not
invoked · auth failure (`auth_ok=false`) · run succeeded but no committed row · any manual
step at execution time.

## Teardown (after the result is recorded)
```sql
drop schema dwi_poc cascade;
```
plus delete Edge Function `dwi-poc0-mcp`, plus remove the connector in ChatGPT.
