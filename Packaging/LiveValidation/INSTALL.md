# AIUsageBar Live Validation — internal test build

This is version 1.1.1 (826), **not frozen v1.1.0 Build 5**. It supports macOS 13+
with native arm64 and x86_64 executables. Provider behavior is unchanged; actual
account results still require human validation. No Developer ID signature or Apple
notarization: this package is **ad-hoc signed only**.

## Download and integrity

Open the exact workflow run linked by the Builder Return. Sign in to GitHub with
repository access; select its `AIUsageBar-LiveValidation-<full source SHA>` artifact.
Actions downloads an outer ZIP. Extract it to find the application ZIP,
`SHA256SUMS`, `PROVENANCE.txt`, this guide and `RESULTS.md`. Artifact retention is
14 days, and administrators may delete it sooner. This is not a public release,
production update or permanent download channel. Check the full source SHA in
PROVENANCE against the Return; check the application ZIP before extracting:

```sh
cd /path/to/extracted-artifact
shasum -a 256 -c SHA256SUMS
```

Expected output is `OK`. Stop on a mismatch. The build process is reproducible
from a clean exact Git checkout with Xcode and network access for SwiftPM:
`Packaging/LiveValidation/build.sh`. ZIP bytes can differ across toolchains/builds;
each run has its own checksum and toolchain provenance. No signing keys needed.

## Install without changing Build 5

1. Keep `AIUsageBar.app` (Build 5) and its existing installation untouched. Quit
   it temporarily to avoid confusing the two menu bar icons; do not uninstall it.
2. Extract the inner application ZIP. Create `~/Applications/AIUsageBar Live Validation/`
   and copy **AIUsageBar Live Validation.app** there. Never rename it to
   `AIUsageBar.app`, drag it over an existing app, or accept a Replace prompt.
3. Open only the validation app. macOS may block an internet-downloaded ad-hoc
   app. After verifying the checksum/source, use Finder's Open and, if macOS
   offers it, System Settings → Privacy & Security → Open Anyway for this app.
   Do not disable Gatekeeper or remove quarantine system-wide. If your Mac or
   organization's policy refuses it, stop and report that; a Developer ID signed,
   notarized distribution would require a separate authorized publishing decision.
4. Confirm the panel says **AIUsageBar Live Validation**, and Settings shows
   **Live Validation · 1.1.1 (826)**. If absent, quit immediately. Launch at login
   and updates are disabled. This is a menu bar app, so no Dock icon is expected.

## Isolation and login

- Bundle/preferences domain: `synok522.AIUsageBar.LiveValidation`.
- Keychain service: `com.synok522.AIUsageBar.LiveValidation`. Existing production
  credentials are never read or migrated into this service. Log in separately.
- WebKit cookies and website storage are process-local and shared only among
  validation windows. Quitting drops browser state; provider credentials saved
  in this app's separate Keychain may persist. Re-login when refresh requests it.
- No URL handlers, app groups or shared Keychain access groups; no registration
  or removal of login items. Sparkle initialization is blocked by compile-time
  flavor even if updater metadata is accidentally added.
- Validation may send native usage notifications under its separate bundle ID;
  disable them in Settings if unwanted. It does not modify Build 5 settings.

For Claude, ChatGPT and Grok, use each app login button and the provider's normal
login page. Never send credentials to the developer or paste them into reports.
Select only accounts you intend to test. In a separate official browser window,
open the provider's usage/limit screen and note the same account, plan, model,
usage window and timezone privately. Refresh AIUsageBar, record observation time,
and compare values and reset times using `RESULTS.md`. Avoid repeatedly retrying
rate-limited endpoints. Record missing official values as unavailable; an app
Unknown/unsupported allowance stays Unknown unless actual evidence proves its
meaning. Do not assume private fields represent Chat/Codex/Work/credit allowances.

Test fresh login, refresh, quit/reopen and logout for each provider. Record failures
as categories (login blocked, unavailable, rate-limited, stale, parse failure),
not raw network output. After logout, check validation credential state; after
quitting validation, reopen frozen Build 5 and confirm its settings/session state
are unchanged. Do not enter production credentials into automated tests.

## Privacy-safe reporting and cleanup

Fill `RESULTS.md` using aggregate values only. Never include names, email, account
IDs, chats, cookies, tokens, authorization headers, raw responses or unredacted
screenshots. Any optional cropped screenshot must exclude identifying material.
No additional provider diagnostics are enabled by this build.

To stop testing, log out all providers in validation first, quit, then remove only
`AIUsageBar Live Validation.app`. Do not remove production preferences or Keychain
entries. Optional preference cleanup is limited to:
`defaults delete synok522.AIUsageBar.LiveValidation` (only while validation is quit).
A missing domain is harmless. If leftover credentials need manual removal, use
Keychain Access and inspect only the exact validation service above; do not delete
`com.synok522.AIUsageBar`. Removing the app alone does not delete Keychain entries.
