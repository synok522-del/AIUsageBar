# S01A — Live ChatGPT / Codex probe

**Sprint:** S01A (Cursor V2 lab)  
**New unit tests:** 0  
**Production ChatGPT code:** untouched (`wham/usage` remains the source)  
**Verdict:** `BLOCKED_PENDING_USER_AUTH`

This environment is a Linux cloud VM. A live `codex app-server --stdio` `account/rateLimits/read` call was **not** invented.

## Live evidence

| ID | Evidence | Result |
|---|---|---|
| T-1A-L1 | Codex binary present or absent | **Absent.** `codex` is not on `PATH`. `command -v codex` failed. No `/usr/local/bin/codex` or `/opt/homebrew/bin/codex`. |
| T-1A-L2 | `codex login` / existing login status | **Not logged in / not runnable.** Binary missing, so login status cannot be queried. |
| T-1A-L3 | `account/rateLimits/read` raw response (secrets redacted) | **Not captured.** No binary, so no RPC was invoked. No fixture was fabricated as a live response. |
| T-1A-L4 | Whether `~/.codex/auth.json` was opened | **NO.** Default and actual: the probe did not list, read, or parse `auth.json`. |
| T-1A-L5 | Error class if blocked | **missing binary** (and therefore not logged in). Not MFA / CAPTCHA. Not a faked sandbox success. |
| T-1A-L6 | This redacted note | This file. |

## What was not done

- Did not open `~/.codex/auth.json`
- Did not read chats, prompts, or conversation history
- Did not change `ChatGPTService` or migrate ChatGPT off `backend-api/wham/usage`
- Did not add a Codex menu card
- Did not invent a rateLimits JSON body

S01C remains **`NOT_PROVEN`**. S02 may proceed on that HOLD.

## Allowed exit

Plan §5 S01A: “Likely result in this Linux VM: `BLOCKED_PENDING_USER_AUTH`. That is a valid sprint exit. Do not fake a Codex response.”
