# Independent Architecture Review — Daily Work Intelligence → Apple Reminders

Status: Phase 1 (review only). No production code. No production workflow touched.
Date: 2026-09-23

## 0. What was inspected

- Repository `synok522-del/AIUsageBar` on branch `claude/daily-intelligence-apple-reminders-x6b5ec`.
  It contains the AIUsageBar macOS app and its POC/release docs. It contains **no**
  Outbox, Fake Outbox, EventKit, Shortcut or Supabase scaffold. The "Fake Outbox" and
  the Astra EventKit investigation referenced in the brief live elsewhere and were not
  available to this review; they are treated as *reported*, not verified.
- This review runs in a Linux cloud container. It cannot reach the user's Mac, iPhone,
  ChatGPT account, or Apple Reminders. Every Apple-side claim below is therefore either
  taken from the brief's real-device reports or marked NEEDS VERIFICATION.

## 1. What I agree with

1. **Three layers with one-way dependency** (Intelligence → State/Outbox → Execution).
   Correct. Intelligence must never wait on, or fail because of, delivery.
2. **ChatGPT stays the thinking surface; Reminders stays dumb.** Correct. Reminders has
   no notion of evidence, revalidation or priority, and should not.
3. **Supabase as ledger/outbox, not a task manager.** Correct, with the refinement in §3.3.
4. **A separate Delivery Gate after the report.** Correct — "is it in the report" and
   "should it buzz the watch" are different questions.
5. **At-least-once transport + idempotent apply.** Correct and the only honest claim.
6. **Completion loop is V2 but identity must allow it.** Correct.
7. **The interactive-vs-unattended distinction (§11).** This is the single most important
   rule in the brief and it applies to one more link than the brief notices (§2.1).

## 2. Critical findings (things the brief does not address)

### 2.1 BLOCKING: the Intelligence → Outbox handoff is unproven — and it is the harder link

The brief spends all its bridge analysis on Outbox → Apple. But the production
requirement "no manual copy/paste" first requires:

> ChatGPT 06:00 scheduled task → **structured tasks written somewhere a machine can read**.

Nothing in the evidence shows this is possible. ChatGPT scheduled tasks produce a
message in a conversation (plus a notification). A ChatGPT conversation is not
machine-readable by any supported API. Whether a *scheduled* ChatGPT run can invoke a
write-capable tool (custom GPT Action, MCP connector, Supabase connector) unattended is
exactly the same class of assumption as "Claude iOS can create a Reminder" — probably
possible interactively, unproven when scheduled.

If this link does not exist, every Apple bridge candidate is moot. **This must be POC-0.**

Fallbacks if POC-0 fails (listed so the decision is fast, not chosen yet):
- F1: The scheduled run emails a structured block to a dedicated inbox; a parser ingests
  it into the Outbox. (Needs verification that scheduled tasks can send email.)
- F2: A Claude scheduled task performs the *structured emission* — it re-derives the
  deliverable task list from the same sources (GitHub, email) — while ChatGPT remains
  the reading/thinking interface. This duplicates intelligence and can disagree with the
  ChatGPT report; it is a real design cost, and it is a user decision.
- F3: Move the whole 06:00 run to a platform with native tool writes. Violates
  "don't redesign the workflow"; last resort only.

### 2.2 Task identity cannot be delegated to the LLM

"Stable task_id" is listed as a field but not as a mechanism. An LLM re-deriving state
every morning will not reproduce the same free-form ID or title. Without a deterministic
key the idempotency story collapses into fuzzy title matching, which is where duplicate
Reminders come from.

Proposal: `task_key = <project_slug>:<source_kind>:<source_ref>:<action_kind>`, e.g.
`aiusagebar:gh_pr:42:review`, `sales:email:<Message-ID>:reply`. Every source in §3 of
the brief already has a natural stable reference (PR number, Message-ID, order/PI number).
The Outbox — not the LLM — assigns the internal `task_id` (UUID) on first sight of a key,
and a `revision` that increments only when a *delivered field* (title, due, notes,
priority) changes, detected by content hash. Tasks without a natural source ref get
`manual:<slug>` keys and must be flagged; they are the duplicate risk surface.

### 2.3 Missing state transitions: retraction

The brief defines create/update but not **what happens to a Reminder when Intelligence
later CLOSES or demotes the task** (e.g. becomes WAITING). Without it the Reminders list
silently diverges from the report — the exact "second place to maintain" the user rejects.

Proposal: a task that was delivered and is no longer in today's SEND set produces a
`RETRACT` delivery. Applied as: mark the Reminder completed with a one-line note
("closed by Daily Intelligence: <evidence ref>") — never delete. Only Reminders carrying
our marker in our dedicated list are ever touched.

### 2.4 "Already-delivered unchanged" requires a desired-state model, not an event queue

Treat each run as publishing a **full snapshot of the desired executable set**. The
Outbox diffs snapshot vs. ledger and emits CREATE / UPDATE / RETRACT deltas. This makes
repeated runs, duplicate publishes and replays naturally idempotent (same snapshot ⇒
empty diff). An append-only "send this task" queue cannot do retraction and is weaker
under duplicates. Guard: a snapshot that would retract > N tasks (e.g. empty snapshot
from a broken run) is held for human confirmation instead of wiping the list.

### 2.5 Apple-side idempotency needs a marker that survives iCloud

The writer must find "our" Reminder again after restart, reinstall, or iCloud resync.
EventKit `calendarItemIdentifier` is documented as potentially changing after a full
sync; `calendarItemExternalIdentifier` is more stable but not guaranteed. So:
ledger stores the identifier as a hint, and the writer falls back to a marker embedded
in the Reminder (`url = dwi://task/<task_id>` or a last notes line `dwi:<task_id>`).
Whether the `url` field round-trips through iCloud and is visible/harmless on iPhone is
NEEDS VERIFICATION (POC-2). The marker is an opaque ID, not a secret.

### 2.6 An LLM does not belong in the delivery path (candidate D)

Candidate D (Claude reads Outbox and creates Reminders) puts a non-deterministic agent in
a path that needs deterministic, idempotent, auditable writes, and it depends on a
connected Mac anyway (per the scheduled-task finding). It has all of C's device
dependency with none of C's determinism. Reject D as the transport. (Claude may still be
relevant to §2.1 F2, which is a different role.)

### 2.7 Candidate comparison

| | A. iPhone Shortcut | B. iOS EventKit app | C. Mac EventKit agent | D. Claude |
|---|---|---|---|---|
| Unattended trigger | Personal automation at time; iOS allows "run without asking" — reliability when locked NEEDS VERIFICATION | iOS background execution is not schedulable reliably (BGTask is opportunistic) — effectively NOT POSSIBLE for a 06:00 guarantee | launchd `StartCalendarInterval` (runs on wake if missed) | Scheduled task + "Require this computer" — unproven |
| Idempotency logic | Weak (Shortcut list filtering, no real error handling) | Strong | Strong | LLM-dependent |
| Testable in CI | No | Partly | Yes (core logic) | No |
| Maintenance | Shortcut edits by hand, brittle | App Store/TestFlight or 7-day re-sign | One signed CLI + plist | Prompt drift |
| Device dependency | iPhone on + unlocked-ish | iPhone | Mac awake + logged in | Mac + Claude Desktop running |

**Recommendation: C** as primary. The iPhone is carried and usually online, which is A's
real advantage, but A cannot do the reconciliation logic reliably and B cannot be
scheduled. C's dependency (Mac logged in; delivery may be delayed until the Mac wakes)
is explicit and recoverable: pending deltas simply wait, and iCloud fans out to
iPhone/Watch once applied. A stays as a documented fallback if the user's Mac is not
reliably on. This is a recommendation pending POC-1/POC-3, not a freeze.

### 2.8 Security

- The Mac agent must **not** hold the Supabase `service_role` key. Use a per-device
  credential that can only call two RPCs (`claim_deltas`, `ack_delta`) — e.g. a
  Supabase Edge Function checking a hashed device token, or a dedicated Postgres role
  with RLS + `SECURITY DEFINER` functions. Publisher gets a separate publish-only
  credential. Revocation = delete the token row.
- Mac secret in Keychain, not in the plist or env.
- Do not log task titles/notes at info level in the agent; log `task_id`, `revision`,
  outcome. Titles may contain customer names/amounts.
- Dedicated Supabase project or schema (`dwi`), no FKs into Sales/Finance/Warehouse.
- The existing Fake Outbox reachable over hotspot: confirm it is not bound to 0.0.0.0 on
  untrusted networks once POCs finish; the C design does not need any inbound port on
  the Mac at all (it pulls), which removes that exposure entirely.

### 2.9 Unnecessary complexity to avoid

- No push channel (APNs/webhooks) in V1: a pull at 06:05 + on wake + every 30 min is enough.
- No separate queue service: Postgres table + `FOR UPDATE SKIP LOCKED` is the queue.
- No dashboard: one SQL view `dwi.delivery_status` answers every §21 question.
- One writer only. Two bridges (e.g. Mac + Shortcut) writing concurrently would need
  cross-writer locking; forbid it by claiming with a lease and a single registered device.

### 2.10 Hidden coupling to watch

- Publishing must be the **last** step of the 06:00 run and its failure must be reported
  in the report as a single line ("delivery: publish failed, will retry"), never abort it.
- The report must not *read back* from Reminders in V1 — that would make Intelligence
  depend on the bridge. V2 completion evidence enters as just another evidence class
  (`REMINDER_COMPLETED`), read from the ledger, and is optional.

## 3. Refined model (proposal, not frozen)

```
ChatGPT 06:00 (unchanged reasoning)
   └─ last step: publish snapshot {run_id, generated_at, tasks[]}  ← POC-0
          │ (publish-only credential; failure ⇒ report still valid)
          ▼
Supabase `dwi` schema
   tasks        (task_key UNIQUE, task_id, revision, content_hash, desired_state)
   runs         (run_id UNIQUE ⇒ duplicate publish is a no-op)
   deliveries   (task_id, revision, op CREATE|UPDATE|RETRACT, state, attempts,
                 claimed_at, lease_until, applied_at, acked_at, apple_item_id, last_error)
          ▲ claim / ack (device credential)
          │
Mac agent (launchd, Swift CLI, EventKit, list "Apple Entry POC" during verification)
   └─ apply idempotently via ledger id → marker fallback → create
          │
Apple Reminders ──iCloud──▶ iPhone / Watch
```

Delivery state machine:
`PENDING → CLAIMED(lease) → APPLIED → ACKED`; `CLAIMED --lease expiry--> PENDING`;
`PENDING|CLAIMED --newer revision--> SUPERSEDED`; any failure → `PENDING` with
`attempts++`; `attempts > N` or permission error → `FAILED_NEEDS_HUMAN`.
"Applied but ACK lost" is safe: re-apply finds the marker and becomes a no-op, then ACKs.

## 4. Answers to the five first-phase questions

See the summary returned to the user and `POC_PLAN.md`. Short form: **not ready to freeze**;
POC-0 (ChatGPT unattended structured publish) is blocking; POC-1/2/3 (Mac EventKit
unattended, marker round-trip, sleep/wake recovery) are required to confirm C.
