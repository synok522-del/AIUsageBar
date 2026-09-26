# AIUsageBar Updater — Final Human Test (isolated Mac only)

This replaces `Packaging/UpdaterSpike/HUMAN-TEST.md` as the final updater Human Gate. The historical U1 binaries (source `0df57e6` / `4fb083d`, versions 0.0.1 / 0.0.2) do **not** contain the current `AppUpdater` or Settings updater UI, so this procedure never uses them as evidence.

## Safety (read first)

- **USE AN ISOLATED MAC / VM ONLY.**
- **DO NOT run the replacement test against Kenny's production Build 4 installation.**
- If the isolated Mac already has production Build 4 (`1.0.0 (4)`) at `/Applications/AIUsageBar.app`, **stop**. Confirm a verified backup/snapshot and an explicit isolation plan before anything replaces it. Staging builds intentionally use the real bundle ID, Keychain and WebKit identities, so they will read and write the same data as production.
- Use test provider accounts where possible. Never record cookies, tokens, Keychain values or full UserDefaults.
- Production feed `https://synok522-del.github.io/AIUsageBar/appcast.xml` is not created or modified. Build 5/6 numbers are not used.

## Staging identities and release evidence

| Item | Value |
| --- | --- |
| Source SHA (both builds) | `5ec435fb5f93422228e49a3fc7f57cec6982e32c` |
| Staging host | `0.0.3 (9003)` — `AIUsageBar-0.0.3-final-9003.dmg` |
| Host artifact URL | `https://github.com/synok522-del/AIUsageBar/releases/download/final-staging-20260924/AIUsageBar-0.0.3-final-9003.dmg` |
| Host SHA-256 / size | `dd3cba548f30f2f5fe93e598c61b7b9e047007989fb4621d777347ac3fa7edcc` / `4,074,231` bytes |
| Staging candidate | `0.0.4 (9004)` — `AIUsageBar-0.0.4-final-9004.dmg` |
| Candidate artifact URL | `https://github.com/synok522-del/AIUsageBar/releases/download/final-staging-20260924/AIUsageBar-0.0.4-final-9004.dmg` |
| Candidate SHA-256 / size | `e7c650818677d11fd810a1dbacdeece6ec6447b49d973068298fcbd4001c8528` / `4,074,241` bytes |
| Staging feed | `https://synok522-del.github.io/AIUsageBar/staging/final-20260924/appcast.xml` |
| Staging release | `https://github.com/synok522-del/AIUsageBar/releases/tag/final-staging-20260924` (pre-release, staging only) |
| Artifact manifest | `https://github.com/synok522-del/AIUsageBar/releases/download/final-staging-20260924/final-staging-artifact-manifest.json`; SHA-256 `c709475823a5b0d392af7dc74c58f4d69c45fa8d44f62c0a9daeb2b6e9ee0705` |
| Staging EdDSA public key | `Packaging/UpdaterSpike/public-key.txt` (the existing U1 staging key) |
| Feed expiration interval | `0` (staging only; the production value is still a human decision) |
| App notarization | Host `8f57703d-d8e2-44b3-bda3-08ba09795f89`: Accepted; candidate `c4389b97-b0a8-47af-8c8d-0279bd060895`: Accepted |
| DMG notarization | Host `a1c57b17-f8b0-4546-9291-9bfba3d017a9`: Accepted; candidate `2945da18-5ad3-4bb2-b1e5-2df1f39f62bd`: Accepted |
| Staple and Gatekeeper | Both apps and DMGs stapled and validated; app Gatekeeper assessment reported Notarized Developer ID; both DMGs were accepted by Gatekeeper |
| Signing identity | Developer ID Application, Team ID `S898B9KBWN`; Hardened Runtime and arm64 + x86_64 verified, including nested Sparkle code |
| EdDSA order | PASS — each DMG was stapled and validated, then frozen and SHA-256 recorded, then signed with the existing staging key; hashes stayed unchanged |
| Remote artifacts | PASS — public HTTPS downloads returned 200; both DMGs matched the frozen hashes and sizes, and both detached EdDSA signatures verified |
| Public feed verification | PASS — HTTP 200; feed SHA-256 `0859b7529d6c054d572e06bef0d4065d4daac05bb529c910b223b1f4adf7cdce`; byte-identical to the locally signed feed; feed signature verified |
| Enclosure in public feed | Only candidate `0.0.4 (9004)`; URL, length `4,074,241`, and EdDSA signature match the remotely verified candidate artifact |
| Human Gate | **NOT RUN** — installed-host, replacement, relaunch, session, and Tahoe observations remain open |

The U1 feed `staging/u1-20260915` and release `u1-staging-20260915` are left untouched.

## Release preparation (completed on the release Mac)

Both staging apps were built from the exact source SHA above on the release Mac using the existing `AIUsageBar-Notary` profile and staging EdDSA Keychain identity. No private key or credential was added to Git or written to the report. Build 4, production signing keys, and production release assets were not modified.

The exact-source Release archives and exports passed bundle/version/build, feed URL, public key, Team ID, Hardened Runtime, nested Sparkle signing, and universal architecture checks. The app and DMG notarization submissions were all Accepted. Stapling and validation completed before the final DMG hashes and detached EdDSA signatures were produced. The two final DMGs were then uploaded to the new staging prerelease and fetched back over public HTTPS; remote bytes and signatures matched.

The signed candidate-only feed was published **last** at the URL above, after verifying both release assets. It advertises only candidate `0.0.4 (9004)`; host `0.0.3 (9003)` can discover it, and candidate `0.0.4 (9004)` must not be offered as a newer version. The public feed was fetched over HTTPS and its feed signature, enclosure URL, size, and signature were verified. Do not modify or republish the release assets or appcast during the Human Gate.

The public Build 4 DMG was independently downloaded and its SHA-256 remained `49d4ecc16ea149d8d05e780cd9512ecaba2bbd49a6c118dfc1250c55ff4e3415`. Its `1.0.0 (4)` app bundle has no `SUFeedURL` or `SUPublicEDKey` updater configuration, so it is not configured to read this staging feed. The production appcast was not changed.

## Mandatory release gates

Record PASS / FAIL for every row. A row passes only if it was actually observed.

| # | Gate | Expected |
| --- | --- | --- |
| 1 | Install host | Mount the verified host DMG, copy the app to `/Applications/AIUsageBar.app`, eject. Don't launch from the DMG or Downloads. |
| 2 | Launch | Menu bar icon appears, no Dock icon, exactly one AIUsageBar process. |
| 3 | Settings opens | Settings window shows the **Software Updates** section. |
| 4 | Host identity | Settings shows **Version 0.0.3 (9003)**. |
| 5 | Candidate discovery | With networking enabled and the published candidate-only feed reachable, **Check for Updates…** shows checking then offers `0.0.4 (9004)`. Settings shows “Update 0.0.4 is available.” Dismiss once: status leaves “available” and the app remains at 9003. |
| 6 | Failure result | Turn networking off, then check again. Status must read **“Update operation failed. Try again later.”**, not retain stale availability or report no update. Restore networking. |
| 7 | No download before consent | Confirm no candidate download begins before the user chooses to install. |
| 8 | Start update | Check again and choose install in Sparkle's stock UI. |
| 9 | Download → verify → install → replace | Status passes through downloading, verifying/preparing and installing, with no Sparkle error. |
| 10 | Relaunch | The old process exits. A new PID starts from `/Applications/AIUsageBar.app` with no manual launch. |
| 11 | MenuBarExtra returns | The menu bar icon is back and the panel opens; no Dock icon. |
| 12 | Candidate identity | Settings shows **Version 0.0.4 (9004)**. `codesign --verify --deep --strict /Applications/AIUsageBar.app` and `spctl --assess --type execute` both pass. |
| 13 | Re-check on candidate | **Check for Updates…** reports “No eligible update was found in the checked feed,” not failure, and 9004 is not offered as newer. |
| 14 | Sessions | ChatGPT, Claude and Grok each remain signed in, and usage refresh works. Genuine server-side expiry is recorded separately and does not count as a pass. |
| 15 | Preferences | Language, notification preference, the automatic-checks toggle, Launch at Login state, and last-good usage (where observable) are unchanged. |
| 16 | Quit / relaunch | Quit from the app and relaunch manually; gates 11, 12 and 14 still hold. |
| 17 | Reboot | Reboot. If Launch at Login was on, the app starts by itself; gates 11, 12 and 14 still hold. |
| 18 | Operates | A final usage refresh succeeds and no updater error appears. |
| 19 | Record | Record PASS / FAIL / NOT RUN for every gate with sanitized evidence. Do not mark an unobserved result PASS. |

**Human Gate result: NOT RUN.** The rows above remain untested until performed on an isolated Mac / VM.

Any FAIL stops the gate. Don't delete or recreate provider data to hide a failure. Recover by reinstalling the verified host DMG.

## Optional diagnostics (not release gates)

- Mount list before and after the update, including UUID-named Sparkle mounts: nothing from the update should stay mounted.
- Safe Sparkle/Autoupdate log excerpts on Tahoe (EPERM, App Management prompts).
- Negative fixtures on a snapshot: tampered enclosure, unsigned or modified feed, same or lower build. Each must reject without installing.
- A second architecture (arm64 / x86_64) or macOS 13.

## Result handling

- U1 stays **INCONCLUSIVE** and DMG_ONLY stays **CONDITIONAL** until every mandatory row passes on these exact bytes.
- Passing this gate does not release Build 5 and does not settle production key custody or `SUSignedFeedFailureExpirationInterval`.
