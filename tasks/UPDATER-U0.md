# AIUsageBar Updater — U0 Architecture Freeze

Audit date: 2026-09-15 (Asia/Shanghai). Scope: architecture only. **U0_STATUS: FROZEN. CAN_START_U1: YES.** No updater implementation, production key generation, build, signing, notarization, release modification, or publication was performed.

Classification applies to each decision: **FROZEN** = binding U1 requirement; **CONDITIONAL** = candidate requiring stated proof; **DEFERRED** = outside V1 scope; **REJECTED** = must not use. Observations are evidence, not claims that unimplemented release gates already pass.

This report is delivered at `tasks/UPDATER-U0.md` in the fresh canonical-repository audit clone and as an identical output copy. The existing local checkouts were inspected without modification. No commit or push was made.

## 1. Repository Baseline

### Verified source and working trees

| Item | Observed evidence | Classification / consequence |
| --- | --- | --- |
| Canonical repository | `synok522-del/AIUsageBar`; default branch `main` | FROZEN: source authority |
| Current remote main | `40360b68aae6d558d64829997d1d6ed8ab59c77e`, commit date `2026-09-13T06:33:45Z`, “docs: publish final release download links” | FROZEN: audit baseline |
| Approved binary source | `df65e6b9541721eefc7b18fb4365c12f7a2aa10a` | FROZEN: Build 4 provenance |
| Production differences | Comparing approved SHA to current main changes six files: one localization test and five documentation/report files; no app source, project, entitlements, or packaging change | FROZEN: do not confuse documentation HEAD with binary source |
| Existing checkout A | `/Users/kennyhung/Documents/AIUsageBar-Github`, HEAD `388f944bbb836e3366a8e1b0b408fcc9fa98a855`, clean | FROZEN: stale local copy, not current-main evidence |
| Existing checkout B | `/Users/kennyhung/Documents/AIUsageBar`, HEAD `97b2b04495ac7304b180d39a70a81f1111624785`, clean | FROZEN: stale local copy, not current-main evidence |
| Fresh audit clone | `work/AIUsageBar`, HEAD equals current remote main; clean before this report | FROZEN: inspected current source; only this report added |
| Repository instructions | No tracked `AGENTS.md` found in current-main tree | Observation |

Source evidence: [pinned source tree](https://github.com/synok522-del/AIUsageBar/tree/40360b68aae6d558d64829997d1d6ed8ab59c77e), [baseline comparison](https://github.com/synok522-del/AIUsageBar/compare/df65e6b9541721eefc7b18fb4365c12f7a2aa10a...40360b68aae6d558d64829997d1d6ed8ab59c77e). Remote SHA was checked with both Git and GitHub API; a downloaded source snapshot was also inspected.

### App and release configuration

| Item | Verified value / qualification | Decision |
| --- | --- | --- |
| Bundle identifier | `synok522.AIUsageBar` | FROZEN: preserve |
| Marketing/build | `1.0.0` / `4`, both app configurations; generated Info.plist | FROZEN: Build 4 untouched |
| Team ID | `S898B9KBWN`, independently read from installed Build 4 signature | FROZEN: normal-release continuity |
| Distribution identity | `Developer ID Application: Wei Kai Hung (S898B9KBWN)` | FROZEN: normal-release identity |
| Project signing | `CODE_SIGN_STYLE=Automatic`; entitlements path configured; no committed `DEVELOPMENT_TEAM` or explicit Developer ID identity | FROZEN: future release process must supply and verify distribution configuration; project alone does not establish it |
| Minimum macOS | Project and installed app: `13.0` | FROZEN: keep 13.0 for Builds 5/6 |
| Architectures | Installed app is universal `x86_64 arm64`; project has no explicit ARCHS override, Debug has `ONLY_ACTIVE_ARCH=YES` | FROZEN: release app and nested Sparkle binaries must support both; no assumption from a host-only Debug build |
| App Sandbox | `ENABLE_APP_SANDBOX=NO`; entitlement file is an empty dictionary | FROZEN: remain non-sandboxed |
| Hardened Runtime | Release `ENABLE_HARDENED_RUNTIME=YES`; installed signature has `runtime` flag | FROZEN: preserve; no Release library-validation exception |
| App architecture | SwiftUI `MenuBarExtra`, `.window` style; `LSUIElement=YES`; app-level view model and window coordinator | FROZEN: retain dockless/menu-bar behavior |
| Dependencies | Xcode project; empty package-product dependency lists; no tracked Package.swift, Package.resolved, or xcconfig | FROZEN: introduce only pinned Sparkle through SwiftPM in U1 |
| Settings footer | Reads bundle version/build; localized `L10n.version`; optional seven-character `GitCommit.plist` metadata; Quit button; no updater controls | FROZEN: preserve footer provenance; add distinct update controls later |

Evidence: [project configuration](https://github.com/synok522-del/AIUsageBar/blob/40360b68aae6d558d64829997d1d6ed8ab59c77e/AIUsageBar.xcodeproj/project.pbxproj), [entitlements](https://github.com/synok522-del/AIUsageBar/blob/40360b68aae6d558d64829997d1d6ed8ab59c77e/AIUsageBar/AIUsageBar.entitlements), [app lifecycle](https://github.com/synok522-del/AIUsageBar/blob/40360b68aae6d558d64829997d1d6ed8ab59c77e/AIUsageBar/App/AIUsageBarApp.swift), [Settings](https://github.com/synok522-del/AIUsageBar/blob/40360b68aae6d558d64829997d1d6ed8ab59c77e/AIUsageBar/Views/SettingsView.swift).

Read-only verification of `/Applications/AIUsageBar.app`: version `1.0.0`, build `4`, GitCommit `df65e6b`, minimum OS `13.0`; `codesign --verify --deep --strict` passed; Gatekeeper accepted with `source=Notarized Developer ID`; `stapler validate` passed. Its designated requirement includes the bundle ID and Team ID. Initial sandbox-limited inspection could not resolve certificate authority and produced misleading signature metadata; unrestricted read-only verification resolved that limitation. This establishes the installed app's status, not byte-for-byte identity with a freshly downloaded public DMG. No release artifact was modified or rebuilt.

### Build, hosting, and workflow inventory

- **FROZEN:** Existing `Packaging/create-dmg.sh` is layout-only. It uses `ditto --norsrc --noextattr`, an `/Applications` symlink, generated background, AppleScript Finder layout, HFS+ read/write image, and UDZO/zlib conversion. It does not sign or notarize. Future packaging must prove it preserves nested framework symlinks, signatures, permissions, and stapled tickets.
- **FROZEN:** The Xcode shell phase writes seven-character GitCommit metadata before final signing. No complete checked-in archive/export/notarize/release workflow exists on main.
- **FROZEN:** GitHub reports registered workflow `AIUsageBar macOS CI` (`.github/workflows/macos-ci.yml`, ID `356462309`, state active), but the current-main recursive tree lacks `.github` and the contents endpoint returns 404. Registration is not evidence of usable CI on main. Restore a reviewed future-version workflow before release qualification.
- **FROZEN:** `docs/intro.md` and image assets exist. GitHub repository metadata says `has_pages=false`, `homepage=null`; Pages endpoint returns 404. No tracked Pages workflow, CNAME, Jekyll configuration, or appcast exists. Pages must be provisioned in U1; it is not live today.
- **FROZEN:** Public `v1.0.0` has one manually uploaded installer, `AIUsageBar-1.0.0-build4.dmg`, 3,142,099 bytes, SHA-256 `49d4ecc16ea149d8d05e780cd9512ecaba2bbd49a6c118dfc1250c55ff4e3415`. GitHub reports `immutable=false`. Earlier beta.1/build2 and beta.2/build3 releases remain present. GitHub-generated source archives are not installers.
- **REJECTED:** Retroactively changing release immutability, assets, tag, notes, or Build 4 during U0. Future artifact immutability is a new-release requirement.

Evidence: [packaging script](https://github.com/synok522-del/AIUsageBar/blob/40360b68aae6d558d64829997d1d6ed8ab59c77e/Packaging/create-dmg.sh), [current release](https://github.com/synok522-del/AIUsageBar/releases/tag/v1.0.0), [repository metadata API](https://api.github.com/repos/synok522-del/AIUsageBar), [workflow inventory API](https://api.github.com/repos/synok522-del/AIUsageBar/actions/workflows).

## 2. Official Sparkle Verification

**FROZEN: Sparkle 2.10.0**, exact SwiftPM version, not a floating range or prerelease. Live GitHub `/releases/latest` returned `2.10.0`, `prerelease=false`, published `2026-09-13T23:54:06Z`; the explicit official release page agrees. It requires macOS 12+, compatible with AIUsageBar's macOS 13 floor. Search results still naming 2.9.6 as latest were stale. [Official 2.10.0 release](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0).

**FROZEN:** Its package uses Swift tools 5.5, a binary target, and `.macOS(.v12)`. The official SPM archive checksum is `17e28312b8e18ab7cdbbe09a6fb28cc55a5479ec6c371dbc07cdecd2a14fd959`. Commit the resolved dependency in U1 and retain matching release tools. [Exact package manifest](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Package.swift).

| Verified capability | U0 disposition |
| --- | --- |
| Developer ID, outside Mac App Store, non-sandboxed app | FROZEN: supported deployment model; preserve Hardened Runtime and correct nested signing |
| SwiftUI setup | FROZEN: one long-lived `SPUStandardUpdaterController`, owned independently of transient menu content, operating on main thread |
| `SPUUpdater` | FROZEN: controller's update engine/scheduler and settings API; no second updater |
| `SPUUserDriver` | DEFERRED: custom presentation protocol; do not build a custom updater UI engine for V1 |
| LSUIElement | CONDITIONAL: standard driver selected; U1 must prove foreground alerts and relaunch without a persistent Dock icon |
| `SUEnableInstallerLauncherService` | REJECTED: do not enable for this non-sandboxed app |
| `SUPublicEDKey`, `SUFeedURL` | FROZEN: embed public key and stable HTTPS appcast URL in signed app |
| EdDSA archive signing | FROZEN: sign exact final installer bytes |
| Feed signing | FROZEN: `SURequireSignedFeed=YES`; supported since 2.9; sign notes as well, or embed notes |
| Pre-extraction validation | FROZEN: `SUVerifyUpdateBeforeExtraction=YES` |
| Feed signature failure expiration | FROZEN: `SUSignedFeedFailureExpirationInterval=0`; never age into accepting an unverified feed |

Official setup supports Developer ID and notarized distribution, with correct framework embedding and signing. Sandboxed apps have extra requirements that do not apply here. Archive/export through Xcode is the preferred way to sign helper components. [Setup](https://sparkle-project.org/documentation/).

The three security options above are deliberate choices rather than defaults. A non-sandboxed app must not enable the installer-launcher XPC service. [Configuration reference](https://sparkle-project.org/documentation/customization/).

The controller supplies the standard user driver and owns an updater. Bind manual checking availability to its updater, keep it alive for the app lifetime, and avoid reinitializing it when the menu closes. [Controller API](https://sparkle-project.org/documentation/api-reference/Classes/SPUStandardUpdaterController.html), [programmatic setup](https://sparkle-project.org/documentation/programmatic-setup/). A custom `SPUUserDriver` must implement the entire presentation/reply contract; this extra responsibility is unnecessary for V1. [User-driver API](https://sparkle-project.org/documentation/api-reference/Protocols/SPUUserDriver.html).

**FROZEN / format verification:** Sparkle supports DMG, ZIP, tar archives, Apple Archives, and installer packages. For this app use a regular `.app` enclosure, never a package installer. `generate_appcast` generates metadata/signatures and can generate deltas; disable delta production for V1. `sign_update` signs archives and can sign the completed appcast; edits require re-signing. APFS/LZFSE is the documented DMG recommendation, not an architecture prerequisite. [Publishing](https://sparkle-project.org/documentation/publishing/).

**DEFERRED / verified advanced capabilities:** Channels use `sparkle:channel` and allowed-channel selection; the default channel remains included. Phased rollout uses publication time and intervals over seven groups; manual checks and critical updates bypass it. Critical updates remove skipping, not user installation consent. `minimumAutoupdateVersion` controls unattended major-upgrade eligibility, not a hard minimum source version. `minimumUpdateVersion` is the 2.9+ hard source-version filter. No channels, phases, critical flags, or special minimum-update rules are needed for the initial proof. [Publishing](https://sparkle-project.org/documentation/publishing/), [appcast item API](https://sparkle-project.org/documentation/api-reference/Classes/SUAppcastItem.html).

**FROZEN / network and lifecycle:** Sparkle schedules future checks after normal driver completion; configuration failures may stop scheduling. Retain its scheduler, expose manual retry, and do not add a competing timer or promise a particular immediate retry/backoff/resume behavior. Validate network interruptions in U1. [2.10.0 scheduler source](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Sparkle/SPUUpdater.m). Sparkle handles extraction, installation and relaunch; app-specific crash recovery or guaranteed rollback after first launch is not established by this API. **REJECTED:** claims of guaranteed recovery under power loss. **CONDITIONAL:** real app replacement/relaunch proof in U1.

**FROZEN / replacement verification:** The 2.10.0 plain installer first attempts a safe atomic swap when eligible. Its fallback moves the old app aside, moves the new app into place, and attempts to restore the old app if that move fails. This is best-effort installation recovery, not a postlaunch health rollback. The installer coordinates host termination and asks its agent to relaunch only when requested. U1 must observe the new process, not infer it from a completed copy. [Plain installer source](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Autoupdate/SUPlainInstaller.m), [installer/relaunch coordination](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Autoupdate/AppInstaller.m).

### Incorrect or outdated assumptions explicitly rejected

- **REJECTED:** “Sparkle cannot sign feeds” or “2.9.6 is current stable.” Signed feeds exist; 2.10.0 is now stable.
- **REJECTED:** “DMG isn't a native Sparkle enclosure” or “ZIP is mandatory.”
- **REJECTED:** “Hardened Runtime requires disabling Release library validation.” Proper Developer ID signing is the distribution path.
- **REJECTED:** “Both unchanged signing identities are always required by Sparkle.” Native key rotation permits alternative trust paths; see §4.
- **REJECTED:** “Setting automatic downloads false by default prevents future opt-in.” Disallow automatic updates explicitly.
- **REJECTED:** “A completed check, nil error, or a last-check timestamp means latest.” See §8.
- **REJECTED:** “A GitHub Release is inherently immutable” or “docs means Pages is enabled.” Live repository evidence disproves both here.
- **REJECTED:** “Build 4 can receive Sparkle through its nonexistent updater.” Users must manually install Build 5.

## 3. Architecture

- **FROZEN:** Official Sparkle 2.10.0 binary package plus standard controller/user driver; thin AIUsageBar settings/state adapter only. No custom downloader, extractor, privileged helper, app-copy engine, or relaunch script.
- **FROZEN:** Keep updater ownership at app lifecycle scope, not in `MenuBarExtra` content. Invoke APIs on the main thread. Manual “Check for Updates…” is separate from provider “Refresh usage.”
- **FROZEN:** Self-update only `AIUsageBar.app`, preserving the installed destination and stable app name. The enclosure must contain one unambiguous app payload. `/Applications` shortcut and cosmetic DMG assets are not additional install targets.
- **FROZEN:** No automatic self-relocation from a mounted installer. Explain installation into Applications if the current app is read-only/translocated; do not imply update success. Standard background UI may suppress non-installable cases, so test manual checking specifically.
- **CONDITIONAL:** Standard UI activation and optional gentle reminder handling must work for this window-style MenuBarExtra. Minimal standard-driver delegation is allowed if needed; a replacement user driver requires architecture review. [Gentle reminders](https://sparkle-project.org/documentation/gentle-reminders/).
- **DEFERRED:** Windows updater technology. Share the release discipline and product naming principle, not Sparkle or macOS feed contents.

## 4. Security / Trust Model

### Trust boundaries

**FROZEN:** Use signed feed metadata and signed artifact bytes under the embedded Ed25519 public key, HTTPS transport, and Developer ID signed/notarized app distribution. Keep Team ID `S898B9KBWN` and bundle ID `synok522.AIUsageBar` continuous in all ordinary releases. Release gates must verify those identities on the app inside the final downloaded installer.

**FROZEN: native Sparkle trust, with an explicit limitation.** This is layered assurance, not two independent signatures whose original identities must both remain unchanged. Exact 2.10.0 `SUUpdateValidator` source shows that after EdDSA prevalidation, Sparkle validates code-signature integrity and basic signing continuity, but does not unconditionally require the old Developer ID designated requirement. In other paths it permits one validation method to succeed for rotation. A valid EdDSA signature therefore must be treated as code-release authority, not as harmless metadata authority. [Validator source](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Sparkle/SUUpdateValidator.m).

Developer ID comparison can use the old app's designated requirement. Pre-extraction fallback for a DMG constructs a Developer ID requirement with the old Team ID. This fallback differs from unconditional Team ID pinning of every EdDSA-authorized update. [Code-signature verifier](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Autoupdate/SUCodeSigningVerifier.m).

**REJECTED:** Marketing this design as surviving arbitrary EdDSA-key compromise because “Apple signing is the second mandatory key.” **DEFERRED:** Custom client-side strict dual authorization. It would change native rotation/recovery semantics and require a separate audited design, not an improvised delegate check in U1. Ordinary-release Team/Bundle continuity is binding release policy, with adversarial behavior documented as a limitation rather than overstated as a native runtime pin.

### Threat review

| Threat | Frozen response / residual risk |
| --- | --- |
| Pages compromise | Unsigned/modified feeds fail closed indefinitely. Attacker can deny service or replay a genuinely signed feed; signatures do not prove freshness. |
| Releases compromise | Modified bytes fail signature validation. Deletion causes unavailable update. A previously signed artifact can be replayed only within the eligibility permitted by authenticated metadata and version selection. |
| EdDSA private key compromise | Treat as a release-signing incident. With feed/hosting control, attacker can authorize malicious updates through native rotation semantics; do not rely on unchanged Team ID being enforced in that path. |
| Developer ID compromise alone | Does not authorize a changed feed under our non-expiring signed-feed requirement. Compromised certificate still endangers manual distribution and native archive fallback; revoke/recover through Apple and a reviewed incident plan. |
| Both keys or release workstation compromised | No cryptographic separation can rescue that release authority. Stop publication, recover on a clean machine, communicate through independent channels. |
| Downgrade | Monotonic build numbers; no custom comparator or older-item selection; reject mismatches in publication gates. Recovery is a higher-numbered corrective release. |
| Replay/old-release/freeze attack | Old signed feed may suppress a newer release or offer a legitimate intermediate build newer than the installed build. No trusted freshness guarantee is claimed. Monitor deployed feed externally; describe results as eligible updates in the checked feed. |
| Malformed appcast / HTML error page | Parse or signature failure is an error, never latest. Reject unsafe metadata before publication; keep notes simple and JavaScript disabled. |
| Incorrect artifact / ID / architecture / version | Bind generated metadata to final bytes; verify identity, app name, both CPU slices, OS floor, signature, length, build and hash before feed publication. Wrong signed artifact is still a release-authority failure, so U1 includes deliberate negative fixtures. |
| Interrupted download | Do not install partial/unverified content; show failure or cancellation; retry via Sparkle. No provider state reset. |
| Interrupted install / insufficient space / denied authorization | Surface failure, preserve recoverability; do not promise atomicity under all filesystem/power failures. U1 must demonstrate safe outcomes. |
| Failed relaunch | Do not report installation-and-relaunch success before observing new build running. Manual recovery installs a trusted signed app without deleting user data. |

### Key custody and recovery

- **FROZEN:** No production key is needed or generated in U0. U1 must first establish a named release operator and restore-tested custody.
- **FROZEN:** Keep the Sparkle private key in the release operator's local macOS Keychain. Keep an encrypted export on offline storage and a second independent encrypted backup in a separate physical location/account. Encryption recovery material must not be stored alongside its only backup.
- **FROZEN:** Verify restore on a clean isolated account/machine: import securely, compare the public key, sign a harmless fixture, and verify with the expected public key. Retain only public fingerprints and pass/fail evidence. Do not display exported private content or place it in command-line arguments/logs.
- **FROZEN:** Keep Developer ID keys and notarization credentials out of the app and repository. Separate hosting credentials from signing custody; an automatic Pages deployment only receives already-signed public files. Restrict any future publishing token to its task; no write token on clients.
- **FROZEN:** Never embed EdDSA private keys, Developer ID private keys, Apple notarization credentials, GitHub write tokens/PATs, or app-specific passwords in the product, reports, Git, logs, or chat.
- **FROZEN:** Prefer backup restore over rotation. Planned EdDSA rotation must serve a bridge feed signed for existing clients, retain old-client access, and test the signed-DMG fallback/new-key continuity before publication. Never change both trust roots in one step.
- **FROZEN:** With `SUSignedFeedFailureExpirationInterval=0`, losing all copies of the old feed key may strand existing clients even when a Developer ID DMG could validate. Recovery then requires an independently verified manual installer. This availability tradeoff is intentional. A compromised key requires a reviewed incident procedure; rotation cannot retroactively make already-authorized malicious updates safe.

## 5. Feed Architecture

| Option | Decision | Reason |
| --- | --- | --- |
| GitHub Releases API directly | REJECTED | Requires bespoke eligibility/parsing/rate-limit handling and duplicates Sparkle appcast behavior; no demonstrated benefit |
| GitHub Pages static signed appcast | FROZEN | Small auditable eligibility surface; public HTTPS reads; no client token or runtime GitHub API dependency |
| Other static HTTPS host | CONDITIONAL fallback | Allowed if Pages cannot deliver exact signed bytes reliably; determine URL before Build 5 signing |
| Dynamic updater service / custom server | DEFERRED | No current authentication, licensing, or targeting requirement justifies it |

**FROZEN:** Pages is the eligibility authority; GitHub Releases hosts version-addressed installer bytes. The runtime client does not call GitHub Releases API. Audit/release tooling may use that API.

**CONDITIONAL:** Candidate production URL: `https://synok522-del.github.io/AIUsageBar/appcast.xml`. It is not operational today. U1 must enable Pages, choose/review the deployment source, enforce HTTPS, and prove byte-for-byte preservation after deployment. Embed the final URL before signing Build 5; no mutable “latest” artifact redirect.

**FROZEN:** Publish the completed signed XML as a static file, without Jekyll/template/XML reformatting after signing. Prefer embedded plain-text release notes. Deploy related signed content together; retain known-good signed feed history. Restrict repository/Pages administration and protect publication branches. HTTPS is transport protection, not a substitute for signing.

## 6. Artifact Strategy

**CONDITIONAL: DMG_ONLY, CONDITIONAL_PENDING_U1.** Candidate names: `AIUsageBar-1.1.0.dmg`, `AIUsageBar-1.1.1.dmg`; one immutable public installer per macOS version. Never reuse a marketing version/filename for different bytes. Preserve Build 4's existing filename.

| Dimension | A: DMG for humans and Sparkle | B: human DMG + updater ZIP |
| --- | --- | --- |
| Native support | Supported | Both supported |
| Authenticity | Final DMG EdDSA signature; signed/notarized app; Developer ID-sign DMG too | Each enclosure separately signed; same canonical signed app |
| Extraction | Sparkle mounts and copies from image, then detaches | ZIP extraction avoids volume mount/unmount |
| Installation | Same bundle-replacement engine after extraction | Same bundle-replacement engine after extraction |
| Reliability surface | Adds DiskImages/mount permission/cleanup failure modes | Removes mount path for updater, but introduces second packaging path |
| Provenance/human error | One URL/hash/signature/payload to release and audit | Two hashes/signatures; risk of stale or differently built ZIP |
| Notarization | Staple canonical app and final DMG | Staple app before both containers; ZIP itself is not a stapling target |
| Recovery/rotation | Signed-DMG fallback compatible with pre-extraction validation | ZIP cannot provide Developer ID-signed-container fallback; emergency DMG may still be required |
| Rollback | No guaranteed postlaunch rollback | No guaranteed postlaunch rollback |
| Automation/maintenance | One tested packaging path; existing Finder script requires GUI access | Extra ZIP creation/verification and enclosure selection; simpler updater extraction |
| Public installer count | 1 macOS installer | 2 macOS installers |
| Windows roadmap | Supports one-artifact-per-platform discipline | Adds macOS-specific exception; no technical impact on Windows updater choice |

The mount/unmount surface is confirmed in [2.10.0 DMG unarchiver](https://github.com/sparkle-project/Sparkle/blob/2.10.0/Autoupdate/SUDiskImageUnarchiver.m): it invokes `hdiutil`, copies content, and attempts forced detach; detach failure is logged. These are real test obligations, not a reason to claim DMG inherently insecure.

**FROZEN:** Do not publish deltas in V1. Internal archives, dSYMs, checksums, feed files, and notarization submissions are release evidence, not extra canonical installers.

**CONDITIONAL fallback:** Adopt DMG_PLUS_ZIP only if U1 shows material recurring DMG extraction, cleanup, permissions, or automation problems. Both must wrap the same already-signed/stapled app; never build or re-sign separate app payloads for each container. Re-run proof through the selected ZIP enclosure before shipping.

## 7. Versioning

**FROZEN:** `CFBundleVersion` is a globally monotonically increasing integer across all distributed builds/channels; `sparkle:version` equals it. `CFBundleShortVersionString` and `sparkle:shortVersionString` are the human version. Do not use Git SHAs or lexical marketing-version ordering. [Appcast version API](https://sparkle-project.org/documentation/api-reference/Classes/SUAppcastItem.html).

| Release | Marketing version | Build | Delivery |
| --- | --- | --- | --- |
| Frozen existing release | 1.0.0 | 4 | Existing installer unchanged |
| First updater-enabled release | 1.1.0 | 5 | Manual installation; updater bootstrapped here |
| First updater proof release | 1.1.1 | 6 | Real Sparkle update from Build 5 |

**FROZEN:** Every published build number identifies one immutable payload. U1 fixtures must not pollute production feeds or reuse public build numbers for changed bytes. A rollback release uses a new higher build. Builds 5/6 remain reserved for the intended release sequence.

## 8. Consent Policy

**FROZEN:** Defaults in Info.plist: `SUEnableAutomaticChecks=YES`, `SUAutomaticallyUpdate=NO`, `SUAllowsAutomaticUpdates=NO`. Leave profiling and release-notes JavaScript disabled. This enables checks while disallowing automatic download/install opt-in. Default schedule: once daily; user may disable automatic checks. Installation must follow an explicit user action for that update. [Configuration reference](https://sparkle-project.org/documentation/customization/).

**FROZEN:** Use `automaticallyChecksForUpdates` for user setting changes; do not overwrite preferences at every launch. Use `canCheckForUpdates` for button availability. `automaticallyDownloadsUpdates` stays false when automatic updates are disallowed. A manual check is not installation consent. Do not add an install-on-quit delegate to bypass consent. [Updater API](https://sparkle-project.org/documentation/api-reference/Classes/SPUUpdater.html).

### Failure honesty

**FROZEN: CHECK FAILED ≠ LATEST.** Distinguish idle/unknown, checking, available, no eligible update found, failed, canceled, downloading, installing, and relaunch pending. “No eligible update found” is more accurate than a universal “latest” claim under channel/OS/replay constraints.

**FROZEN:** A last-check timestamp is not proof of success. Nil completion error can follow dismissing/skipping an update. `SUNoUpdateError` is a special result; network, parsing, feed signature, archive validation, disk and launch errors remain errors. Use delegate completion and no-update reason information; do not collapse all aborts into no-update. [Updater delegate](https://sparkle-project.org/documentation/api-reference/Protocols/SPUUpdaterDelegate.html), [no-update reasons](https://sparkle-project.org/documentation/api-reference/Enums/SPUNoUpdateFoundReason.html).

**FROZEN:** Background failure may avoid disruptive alerts, but opening Settings must not display false success. Preserve last successful result only with its timestamp and a clear failed/stale current status. U1 tests manual and background paths with offline, TLS failure, HTTP errors, malformed XML, invalid/missing signatures, and canceled checks.

## 9. Session/Data Invariants

**FROZEN:** Replace the app bundle only. No updater-triggered logout, data-store reset, Keychain migration, account rekeying, preferences reset, or cleanup outside updater-owned temporary files.

| Storage / behavior | Identifiers and assumptions to preserve |
| --- | --- |
| Keychain | Generic-password class; service `com.synok522.AIUsageBar` (different from bundle ID); account keys `claudeSessionKey`, `chatGPTSessionToken`, `chatGPTCookieHeader`, `grokSessionToken`, `grokCookieHeader`; legacy defaults key `chatgptSessionToken` migration behavior |
| UserDefaults | Standard app domain `synok522.AIUsageBar`; preserve preferences and existing migration behavior; no switch to new suite/app group |
| WebKit | Login provider and Grok restorer use `WKWebsiteDataStore.default()`; shared persistent store with provider-scoped cookie/data clearing only on existing logout/recovery paths; no new nonpersistent store or version-based store identifier |
| Last-good usage | `aiusgbar.lastGood.v1.` + provider + `.` + account key; schema 1, provider/meter/window identifiers and timestamp semantics |
| Account cache identity | SHA-256 of trimmed credential; do not change normalization/fingerprinting during updater integration |
| HTTP 429 reliability state | `aiusgbar.http429Backoff.v1`; preserve deadlines and schema, allow normal expiry |
| Notifications | `lowUsageNotificationsEnabled`, `lowUsageNotificationAuthorizationRequested`; preserve existing authorization behavior |
| Language | Existing `Localizable` catalog, English fallback, system/app language preference; keep bundle identity and avoid forcing AppleLanguages |
| Launch at Login | `SMAppService.mainApp.status`, register/unregister only for explicit settings changes; retain bundle identity/name/install location and normal signing continuity |

Evidence: [Keychain](https://github.com/synok522-del/AIUsageBar/blob/40360b68aae6d558d64829997d1d6ed8ab59c77e/AIUsageBar/Service/KeychainManager.swift), [view model](https://github.com/synok522-del/AIUsageBar/blob/40360b68aae6d558d64829997d1d6ed8ab59c77e/AIUsageBar/ViewModels/UsageViewModel.swift), [WebKit login](https://github.com/synok522-del/AIUsageBar/blob/40360b68aae6d558d64829997d1d6ed8ab59c77e/AIUsageBar/Login/WebLoginProvider.swift), [last-good persistence](https://github.com/synok522-del/AIUsageBar/blob/40360b68aae6d558d64829997d1d6ed8ab59c77e/AIUsageBar/V2/LastGoodUsageStore.swift), [identity derivation](https://github.com/synok522-del/AIUsageBar/blob/40360b68aae6d558d64829997d1d6ed8ab59c77e/AIUsageBar/V2/UsageSourceModels.swift), [backoff persistence](https://github.com/synok522-del/AIUsageBar/blob/40360b68aae6d558d64829997d1d6ed8ab59c77e/AIUsageBar/V2/HTTPRateLimitBackoff.swift), [login service](https://github.com/synok522-del/AIUsageBar/blob/40360b68aae6d558d64829997d1d6ed8ab59c77e/AIUsageBar/Service/LaunchAtLoginManager.swift).

**FROZEN:** Persistence preservation is not a promise that every session cookie or in-memory task survives process exit. Existing startup restore, legitimate provider expiry, stale-data expiry, and transient-lane reconstruction still occur. Preserve durable state and reconstruct safely; do not fabricate freshness or account continuity. U1 must compare real before/after session behavior without dumping credentials or cookies.

## 10. Release Pipeline

**FROZEN order, future versions only:**

1. Pin reviewed clean source SHA, version/build, final feed URL/public key, Sparkle 2.10.0 resolution, Xcode/tool versions. Run appropriate product tests/CI before release qualification.
2. Archive Release for both architectures and export for Developer ID. Verify all nested frameworks/XPC/tools and outer app; keep Hardened Runtime. No ad-hoc Release signing.
3. Submit the signed app in an allowed notarization container; require success. Staple and validate the app; verify its signature and Gatekeeper acceptance. Retain that canonical `.app` and dSYMs.
4. Build the one canonical DMG from that app. Verify packaging preserved signatures, symlinks, permissions and ticket. Finish all layout/compression before signing the DMG.
5. Developer ID-sign the final DMG, notarize it, staple it, validate it and assess distribution. Reopen read-only for inspection and verify the contained app again. Do not conflate the app's ticket with the DMG's ticket.
6. Compute final installer SHA-256, byte length and EdDSA signature only after all byte-changing operations, including DMG stapling. Record full source SHA, app/build/Team ID, package checksum, and release evidence.
7. Generate the no-delta appcast into staging using matching tools. Verify enclosure URL, bytes/signature, version, minimum OS `13.0.0`, notes, and signed-feed validation. Any metadata edit requires re-signing. Keep it unpublished.
8. Publish the future GitHub Release installer at an immutable version-specific URL. Enforce write-once assets operationally and enable platform immutability where available for these new releases. Do not advertise unverified bytes in the feed.
9. Download from the public URL as an unauthenticated client. Match SHA-256/size/signature; independently inspect app identity, CPU slices, build and notarization. Test the exact remote bytes in the staged proof feed.
10. Publish the signed production appcast **LAST**, only after its release gates pass. Fetch it remotely, verify exact bytes/signature and referenced enclosure accessibility. Monitor publication. Preserve a known-good signed feed for incident withdrawal; already-installed clients need a higher-build repair.

**REJECTED:** Signing update metadata before stapling; editing a signed archive; modifying an advertised asset in place; assuming a tag's current target identifies a historical binary; publishing appcast before remote verification.

**CONDITIONAL:** Current GUI-based packaging may require a controlled release Mac. U1 chooses and proves the automation environment; do not claim the existing script is already suitable for unattended CI. No pipeline step above was executed on Build 4.

## 11. Risks

| Risk | Disposition |
| --- | --- |
| New 2.10.0 release has little field time | CONDITIONAL: pin and test; verify security notices before ship, reopen version decision if a material issue appears |
| Missing Pages and on-main CI | FROZEN: prerequisites before public updater-enabled release, not blockers to starting U1 |
| No production updater key/custody yet | FROZEN: expected U1 preparation gate; no placeholder key in shipped app |
| Native trust allows identity rotation | FROZEN: accepted documented boundary; key compromise is critical, not defeated by an assumed second mandatory identity |
| Strict feed validation can strand clients on key loss | FROZEN: redundant restore-tested backups and manual recovery tradeoff |
| Feed replay/freshness | FROZEN: residual risk, no claimed anti-freeze protocol |
| HFS+/UDZO and layout-copy behavior | CONDITIONAL: test existing packaging; change only future packaging if needed |
| Launch-at-login / Keychain / WebKit continuity | CONDITIONAL: real-user-account tests required; source inspection alone cannot prove OS behavior |
| Full crash/power-loss rollback | REJECTED as a guarantee; CONDITIONAL recovery tests |

## 12. U1 Requirements

All entries below are **FROZEN acceptance requirements**. They authorize the shape of later work, not its execution during U0.

1. Integrate the exact package and standard controller without changing provider logic or identifiers. Add Settings check control and honest status; prove updater survives repeated menu opening/closing.
2. Restore reviewed CI on the working branch; validate app tests and signing configuration. Resolve nested Sparkle components for arm64 and x86_64 with macOS 13 support.
3. Establish restore-tested key custody and final HTTPS Pages endpoint before signing the first distributed Build 5. No private material in evidence.
4. Produce real signed/notarized/stapled **1.1.0 Build 5 → 1.1.1 Build 6** proof using the same canonical remote installer bytes intended for humans. Use an isolated proof environment/feed until all gates pass; never touch Build 4 or the user's installed app for a synthetic downgrade test.
5. Test manual Build 4 → Build 5 installation on a safe test account/copy; verify existing sessions and settings. Do not portray this as an in-app update.
6. Prove DMG selection with its `/Applications` shortcut/background; validate mount/copy/detach cleanup, signatures, app destination and no extra app copies. Repeat on Intel and Apple silicon, macOS 13 and a currently supported newer macOS.
7. Test writable Applications, user-owned install location, read-only mounted DMG/translocation, denied authorization, low disk space, canceled download, offline/HTTP/TLS failures, sleep/wake, interrupted extraction/install and failed relaunch. Record actual outcomes and recoverability, not just log completion.
8. Verify tampered archive, corrupted code signature, malformed/unsigned/wrong-key feed, altered notes, wrong app/build/CPU/OS metadata, old/equal versions and signed-feed replay. Demonstrate the native rotation limitation with nonproduction fixtures rather than expecting strict Team-ID rejection after valid EdDSA authorization.
9. Prove no artifact download before user consent, no unattended install/on-quit install, no silent enablement through standard UI or stale preferences. User-disabled automatic checks remain disabled. Test manual and scheduled paths separately.
10. Compare safe before/after checks for three provider logins, Keychain access, persistent WebKit state, account isolation, last-good data, 429 backoff, notification preference, language and launch-at-login. Keep tokens/cookies out of recordings and reports.
11. Observe Build 6 running after replacement with one menu-bar instance and correct footer/build metadata. Manual relaunch/recovery must not delete preferences or sessions.
12. Record DMG verdict. If material failures justify ZIP fallback, package the same canonical app with a symlink-preserving ZIP tool, re-sign the final ZIP and rerun the full update proof. Publish appcast only after remote gates.

## 13. Frozen Decisions

**FROZEN:** U0 complete; Build 4 immutable; current-main source baseline recorded; Sparkle **2.10.0** exact SwiftPM package; macOS 13 universal release; non-sandboxed Hardened Runtime; standard controller; one app bundle update; signed feed with no failure expiration; EdDSA archive authentication; Developer ID/notarized distribution and ordinary Team/Bundle continuity; documented native rotation limits; HTTPS Pages eligibility + versioned GitHub Release artifacts; no runtime GitHub API; integer build ordering; automatic checks with explicit installation consent; honest failure states; persistent-data preservation; final-artifact signing; appcast-last release gates; no production keys in U0.

## 14. Conditional Decisions

**CONDITIONAL:** DMG_ONLY pending real U1 proof; final Pages URL/deployment verification; existing HFS+/UDZO packaging versus APFS/LZFSE improvement; release-machine/CI packaging environment; standard UI behavior for MenuBarExtra; actual architecture/OS/signing/session/relaunch validation. These are implementation/release qualification gates, not an unmade choice of update framework or trust authority.

## 15. Deferred Decisions

**DEFERRED:** Windows updater/installer technology; deltas; beta channels; phased rollout; critical-update policy; paid-major-upgrade rules; special minimum source-version filtering; custom user driver; custom strict dual-authorization client policy; automatic installation as a future product change. No deferred feature may silently enter U1.

## 16. Stop Conditions

**FROZEN:** Stop release publication and reopen the affected decision if any of these occurs:

- Build 4 source/artifact/release would be changed, rebuilt, re-signed, re-notarized or replaced.
- Baseline drift is unexplained; production source or version provenance cannot be established.
- Stable Sparkle package/tool provenance or security status becomes questionable.
- Any release secret enters Git, app contents, logs, reports or chat; key restore/custody is unverified.
- Pages cannot preserve and deliver signed bytes, the appcast advertises unavailable/unverified bytes, or an artifact changes after signatures are calculated.
- App identity, Team ID, OS/architecture support, nested signatures, notarization or staple gates fail.
- Automatic installation/download violates consent, or any failure is displayed as latest.
- Update path clears durable data, breaks account isolation, silently changes launch-at-login, or cannot recover from representative interruption.
- DMG proof fails materially: select and prove the allowed ZIP fallback or stop the release.
- U1 attempts to claim stronger dual-key/freshness/rollback guarantees than actually implemented and tested.

**U0 blockers: NONE.** Missing hosting, custody and production update proof are explicitly assigned U1 gates. **CAN_START_U1: YES**, but U1 has not started. Stop after this report.
