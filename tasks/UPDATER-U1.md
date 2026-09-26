# AIUsageBar Updater — U1 Sparkle Integration Spike

## 1. Objective

Empirically prepare and verify the frozen updater architecture using the real AIUsageBar source and stock Sparkle 2.10.0. U1 is not the production updater, and no U2/U3/U4 work is authorized by this result.

**Current-machine boundary:** the user explicitly confirmed that no isolated VM/secondary Mac is available and prohibited touching the installed production Build 4. Therefore replacement, runtime relaunch, MenuBarExtra restoration and real-session preservation must remain **HUMAN_GATE_REQUIRED**. Preparing trustworthy staging artifacts is useful evidence but cannot satisfy the complete engine proof.

## 2. U0 Frozen Inputs

Read `tasks/UPDATER-U0.md` before edits. Retain Sparkle 2.10.0, static signed HTTPS appcast, version-addressed GitHub artifacts, no runtime GitHub API, Developer ID/Hardened Runtime, public EdDSA key, signed feed, pre-extraction verification, stock user driver, and unchanged application/storage identities. DMG_ONLY remains conditional.

The later U1 execution prompt expressly supersedes U0 in three areas: staging versions cannot consume production builds 5/6; production feed-expiration policy must be reviewed before shipping; no CI overhaul or production Settings/state implementation. U0 remains stored as the historical report rather than silently rewritten.

## 3. Grok Challenge Findings Incorporated

- HIGH-1: Final DMG notarization and stapling precede SHA-256/length and EdDSA signing. Recheck the same bytes before/after signing and after remote download.
- HIGH-2: Tahoe install-cache/App Management reports are investigated upstream, without disabling OS protections or claiming universal reliability.
- MEDIUM-1: Exact Sparkle 2.10.0 requirement and resolved revision; no downgrade to 2.9.6.
- MEDIUM-2: Default expiration 1,728,000 seconds; spike uses 0; production choice remains open.
- MEDIUM-3: `SPUStandardUpdaterController` with nil user-driver delegate uses the stock driver. No custom `SPUUserDriver`.
- MEDIUM-4: Only actual public HTTPS feed/enclosure fetches count as remote evidence; local signature fixtures are explicitly labeled.
- LOW: Repository project still requires macOS 13.0. Verify final bundle and generated appcast floor.

## 4. Repository Baseline

STARTING_MAIN_SHA: `40360b68aae6d558d64829997d1d6ed8ab59c77e`, verified against remote main before starting and again after resuming.

Approved Build 4 product source: `df65e6b9541721eefc7b18fb4365c12f7a2aa10a`. Later main commits affect tests/docs, not product code. Initial working tree: only the prior untracked `tasks/UPDATER-U0.md`; no tracked modifications. U0 had made no branch or commit.

Machine: macOS 26.5.2 (`25F84`), Xcode 26.6 (`17F113`). Distribution identity available: `Developer ID Application: Wei Kai Hung (S898B9KBWN)`. User-supplied Keychain notary profile `AIUsageBar-Notary` authenticated successfully. No credentials were read into reports or chat.

Read-only content hashes were recorded for the installed Build 4 app before U1 operations. No staging app is launched in this production user account; shared bundle/Keychain/WebKit identities make a renamed copy or custom TMPDIR insufficient isolation.

## 5. Branch / Git Boundary

Branch: `feature/in-app-updater-u0-u1`, created from current canonical main in the existing audit clone. No merge to main, production tag change, Build 4 release modification, or production release/feed publication is allowed.

Source commits retain the integration and reproducible staging tools. Host binary source: `0df57e6b59eee566aa305ff2e229998bbf276f02`; candidate binary source: `4fb083d3af2360b4a87d875cee55735473561a15`. Their app/project source is identical; intervening differences are staging script guards and removal of xcconfig version defaults. Embedded GitCommit metadata was read from both exported apps. Final branch SHA is recorded in completion output. Report-only follow-up commits do not imply that artifacts were built from a later documentation SHA.

## 6. Sparkle Integration

Project references the official Sparkle repository with `kind=exactVersion`, `version=2.10.0`. Official tag revision: `eef1a539a373c1f1a320624b1130fc5de7b2e100`. Official SPM ZIP SHA-256: `17e28312b8e18ab7cdbbe09a6fb28cc55a5479ec6c371dbc07cdecd2a14fd959`.

`UpdaterSpike` is an app-lifetime `@StateObject`, conditional on `AIUSAGEBAR_UPDATER_SPIKE`. It holds a stock controller and observes `canCheckForUpdates`; it does not change provider logic or create a second scheduler. A temporary menu-panel button invokes the stock UI. Test-process initialization does not start the updater. No production UpdateState, custom driver, final Settings layout, localization, analytics or retry policy was added.

The first archive exposed that arbitrary `INFOPLIST_KEY_SU*` build settings were not emitted into the generated plist. That archive was rejected before publication. An explicit staging `Staging-Info.plist` now supplies typed security/consent values and the public key, and verification reads the signed exported bundle. Archive-stage helper signatures are not distribution evidence: Xcode Developer ID export re-signs nested helpers; the exported host passed independent checks for every Mach-O.

The standalone controller type-check passed against official 2.10.0. The actual framework comparator passed 9001 < 9002, 9002 = 9002, and 9002 > 9001. These are API checks, not installed-host discovery evidence.

Official tooling archive size 16,319,840 bytes and SHA-256 `c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c` matched GitHub release metadata before execution.

## 7. Staging Architecture

Same real app name `AIUsageBar.app`, Bundle ID `synok522.AIUsageBar`, Team ID `S898B9KBWN`, non-sandboxed entitlement configuration, default WebKit store, Keychain service/account keys and standard UserDefaults domain.

Isolation comes from the source branch, staging-only public feed path, staging-only signing key, distinct versioned prerelease assets, and a required isolated runtime machine. The installed Build 4 is never used as a disposable host. Nothing makes existing Build 4 clients point at staging.

Staging endpoint: `https://synok522-del.github.io/AIUsageBar/staging/u1-20260915/appcast.xml`. Only staging content belongs in the separate Pages source branch. No root production appcast is created.

## 8. Version Strategy

| Role | Marketing version | CFBundleVersion |
| --- | --- | --- |
| Isolated staging host | 0.0.1 | 9001 |
| Isolated staging candidate | 0.0.2 | 9002 |

Production 1.0.0/4, 1.1.0/5 and 1.1.1/6 remain reserved and untouched. Never install these high-numbered staging builds on a production machine: returning to lower production numbering requires a manual install in an isolated test environment, not a Sparkle downgrade. Public filenames and release descriptions explicitly identify U1 staging.

## 9. Signing Architecture

Use archive/export with Developer ID, exact package, universal architectures, macOS 13 floor, and Hardened Runtime. Inspect every embedded Mach-O independently: app, framework, installer/progress helper, and XPC services. Verify symlinks and signatures after packaging as well as before.

Staging EdDSA account: `AIUsageBar-U1-Staging-20260915`, service `https://sparkle-project.org`, stored by official `generate_keys` in local Keychain. No private export was made. Public key: `UIXKYCVs01bngJO5Ot4tgSO3IU4wYSj6Se2h4GMQIF0=`. Production key generation/custody is a separate pre-release gate.

Native Sparkle rotation limits from U0 still apply: a valid EdDSA-authorized update is not an unconditional unchanged-Team-ID check. Tool verification does not establish stronger dual authorization. Do not mislabel intentional same-Team signed-DMG fallback as a bypass merely by changing an EdDSA attribute.

## 10. Notarization Evidence

| Role | App notary ID | DMG notary ID | Result |
| --- | --- | --- | --- |
| host | `935d6ac9-a167-4bcd-b0c9-005dce2d566b` | `0af7d339-e2f7-49af-bb5d-82ce8dc18495` | Accepted; both staples valid; Gatekeeper accepted |
| candidate | `605866d5-c8c6-4731-82fa-d8d09744327a` | `c27a572a-461a-423a-85ad-81e7bf9e1567` | Accepted; both staples valid; Gatekeeper accepted |

Both exported apps and both final DMGs passed Developer ID, deep/strict signatures, Hardened Runtime, notarization, staple validation and Gatekeeper. Each of six Mach-O components is universal and signed by Team S898B9KBWN after export.

## 11. DMG Creation

Use the existing `Packaging/create-dmg.sh` layout for both stages: one AIUsageBar.app, Applications shortcut and cosmetic background. Do not change production packaging unnecessarily. Read-only mounted-image inspection passed for both DMGs. Full file SHA-256, POSIX mode and symlink inventories match their canonical exported/stapled apps. One top-level AIUsageBar.app and the Applications shortcut were verified; no app was launched. Both images detached successfully. This is packaging inspection, not Sparkle installer execution.

## 12. EdDSA Ordering

`notarize-dmg.sh` requires staging versions, rejects `/Applications` input, notarizes/staples the app, creates/signs/notarizes/staples the DMG, and only then records final SHA-256 and length. EdDSA is a separate later step. No DMG may change after that step.

| Role | Final DMG bytes | SHA-256 |
| --- | ---: | --- |
| host | 4054775 | `5fa1da43179c54b597e1c15255417dbf395ecc047e0e03b383961c8b1cb2a3fd` |
| candidate | 4054794 | `3bfb0a8cf60b32dcb8b2a90173fd7f16a8a50cc19061b51188b56d0dd4edac17` |

Public signatures and full source/notary metadata are retained in `Packaging/UpdaterSpike/evidence/artifact-manifest.json` and the staging release asset. Both final DMGs retained their hashes after signing and matched independently downloaded remote bytes.

Local harmless payload and signed-feed fixtures were accepted by official signing tools and the separate public-key-only verifier. Equal-length tampering was rejected. This tests cryptographic verification, not installed-app failure recovery.

## 13. Public Staging Feed

Public endpoint returned HTTP 200, `application/xml`, Content-Length 2351, Cache-Control `max-age=600`, and byte-identical signed XML. Feed SHA-256: `1f8cf8bb27203853544a46dc13af500ab39a2cf88f025251f49fc62c3a8be48c`. Pages source is isolated branch `u1-staging-pages`, commit `b4f5465a00149cf7a143ff3743888ac874341657`; HTTPS enforced. Public staging release: https://github.com/synok522-del/AIUsageBar/releases/tag/u1-staging-20260915. No production root appcast exists.

Executed sequence: publish installer → independently download and verify bytes → generate/sign appcast → publish appcast last → independently fetch and verify feed and enclosure again. Both enclosure downloads before publication returned 200 and exact Content-Length (4054775 / 4054794). GitHub asset responses supplied ETag/Last-Modified and Age but no Cache-Control header. After public feed verification, both enclosure URLs were fetched again: HTTP 200, exact hashes/lengths and EdDSA PASS. Safe response metadata is retained without temporary redirect query credentials. Official `generate_appcast` produced two no-delta items with macOS 13.0 floor, correct builds/URLs/lengths and signatures. The final signed feed passed official and public-key verification; a tampered copy was rejected.

## 14. Update Discovery

Installed-host discovery: **HUMAN_GATE_REQUIRED**. A public XML fetch, parser check or comparator result must not be labeled as the stock host detecting the candidate. Human procedure records the exact host/candidate and same/lower behavior.

## 15. Download / Verification

Separate direct public artifact download/cryptographic checks from Sparkle's in-app download path. The latter remains **HUMAN_GATE_REQUIRED** on an isolated machine. No missing runtime evidence is converted to PASS.

## 16. Installation / Replacement

**HUMAN_GATE_REQUIRED.** User explicitly prohibits replacing this Mac's `/Applications/AIUsageBar.app`. No alternate-path copy counts as the authoritative replacement proof. The procedure must establish recovery on failure, correct payload selection, permissions, executable bits, framework symlinks, and no leftover mounts.

## 17. Relaunch / MenuBarExtra

**HUMAN_GATE_REQUIRED.** Observe old PID termination, new PID/path/version, return of MenuBarExtra, Settings showing 9002, no unexpected Dock icon, and functional usage refresh. Bundle copy, install notification or a relaunch request alone is insufficient.

## 18. Session/Data Preservation

**HUMAN_GATE_REQUIRED.** No runtime session claim is made. Source diff preserves all provider, storage, language, notification and login-service implementations. Isolated real-account testing must verify ChatGPT, Claude, Grok, Keychain, WebKit, UserDefaults, last-good state, language/preferences and Launch at Login. Record masked identity/status only, never cookies or tokens.

## 19. Failure Safety

Local cryptographic negative fixtures: PASS. Byte-corrupted copies of both final DMGs were rejected by the public-key verifier; original bytes were untouched. Installed-app feed-unavailable behavior, missing enclosure, interrupted download, failure recovery and failed relaunch: HUMAN_GATE_REQUIRED. The current app must remain operational; the spike must never equate a check failure with latest. No destructive failure test was run on production Build 4.

## 20. macOS 26 / Tahoe Status

The original issue was converted to upstream discussion #2881. Maintainer investigation reproduced a case with a Bundle ID ending in `.app`, and linked fix #2882; 2.9.3 release notes include that fix. Sparkle 2.10.0 includes additional handling for irregular bundle-like suffixes. AIUsageBar's identifier ends in `AIUsageBar`, not `.app`.

This narrows the specific report; it does not prove every Tahoe update succeeds or validate all original claims about provenance. Do not patch Sparkle, remove xattrs or weaken macOS protections speculatively. This Mac runs Tahoe, but there is no safe isolated replacement environment. **TAHOE_GATE: HUMAN_GATE_REQUIRED.**

Sources: [upstream discussion](https://github.com/sparkle-project/Sparkle/discussions/2881), [2.10.0 release](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0).

## 21. Signed Feed Expiration Policy

CURRENT_DEFAULT: **1728000 seconds (20 days)**.

Pinned `SUAppcastDriver.m` defines that default. On signature failure, it records the first failure date; after the configured interval it may allow limited recovery. Zero disallows that expiration path. This is a signing-failure recovery timer, not a guarantee of feed freshness.

Spike configuration: **0**, to keep negative fixtures fail-closed. **PRODUCTION_DECISION_REQUIRED: YES.** The U1 prompt reopens U0's production choice; decide default vs zero vs justified alternative before 1.1.0 ships, with key-loss recovery and custody reviewed.

Source: [pinned driver](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Sparkle/SUAppcastDriver.m).

## 22. DMG vs ZIP Decision

**DMG_ONLY_DECISION: INCONCLUSIVE.** Native DMG support and artifact preparation do not meet the complete freeze gate. No DMG-specific runtime failure has been demonstrated; a ZIP comparison would not resolve the absence of an isolated test machine. **ZIP_FALLBACK_REQUIRED: UNRESOLVED.**

## 23. Findings

- **BLOCKER to full empirical PASS:** isolated `/Applications` replacement/relaunch/MenuBarExtra proof is unavailable. This is missing evidence, not a discovered Sparkle defect.
- **HIGH production gate:** real-session preservation and representative supported-OS/CPU runtime checks remain unproven.
- **MEDIUM production gate:** signed-feed expiration/custody decision remains open.
- **LOW, corrected before publication:** generated Info.plist omitted custom Sparkle keys, xcconfig defaults overrode candidate numbering, and a shell signature guard could exit on SIGPIPE. Explicit typed plist, exported-version assertions, and a non-early-closing check resolve these; rejected outputs were never published.
- **MEDIUM evidence limit:** Tahoe upstream context narrows the known issue but does not replace an application-specific test.

## 24. Changed Files

Integration: project package reference/staging version defaults, app-lifetime spike hook, and `AIUsageBar/Updater/UpdaterSpike.swift`.

Spike-only tools: `Packaging/UpdaterSpike/` configuration, export options, build/notarize scripts, public-key-only verifier, version-comparison check, public fetch evidence tool, public key and human procedure. Reports: U0 preserved and U1 added. No provider/session implementation, production Settings/state layer, CI workflow or production release script is refactored.

## 25. Machine Evidence

Statuses below distinguish tool-level evidence from actual installed-host behavior. Human-gated items were not executed; they are not PASS.

| Item | Status | Evidence / scope |
| --- | --- | --- |
| Starting main SHA | PASS | 40360b68aae6d558d64829997d1d6ed8ab59c77e |
| Branch | PASS | feature/in-app-updater-u0-u1, isolated and pushed |
| Final HEAD | PASS | Final commit SHA recorded in completion evidence (a report cannot embed its own commit hash) |
| Clean tree | PASS | Verified after final commit; see completion evidence |
| Scope audit | PASS | App diff limited to stock spike; provider/storage identities unchanged |
| Sparkle 2.10.0 pinned | PASS | Actual SwiftPM state revision eef1a539a373c1f1a320624b1130fc5de7b2e100 and binary checksum match |
| Release build | PASS | Release compilation and archive succeeded for both stages |
| Release archive/export | PASS | Both exported versions checked from Info.plist |
| Universal arm64 | PASS | All six Mach-O components |
| Universal x86_64 | PASS | All six Mach-O components |
| Developer ID | PASS | Exported apps and DMGs |
| Deep codesign | PASS | Exported and mounted apps |
| Hardened Runtime | PASS | Each Mach-O signature |
| Nested Sparkle components | PASS | App, Sparkle, Autoupdate, Updater, Installer XPC, Downloader XPC |
| Notarization | PASS | Four Accepted submissions, IDs in §10 |
| Staple | PASS | Apps and DMGs; mounted app tickets retained |
| Gatekeeper | PASS | Apps execute assessment and DMGs primary-signature assessment |
| Final DMG SHA-256 | PASS | §12 and artifact manifest |
| Final DMG size | PASS | Host 4054775; candidate 4054794 bytes |
| EdDSA-after-staple | PASS | Staple finished before signatures; hashes unchanged afterward |
| Public staging feed reachable | PASS | Actual public HTTPS response 200, exact signed bytes |
| Remote enclosure reachable | PASS | Both public unauthenticated HTTPS downloads returned 200 |
| Remote enclosure bytes verified | PASS | SHA-256, length and public-key EdDSA match |
| Signed feed verification | PASS | Official tool + independent verifier; public bytes match |
| Update discovery | HUMAN_GATE_REQUIRED | No staging host launched on production account |
| Newer-version comparison | PASS | Official comparator API: 9001 < 9002; installed discovery remains human-gated |
| Same/lower-version behavior | HUMAN_GATE_REQUIRED | Comparator equality/lower API passed; installed selection untested |
| DMG download | PASS | Direct public HTTPS download only; in-app Sparkle download human-gated |
| EdDSA verification | PASS | Both actual final/remote DMGs; official and independent verifier |
| Developer ID identity | PASS | Expected distribution certificate |
| Team identity | PASS | S898B9KBWN on all exported code |
| Bundle identity | PASS | synok522.AIUsageBar |
| DMG extraction | HUMAN_GATE_REQUIRED | Manual read-only mount inspection passed; stock extraction untested |
| Replacement | HUMAN_GATE_REQUIRED | /Applications production app untouched |
| Relaunch | HUMAN_GATE_REQUIRED | New PID/path not tested |
| MenuBarExtra return | HUMAN_GATE_REQUIRED | Runtime gate |
| Settings new version | HUMAN_GATE_REQUIRED | Bundle metadata checked, UI not launched |
| Usage refresh | HUMAN_GATE_REQUIRED | No production account runtime test |
| Stale mount check | PASS | Packaging/inspection mounts detached; updater cleanup remains human-gated |
| Feed unavailable safety | HUMAN_GATE_REQUIRED | Installed host error handling not tested |
| Bad feed signature | PASS | Local signed fixture tampering rejected; host rejection human-gated |
| Bad enclosure signature | PASS | Corrupted copies of both final DMGs rejected; host recovery human-gated |
| Failed download safety | HUMAN_GATE_REQUIRED | Current-app recoverability not tested |
| ChatGPT session | HUMAN_GATE_REQUIRED | No session data read or modified |
| Claude session | HUMAN_GATE_REQUIRED | Same |
| Grok session | HUMAN_GATE_REQUIRED | Same |
| Preferences | HUMAN_GATE_REQUIRED | Source identity preserved; runtime not tested |
| UserDefaults | HUMAN_GATE_REQUIRED | Same |
| Last-good | HUMAN_GATE_REQUIRED | Same |
| Launch at Login | HUMAN_GATE_REQUIRED | Same |
| Keychain / WebKit | HUMAN_GATE_REQUIRED | Same |
| Tahoe compatibility | HUMAN_GATE_REQUIRED | Release tools worked on 26.5.2; stock installation not tested |
| Installed Build 4 preservation | PASS | All ten bundle file-content hashes equal pre-U1 baseline |

Machine-readable evidence is in `Packaging/UpdaterSpike/evidence/`. No private keys, credentials, cookies or session snapshots are included.

## 26. Remaining Human Gates

Run `Packaging/UpdaterSpike/HUMAN-TEST.md` only in a disposable VM or separate test Mac with snapshots. Test stock discovery through full replacement/relaunch/menu-bar return and data preservation. Do not run it on this production Mac. The procedure contains failure cases and Tahoe-specific observations.

## 27. Final Verdict

**U1_STATUS: INCONCLUSIVE. DMG_ONLY_DECISION: INCONCLUSIVE. ZIP_FALLBACK_REQUIRED: UNRESOLVED. CAN_PROCEED_TO_U2: NO.**

Release artifacts and the public signed feed are prepared and verified. Full engine proof remains blocked by the lack of an isolated macOS installation environment. Replacement, relaunch, MenuBarExtra, runtime failure safety and session preservation are HUMAN_GATE_REQUIRED. No U2 work was started.

CI: the repository still reports registered workflow `AIUsageBar macOS CI` (356462309), but `.github/workflows/macos-ci.yml` is absent from this branch/main. No workflow was created or weakened. An exact-final-SHA check is recorded in the completion evidence; do not infer product CI success from the separate Pages deployment.
