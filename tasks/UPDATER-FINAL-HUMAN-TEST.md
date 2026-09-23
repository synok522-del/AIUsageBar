# AIUsageBar Updater — Final Human Test (isolated Mac only)

This replaces `Packaging/UpdaterSpike/HUMAN-TEST.md` as the final updater Human Gate. The historical U1 binaries (source `0df57e6` / `4fb083d`, versions 0.0.1 / 0.0.2) do **not** contain the current `AppUpdater` or Settings updater UI, so this procedure never uses them as evidence.

## Safety (read first)

- **USE AN ISOLATED MAC / VM ONLY.**
- **DO NOT run the replacement test against Kenny's production Build 4 installation.**
- If the isolated Mac already has production Build 4 (`1.0.0 (4)`) at `/Applications/AIUsageBar.app`, **stop**. Confirm a verified backup/snapshot and an explicit isolation plan before anything replaces it. Staging builds intentionally use the real bundle ID, Keychain and WebKit identities, so they will read and write the same data as production.
- Use test provider accounts where possible. Never record cookies, tokens, Keychain values or full UserDefaults.
- Production feed `https://synok522-del.github.io/AIUsageBar/appcast.xml` is not created or modified. Build 5/6 numbers are not used.

## Staging identities (fill in from the release step)

| Item | Value |
| --- | --- |
| Source SHA (both builds) | `<REMEDIATED_SHA>` — must equal the reviewed commit |
| Staging host | `0.0.3 (9003)` — `AIUsageBar-0.0.3-final-9003.dmg` |
| Staging candidate | `0.0.4 (9004)` — `AIUsageBar-0.0.4-final-9004.dmg` |
| Host SHA-256 / size | `<to record>` |
| Candidate SHA-256 / size | `<to record>` |
| Staging feed | `https://synok522-del.github.io/AIUsageBar/staging/final-20260924/appcast.xml` |
| Staging release | `https://github.com/synok522-del/AIUsageBar/releases/tag/final-staging-20260924` (pre-release, staging only) |
| Staging EdDSA public key | `Packaging/UpdaterSpike/public-key.txt` (the existing U1 staging key) |
| Feed expiration interval | `0` (staging only; the production value is still a human decision) |

The U1 feed `staging/u1-20260915` and release `u1-staging-20260915` are left untouched.

## Release preparation (release Mac, before the test)

This needs the Developer ID identity, a notary keychain profile and the staging EdDSA private key in the release Mac's Keychain. None of these belong in Git or in logs. Work outside iCloud/File Provider folders, e.g. `/private/tmp/AIUsageBar-final-staging`.

1. Check out `<REMEDIATED_SHA>` with a clean tree. Build both apps with the SHA as an explicit provenance argument:
   `Packaging/UpdaterSpike/build-staging.sh final-host OUT "$(cat Packaging/UpdaterSpike/public-key.txt)" <REMEDIATED_SHA>`, then the same command with `final-candidate`.
   The script refuses any other HEAD and checks the exported version, build, feed URL and public key.
2. For each exported app, run `Packaging/UpdaterSpike/notarize-dmg.sh APP OUT NOTARY_PROFILE`. It runs, in order: app notarize → staple → Gatekeeper → DMG → DMG sign → DMG notarize → staple → validate. It then freezes the DMG and writes its SHA-256 and size. Nothing may modify a DMG after this.
3. Run `python3 Packaging/UpdaterSpike/verify-dmg.py DMG APP` to confirm packaging kept the app byte-identical.
4. Create the EdDSA archive signatures from the frozen DMGs with Sparkle 2.10.0 `sign_update`.
5. Upload both DMGs to the **staging pre-release** `final-staging-20260924`. Fetch each one back with `fetch-public.py` and require the same SHA-256, size and EdDSA verification (`verify-signature`) as the local bytes. Stop on any mismatch.
6. **Feed phase A (host only):** use `generate_appcast` to generate and sign a feed that lists only 0.0.3 (9003). Publish it **last**, to `staging/final-20260924/appcast.xml` on the isolated staging Pages branch. Read it back publicly and verify it with `verify-signature ... --feed`.
7. Record the SHA, hashes, sizes and URLs in the table above.

Phase B is published during the test (mandatory step 7).

## Mandatory release gates

Record PASS / FAIL for every row. A row passes only if it was actually observed.

| # | Gate | Expected |
| --- | --- | --- |
| 1 | Install host | Mount the verified host DMG, copy the app to `/Applications/AIUsageBar.app`, eject. Don't launch from the DMG or Downloads. |
| 2 | Launch | Menu bar icon appears, no Dock icon, exactly one AIUsageBar process. |
| 3 | Settings opens | Settings window shows the **Software Updates** section. |
| 4 | Host identity | Settings shows **Version 0.0.3 (9003)**. |
| 5 | No-update result | Feed phase A is live. Click **Check for Updates…**. Status must read **"No eligible update was found in the checked feed."**, never **"Update operation failed"**. |
| 6 | Failure result | Turn networking off, then **Check for Updates…**. Status must read **"Update operation failed. Try again later."**, and must not keep showing the no-update text. Turn networking back on. |
| 7 | Candidate feed | Publish **feed phase B**, a signed feed listing 0.0.3 and 0.0.4, generated from the already-verified uploads and published last. Read it back publicly and verify the feed signature. |
| 8 | Discovery | **Check for Updates…** shows "Checking for updates…", then the stock Sparkle window offers 0.0.4 (9004). Settings shows "Update 0.0.4 is available." Dismiss once: the status must leave "available" (shows "Updater is ready."), and the app stays at 9003. |
| 9 | Start update | Check again and choose install in the stock Sparkle window. |
| 10 | Download → verify → install → replace | Status passes through downloading, verifying/preparing and installing, with no Sparkle error. |
| 11 | Relaunch | The old process exits. A new PID starts from `/Applications/AIUsageBar.app` with no manual launch. |
| 12 | MenuBarExtra returns | The menu bar icon is back and the panel opens; no Dock icon. |
| 13 | Candidate identity | Settings shows **Version 0.0.4 (9004)**. `codesign --verify --deep --strict /Applications/AIUsageBar.app` and `spctl --assess --type execute` both pass. |
| 14 | Re-check on candidate | **Check for Updates…** gives the no-update text, not failure, and 9004 is not offered as newer. |
| 15 | Sessions | ChatGPT, Claude and Grok each still signed in, and usage refresh works. Genuine server-side expiry is recorded separately and does not count as a pass. |
| 16 | Preferences | Language, notification preference, the automatic-checks toggle, Launch at Login state, and last-good usage (where observable) are all unchanged. |
| 17 | Quit / relaunch | Quit from the app and relaunch manually; gates 12, 13 and 15 still hold. |
| 18 | Reboot | Reboot. If Launch at Login was on, the app starts by itself; gates 12, 13 and 15 still hold. |
| 19 | Operates | A final usage refresh succeeds and no updater error appears. |
| 20 | Record | Every row above is PASS or FAIL, with sanitized evidence (screenshots without credentials, PIDs, hashes). |

Any FAIL stops the gate. Don't delete or recreate provider data to hide a failure. Recover by reinstalling the verified host DMG.

## Optional diagnostics (not release gates)

- Mount list before and after the update, including UUID-named Sparkle mounts: nothing from the update should stay mounted.
- Safe Sparkle/Autoupdate log excerpts on Tahoe (EPERM, App Management prompts).
- Negative fixtures on a snapshot: tampered enclosure, unsigned or modified feed, same or lower build. Each must reject without installing.
- A second architecture (arm64 / x86_64) or macOS 13.

## Result handling

- U1 stays **INCONCLUSIVE** and DMG_ONLY stays **CONDITIONAL** until every mandatory row passes on these exact bytes.
- Passing this gate does not release Build 5 and does not settle production key custody or `SUSignedFeedFailureExpirationInterval`.
