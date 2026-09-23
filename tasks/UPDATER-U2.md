# AIUsageBar Updater — U2 Production Integration

**U2_STATUS: IMPLEMENTED_NOT_RUNTIME_PROVEN**

U2 replaces the staging-only controller spike with an app-lifetime adapter around `SPUStandardUpdaterController` and Sparkle's stock user driver. Settings exposes automatic-check preference and a manual “Check for Updates…” action. Status reporting distinguishes checking, eligible/no-eligible results, download, extraction, install, relaunch, cancellation, and failure without claiming “latest” after a nil completion error.

Updater startup is fail-closed. The adapter requires HTTPS, a 32-byte EdDSA public key, signed-feed validation, pre-extraction validation, non-automatic installation, and an explicit `SUSignedFeedFailureExpirationInterval`. Missing/partial/placeholder production configuration leaves Sparkle stopped and the controls disabled. The staging plist remains the only configured key/feed in the tree.

Provider, Keychain, UserDefaults, WebKit, notification, language and Launch-at-Login identities are unchanged. U1 remains `INCONCLUSIVE`; the installed-host gates are not satisfied by source or unit-test evidence.

The Sparkle callback status mapping was remediated to preserve `SUNoUpdateError` as no-eligible-update through Sparkle's abort and cycle-finished callbacks; cancellation remains cancellation and other Sparkle/network errors remain failures. Five focused transition tests were added. Local serial validation passed all 260 `AIUsageBarTests` in 9 suites, and all exact-SHA CI jobs passed on `19531d53aa0b99a0442beea1783c1999293be9f8`.

The updated staging configuration passed signed Release archive/export validation for host `0.0.3 (9031)` and candidate `0.0.4 (9032)`, both from that exact source SHA. They are not notarized DMGs, and the installed-host Human Gate remains unrun. The final staging procedure and current publication blocker are recorded in [`UPDATER-FINAL-HUMAN-TEST.md`](UPDATER-FINAL-HUMAN-TEST.md).
