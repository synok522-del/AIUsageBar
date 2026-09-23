# AIUsageBar updater — final isolated Mac Human Gate

**USE AN ISOLATED MAC / VM ONLY.** This procedure replaces the historical U1-only procedure. It must use the new artifacts listed below, built from the exact remediated source SHA. The old U1 artifacts from `0df57e6` and `4fb083d` are not evidence for this implementation.

**Do not run replacement testing against Kenny's production Build 4 installation. If the isolated Mac currently has production Build 4 at `/Applications/AIUsageBar.app`, stop and confirm the backup/isolation strategy before replacing it.** A renamed copy or alternate `TMPDIR` is not isolation because the app retains the real bundle, Keychain, WebKit, and UserDefaults identities.

## Artifact identity

| Item | Identity |
| --- | --- |
| Remediated source SHA | `19531d53aa0b99a0442beea1783c1999293be9f8` |
| Sparkle | `2.10.0` (`eef1a539a373c1f1a320624b1130fc5de7b2e100`) |
| Staging host | `0.0.3` / build `9031` |
| Host DMG | Not produced: app notarization is blocked because the `AIUsageBar-Notary` profile is absent from the current login keychain |
| Staging candidate | `0.0.4` / build `9032` |
| Candidate DMG | Not produced: app notarization is blocked because the `AIUsageBar-Notary` profile is absent from the current login keychain |
| Signed staging feed | `https://synok522-del.github.io/AIUsageBar/staging/u2-remediated-20260923/appcast.xml` |
| Staging GitHub Release | Not published; waiting for notarized and stapled host/candidate DMGs |
| Feed SHA-256 | Not produced; the signed feed is not published until its enclosure is verified |
| Artifact manifest | Not published; waiting for final DMG hashes and signatures |

## Preparation evidence (2026-09-23)

- The exact source SHA above passed all three PR #35 GitHub checks: macOS build, `AIUsageBarTests`, and UI/launch tests.
- Local serial execution passed all 260 `AIUsageBarTests` in 9 suites. A separate full-scheme run also executed the product tests, but one timing-sensitive integration test failed under parallel load and the UI runner could not initialize while macOS authentication was active. The failure did not reproduce in the serial product run; exact-SHA remote CI passed both product and UI jobs.
- Signed Developer ID Release archives and exports were produced for both staging identities. Each passed bundle/version/build, Sparkle staging configuration, Team ID, Hardened Runtime, code-signature, and universal architecture checks. They are local preparation outputs only and are not installers.
- `xcrun notarytool history --keychain-profile AIUsageBar-Notary` reports that no Keychain password item exists for that profile. No app or DMG was submitted, no staging release/feed was created, and the existing U1 staging fixture was left untouched.
- The public `v1.0.0` Build 4 release still lists `AIUsageBar-1.0.0-build4.dmg` with SHA-256 `49d4ecc16ea149d8d05e780cd9512ecaba2bbd49a6c118dfc1250c55ff4e3415`. The original `u1-staging-20260915` prerelease remains separate and unchanged.

Before continuing, configure the already-approved Apple notary credentials locally under the `AIUsageBar-Notary` profile (do not put credentials in the repository or paste them into this report). Then notarize and staple both staging apps and DMGs, verify their final hashes and EdDSA signatures, publish the new staging release assets, and publish the signed feed last. The Human Gate below cannot start before those steps pass.

The staging host and candidate use a staging-only signed-feed configuration and the existing U1 staging key. The feed contains the candidate; it is not the production appcast. Builds `0.0.3/9031` and `0.0.4/9032` are distinct from Build 4 and reserved production Builds 5 and 6. The production feed and production signing key are not used.

## Before starting

Use a disposable VM or separate test Mac with a restorable snapshot. Record macOS version/build, CPU architecture, test account, current app path/version, and mounted-image baseline. Verify the downloaded host DMG SHA-256, size, notarization staple, Developer ID signature, Team ID `S898B9KBWN`, Bundle ID `synok522.AIUsageBar`, and both architecture slices against the manifest. Verify the candidate DMG and its EdDSA signature too. Do not launch either app from Downloads or a mounted image.

Use test accounts where safe. Record only whether each provider is signed in and a masked account identity. Never copy cookies, tokens, Keychain values, or full UserDefaults contents into the report.

## Mandatory release gates

1. Install the verified staging HOST into `/Applications/AIUsageBar.app` on the isolated Mac. Eject the DMG after copying the app.
2. Launch it normally and confirm the menu bar app appears without an unexpected Dock icon or duplicate process.
3. Open Settings.
4. Confirm Settings shows host `0.0.3 (9031)` and the Software Updates controls are available.
5. Disconnect the network, manually check for updates, and confirm the status reports failure. It must not report no-update/latest. Restore the network afterward.
6. With the candidate feed reachable, manually check again and confirm the status transitions through checking to an available update `0.0.4` / `9032`.
7. Confirm no candidate download began before the user chose to update.
8. Start the update from Sparkle's stock UI.
9. Confirm the stock UI reports download progress and completion.
10. Confirm Sparkle verifies the signed feed and candidate before extraction; record the exact artifact URL and safe diagnostic evidence.
11. Approve installation and confirm install/replacement of the bundle at `/Applications/AIUsageBar.app`.
12. Confirm the old process exits and the new process relaunches automatically from `/Applications/AIUsageBar.app`.
13. Confirm the MenuBarExtra returns and Settings opens.
14. Confirm Settings shows candidate `0.0.4 (9032)`. Manually re-check: the current feed must yield a truthful no-eligible-update result, not failure and not a claim broader than the checked feed.
15. Confirm ChatGPT, Claude, and Grok test sessions remain signed in and usable.
16. Confirm preferences, selected language, Launch at Login, and last-good usage remain where observable.
17. Quit the app, relaunch it normally, and confirm it operates correctly.
18. Reboot the isolated Mac if required by the existing gate plan; confirm the app and Launch at Login behavior afterward.
19. Confirm no Sparkle DMG mount remains, and repeat signature, Gatekeeper, staple, process-path, and version/build checks on the installed candidate.
20. Record PASS or FAIL for every gate below. Do not mark an unobserved result PASS.

| Gate | Result: PASS / FAIL / NOT RUN | Evidence or short note |
| --- | --- | --- |
| Host install and launch |  |  |
| Menu bar / Dock / single process |  |  |
| Settings host version/build |  |  |
| Offline check reports failure |  |  |
| Host finds candidate |  |  |
| No download before consent |  |  |
| Download and signature verification |  |  |
| Install and replacement |  |  |
| Automatic relaunch and process path |  |  |
| MenuBarExtra returns |  |  |
| Candidate version/build in Settings |  |  |
| Candidate re-check reports no eligible update |  |  |
| ChatGPT session |  |  |
| Claude session |  |  |
| Grok session |  |  |
| Preferences and language |  |  |
| Launch at Login |  |  |
| Last-good usage where observable |  |  |
| Quit/relaunch and reboot if required |  |  |
| Signatures, Gatekeeper, mounts, and final identity |  |  |

## Optional diagnostics

- Capture sanitized Sparkle/Autoupdate logs around the check, replacement, and relaunch; remove account identifiers and all credentials.
- Record before/after process IDs, bundle paths, mounted-image lists, appcast response metadata, and provider refresh results.
- Investigate Tahoe/macOS 26 installation-cache or App Management errors without removing quarantine/provenance data or weakening OS protections.
- Run negative feed/download fixtures only on a restorable isolated snapshot. Do not modify the canonical staging DMGs or feed to create a failure case.

## Stop conditions and decision

Stop immediately if the test machine is not isolated, if production Build 4 is the installed app being replaced, if an artifact hash/signature differs, or if the app loses recoverability. Preserve the old host and snapshot; do not delete provider data to hide a failure.

**U1 remains `INCONCLUSIVE` until this gate is completed and reviewed. `DMG_ONLY` remains `CONDITIONAL_PENDING_HUMAN_GATE`.** This procedure does not authorize merging PR #35 or releasing Build 5/6. Production release tooling remains a MEDIUM gap: Build 5 still needs a human-approved expiration value and production-key custody/restore evidence, plus production notarization/stapling, final DMG and EdDSA signing, appcast publication/remote verification, exact-SHA CI, and the installed-host gates. `SUSignedFeedFailureExpirationInterval` for production remains `HUMAN_DECISION_REQUIRED`.
