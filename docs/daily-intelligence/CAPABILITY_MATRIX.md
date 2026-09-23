# Capability Matrix

Legend: VERIFIED (real-device evidence reported) · NOT POSSIBLE · DESIGN CHOICE · NEEDS VERIFICATION

| # | Capability | Class | Evidence / note |
|---|---|---|---|
| 1 | ChatGPT 06:00 scheduled run produces the Daily Intelligence report | VERIFIED (per user) | Existing workflow |
| 2 | ChatGPT **scheduled** run writes structured JSON to an external store without human action | **NEEDS VERIFICATION — BLOCKING** | No evidence. Interactive tool use ≠ scheduled tool use |
| 3 | ChatGPT conversation content readable by an external program | NOT POSSIBLE (no supported API) | Rules out "scrape the conversation" |
| 4 | Claude iOS interactive creates a Reminder | VERIFIED (real device) | Brief §10 |
| 5 | Claude iOS interactive reads completion state | VERIFIED (real device) | Brief §10 |
| 6 | Claude scheduled task writes Reminders unattended via "Require this computer" | NEEDS VERIFICATION | Only an instruction message observed; no success case |
| 7 | iPhone reaches Mac Fake Outbox over network | VERIFIED (unauthenticated 401) | Transport only |
| 8 | Shortcut authenticated pull → create → ACK | NEEDS VERIFICATION | Not required if C is chosen |
| 9 | iOS app scheduled at fixed time in background | NOT POSSIBLE (reliably) | BGTaskScheduler is opportunistic |
| 10 | (Bridge C is the leading hypothesis, not frozen) macOS launchd job runs EventKit CLI with Reminders access, user logged in, screen locked | NEEDS VERIFICATION | POC-1; TCC grant must attach to the signed binary |
| 11 | launchd `StartCalendarInterval` fires after wake if the time was missed during sleep | NEEDS VERIFICATION on user's Mac | Documented behavior; confirm (POC-3) |
| 12 | Delivery while Mac powered off / logged out | NOT POSSIBLE (C) | Accepted: delayed until next login/wake |
| 13 | Reminder `url` or notes marker round-trips via iCloud and is findable after re-query | NEEDS VERIFICATION | POC-2 |
| 14 | Supabase: RPC-only device credential with RLS | DESIGN CHOICE (standard feature) | Verify in dev project at implementation |
| 15 | Snapshot diff ⇒ CREATE/UPDATE/RETRACT | DESIGN CHOICE | Unit-testable in CI |
| 16 | Three-tier identity: preserved canonical ID / deterministic source key / persistent assigned ID | DESIGN CHOICE | Tier 3 needs publisher to echo assigned IDs |
| 16b | Apple projection of CANCELLED/WAITING/WITHDRAWN | NEEDS VERIFICATION | Policy not frozen; test in Apple Entry POC list |
| 17 | Exactly-once delivery | NOT POSSIBLE / not claimed | At-least-once + idempotent apply |
| 18 | Completion read-back (V2) via EventKit on same agent | NEEDS VERIFICATION (cheap, deferred) | `EKReminder.isCompleted`/`completionDate` |
