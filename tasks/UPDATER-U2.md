# AIUsageBar Updater — U2 Production Integration

**U2_STATUS: IMPLEMENTED_NOT_RUNTIME_PROVEN**

U2 replaces the staging-only controller spike with an app-lifetime adapter around `SPUStandardUpdaterController` and Sparkle's stock user driver. Settings exposes automatic-check preference and a manual “Check for Updates…” action. Status reporting distinguishes checking, eligible/no-eligible results, download, extraction, install, relaunch, cancellation, and failure without claiming “latest” after a nil completion error.

Updater startup is fail-closed. The adapter requires HTTPS, a 32-byte EdDSA public key, signed-feed validation, pre-extraction validation, non-automatic installation, and an explicit `SUSignedFeedFailureExpirationInterval`. Missing/partial/placeholder production configuration leaves Sparkle stopped and the controls disabled. The staging plist remains the only configured key/feed in the tree.

Provider, Keychain, UserDefaults, WebKit, notification, language and Launch-at-Login identities are unchanged. U1 remains `INCONCLUSIVE`; the installed-host gates are not satisfied by source or unit-test evidence.

The Sparkle callback status mapping now uses a pure reducer so no-update, cancellation, dismissal, and real failures remain distinct across callback orderings. Focused reducer tests ran in exact-source CI run `35840172573`, which passed the macOS build, all 266 product tests in 9 suites, and UI/launch checks for `5ec435fb5f93422228e49a3fc7f57cec6982e32c`.

The final staging host `0.0.3 (9003)` and candidate `0.0.4 (9004)` were built from that exact source SHA, notarized, stapled, signed after staple with the existing staging EdDSA key, published to the isolated staging release/feed, and verified from public HTTPS downloads. Their complete hashes, signature, and notarization evidence are recorded in [`UPDATER-FINAL-HUMAN-TEST.md`](UPDATER-FINAL-HUMAN-TEST.md). The installed-host Human Gate remains unrun; U1 is still `INCONCLUSIVE` and DMG_ONLY remains `CONDITIONAL_PENDING_HUMAN_GATE`.
