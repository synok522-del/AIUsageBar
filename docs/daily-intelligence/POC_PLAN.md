# POC Plan — required before Architecture Freeze

Each POC tests one assumption, uses isolated resources (Supabase dev project/schema
`dwi_poc`, Reminders list **Apple Entry POC**), and never touches the production 06:00
task or unrelated Reminders.

## POC-0 (BLOCKING) — ChatGPT scheduled run can publish structured tasks unattended

WHY: without it there is no no-copy-paste path at all (Review §2.1).
HUMAN GATE: requires the user's ChatGPT account.

EXACT STEPS
1. Claude prepares a throw-away endpoint (Supabase Edge Function `dwi_poc_publish`,
   bearer token, inserts the body into `dwi_poc.inbox`). Claude hands the user the URL + token.
2. In ChatGPT, create a **new, separate** scheduled task (not 「每日工作清單」), scheduled
   5 minutes ahead, with the instruction: "Call the publish tool with
   `{\"run_id\":\"poc0-<timestamp>\",\"tasks\":[{\"task_key\":\"poc:manual:test:check\",\"title\":\"POC-0 test\"}]}`".
   Wire the tool using whatever write mechanism the account supports (custom GPT Action or
   connector). Record which mechanism was used.
3. Do not open ChatGPT until after the scheduled time. Lock the phone / close the laptop.

EXPECTED: one row in `dwi_poc.inbox` with that run_id, inserted at the scheduled time.
PASS: row present, timestamp ≈ schedule time, no human interaction between schedule and insert.
FAIL: no row; or ChatGPT asked for confirmation; or tools are unavailable to scheduled tasks.
RETURN: the mechanism used, screenshot of the scheduled-task result, and whether a
confirmation prompt appeared. (Claude checks the table itself.)

If FAIL → evaluate fallbacks F1 (email) then F2 (Claude emitter) from the review; F2 is a
user decision.

## POC-1 — Mac launchd EventKit CLI creates a Reminder unattended

WHY: confirms candidate C's core capability and TCC behavior.
Claude prepares: a minimal signed Swift CLI `dwi-poc-writer` (creates one reminder with
marker `dwi:poc1-<ts>` in list "Apple Entry POC") and a LaunchAgent plist firing 3 min later.
HUMAN GATE STEPS: build/install; run once interactively to grant Reminders permission;
load the agent; lock the screen and walk away.
PASS: reminder appears on iPhone; log shows exit 0 with no prompt pending. FAIL: TCC denial
logged, or no run. RETURN: `~/Library/Logs/dwi-poc/writer.log` and an iPhone screenshot.

## POC-2 — Idempotency marker round-trips through iCloud

Run POC-1 writer in "ensure" mode three times for the same task_id, once after deleting the
ledger hint. PASS: exactly one reminder, found by marker each time, marker (url or notes)
still present when fetched after iPhone edit of the title. RETURN: log + screenshot.

## POC-3 — Recovery after sleep

Schedule the agent for T+5 min, put the Mac to sleep at T, wake at T+15.
PASS: job runs within ~1 min of wake and applies the pending item. RETURN: log.

## Not required for freeze
- Claude "Require this computer" scheduled POC — only if POC-0 fails and F2 is chosen.
- Shortcut authenticated pull — only if POC-1/3 fail or the Mac is not reliably on.
