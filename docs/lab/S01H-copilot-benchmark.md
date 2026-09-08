# S01H — Copilot as architecture benchmark (not a product card)

**Sprint:** S01H (Cursor V2, docs only)  
**New tests:** 0  
**Swift types in the app target:** none  
**UI:** none  
**Production providers:** still ChatGPT, Claude, Grok only

## What “gold standard” means here

GitHub Copilot quota, when observed through GitHub’s own authenticated **`GET /rate_limit`** (GitHub REST), is the architecture **benchmark** for V2 — not a template to clone into AIUsageBar’s menu.

That endpoint is gold-standard **as a meter contract** because:

| Property | Why it matters for V2 |
|---|---|
| **Owner of the API is the same party that owns the quota** | GitHub publishes remaining / limit / reset for the identity that holds the token. The meter is not reverse-engineered from a chat UI, a cookie jar, or a WebKit “READY” latch. |
| **Identity is explicit** | The token names an account. Cross-account reuse is a contract violation, not a fingerprint of empty cookies. |
| **Reset is a real timestamp** | `reset` is supplied by the API. It is not derived from public blog rules, not substituted from a billing-period field, and not invented when missing. |
| **Remaining is a first-class number** | Used/remaining come from the payload. Limitless/null must stay “unknown remaining,” not a fabricated percent. |
| **Failure is HTTP, not session theater** | 401/403 mean unauthorized. Missing a meter is not logout. Cookie-exists / navigation-finished / WKWebView READY would never count as success against this bar. |
| **No user content** | The call does not read chats, prompts, repos, or Copilot conversation history. |

V2 should **aspire to this shape** (account-keyed snapshot, real `resetAt` when the provider gives one, remaining without guesswork, recovery ≠ cookie latch) for ChatGPT, Claude, and Grok **using each product’s own authorized source**.

## Why AIUsageBar must not copy Copilot as a UI provider

1. **Product scope is frozen.** Shipped cards are ChatGPT, Claude, and Grok. Copilot is classified in `docs/V2_BASELINE.md` as architecture benchmark only. Adding a Copilot card would be a new UI provider without Stage 6 authorization (sprint-plan hard rule: no Copilot UI).
2. **Different vendor, different identity plane.** `/rate_limit` is a **GitHub** API. AIUsageBar’s production logins are chatgpt.com / claude.ai / grok.com WebKit cookies. Wiring GitHub OAuth into this menu bar would mix identity systems and imply a fourth account the user did not ask this app to show.
3. **Gold standard ≠ ship the endpoint.** Using Copilot’s API as a **yardstick** does not grant permission to display Copilot remaining in the extra. Copying the HTTP call into `UsageViewModel` would be a production swap this sprint explicitly forbids.
4. **Would skip the challenger/HOLD path.** Cursor and Gemini are HOLD until Stage 6 PASS. Copilot is stricter: it is **never** a card in this experiment. Docs-only is the whole sprint.
5. **No Swift types.** There is no `CopilotService`, `CopilotUsage`, `Provider.copilot`, or menu mapping in this change. If those types appear later without a dedicated authorized sprint, that is a review FAIL.

## What later sprints may take from this note

- Prefer an official, identity-bearing quota API **owned by that product** when one exists and is authorized.
- Do not treat a convenient GitHub endpoint as a stand-in for ChatGPT `wham/usage`, Claude org usage, or Grok `GetGrokCreditsConfig`.
- Do not add Copilot (or Cursor / Gemini) cards unless 偉凱 explicitly authorizes that provider after the experiment.

## Production

`main` stays `d6a4bd7…`. This file does not migrate any provider. Web Grok / ChatGPT / Claude paths are unchanged.
