# U1 isolated-machine test — not for the production Mac

**Do not run this procedure on Kenny's production Mac.** Its installed Build 4 and provider data must stay untouched. Use a disposable macOS VM or a separate test Mac, with snapshots/backups and no production install at `/Applications/AIUsageBar.app`. Changing a filename or setting a different TMPDIR is not isolation: this spike deliberately retains the real bundle, Keychain and WebKit identities. Sparkle relaunch does not preserve arbitrary launch environment variables.

## Build workspace

Release build, SourcePackages, archive and exported app directories must be outside File Provider/iCloud-synced Documents. Use a dedicated `/private/tmp/AIUsageBar-U1-20260915` workspace on the release machine. The initial Documents build acquired Finder metadata and was rejected by codesign; no provenance removal is used as a workaround.

## Prepare

1. Read `tasks/UPDATER-U1.md` and its exact staging URLs/hashes. Use host 0.0.1 (9001), candidate 0.0.2 (9002), and Sparkle 2.10.0. Do not use production versions/builds 4, 5 or 6.
2. Record OS build, CPU architecture, logged-in test account and a clean baseline of mounted images. Test arm64 and x86_64, macOS 13 and Tahoe before broader support claims.
3. Download the host DMG from its versioned staging release URL. Check the report's SHA-256/size, `xcrun stapler validate`, `codesign --verify --strict`, and `spctl --assess --type open --context context:primary-signature --verbose=2`.
4. Mount the image, copy its AIUsageBar.app into the isolated machine's `/Applications`, and eject the image. Do not launch from the DMG or Downloads. Verify app signature, Team ID `S898B9KBWN`, Bundle ID `synok522.AIUsageBar`, `LSUIElement=true`, both CPU slices, and host version/build.
5. Launch the host normally. Record process ID/path, menu-bar appearance, absence of an unexpected Dock icon, Settings version, and provider refresh behavior. Confirm only one AIUsageBar process exists. Keep recordings free of credentials/cookies.

## Preservation baseline

Use test accounts where safe. Sign into ChatGPT, Claude and Grok manually; record only logged-in status and masked account identity. Exercise a usage refresh. Set a recognizable notification preference, language choice and Launch at Login preference. Record last-good state/timestamps through the app. Never dump Keychain values, cookie stores or full UserDefaults into logs. Snapshot the VM before failure testing.

## End-to-end stock-driver proof

1. Fetch the public HTTPS staging appcast and enclosure independently. Verify exact remote hash, byte length and signatures with the supplied tools. Record response/cache headers.
2. Open **U1 Staging: Check for Updates…** in the menu-bar panel. The stock Sparkle UI must offer 0.0.2 / 9002. Record discovery. Merely showing an update does not prove installation.
3. Before consenting, verify no candidate artifact has downloaded automatically. Decline once and confirm the app remains at 9001 and operates. Check again, explicitly choose download/install, and observe the stock progress UI.
4. Record download completion, signed-feed acceptance and enclosure validation from safe Sparkle diagnostics. Observe the old process terminate, bundle replacement, and a new process with a new PID launched from `/Applications/AIUsageBar.app`.
5. Verify MenuBarExtra returns, Settings opens and shows **0.0.2 (9002)**, no unexpected Dock icon appears, and usage refresh remains functional. Mark each separately. A copied bundle or launch request alone is not PASS.
6. Run `verify-app.py /Applications/AIUsageBar.app`, deep/strict codesign, Gatekeeper and staple validation. Inspect executable permissions and framework symlinks. Record any permission prompts or errors.
7. Compare mount lists before/after, including UUID-named Sparkle mounts, not only `/Volumes/AIUsageBar*`. Confirm no image associated with this update remains mounted.
8. Verify all three test sessions, account isolation, preferences, language, WebKit persistence, Keychain access, last-good data and Launch at Login state. Legitimate expiry must be distinguished from updater-induced loss. Do not delete/recreate provider data to hide a failure.
9. Manual check from 9002 must not offer 9002 or older as newer. Verify the selected candidate and no-update result; distinguish an unavailable/invalid feed from no eligible update.

## Failure matrix on isolated snapshots only

Use separate signed staging fixture feeds or a controlled HTTPS test endpoint. Never modify canonical DMGs or production feeds. Do not switch the host's bundle ID, public key, or Team ID to make a fixture pass.

| Case | Expected observation |
| --- | --- |
| Unreachable feed / TLS / HTTP error | Stock check error; no “latest” conclusion |
| Modified or unsigned feed | Signature rejection; no download/install |
| Signed feed pointing at tampered enclosure | Archive rejected; old host remains operational |
| Missing enclosure | Download failure; old app still launches |
| Interrupted download | No partial install; old app still launches |
| Same/lower build | Never selected as newer |
| Failed install / denied authorization | Current app remains recoverable; record exact state |
| Failed relaunch | Report failure; recover via verified host installer without deleting data |

For **bad EdDSA** use a byte-corrupted copy so both archive integrity and Developer ID container validation fail. An otherwise valid same-Team signed DMG with only a bad EdDSA string can exercise Sparkle's intentional key-rotation fallback; it is not proof of a bypass of the frozen native trust model. Record which path actually ran.

## Tahoe focus

Inspect safe Sparkle/Autoupdate logs for EPERM, installation-cache errors and App Management denials. Do not remove provenance xattrs, disable macOS security, patch Sparkle, or redirect caches to force success. Upstream's `.app` bundle-ID workaround reduces a known risk but is not empirical proof for this application. Record one success as one tested configuration, not universal reliability.

## Record and stop

Fill every runtime row in `tasks/UPDATER-U1.md` with PASS, FAIL, NOT_TESTED or HUMAN_GATE_REQUIRED and attach sanitized evidence. Keep source SHA and artifact hashes tied to the tested bytes. DMG_ONLY stays INCONCLUSIVE until the full replacement/relaunch/menu-bar gates pass. Do not start U2 or publish production artifacts.
