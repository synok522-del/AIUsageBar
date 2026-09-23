# AIUsageBar Updater — U2 Production Integration

**U2_STATUS: IMPLEMENTED_NOT_RUNTIME_PROVEN**

U2 replaces the staging-only controller spike with an app-lifetime adapter around `SPUStandardUpdaterController` and Sparkle's stock user driver. Settings exposes automatic-check preference and a manual “Check for Updates…” action. Status reporting distinguishes checking, eligible/no-eligible results, download, extraction, install, relaunch, cancellation, and failure without claiming “latest” after a nil completion error.

Updater startup is fail-closed. The adapter requires HTTPS, a 32-byte EdDSA public key, signed-feed validation, pre-extraction validation, non-automatic installation, and an explicit `SUSignedFeedFailureExpirationInterval`. Missing/partial/placeholder production configuration leaves Sparkle stopped and the controls disabled. The staging plist remains the only configured key/feed in the tree.

Provider, Keychain, UserDefaults, WebKit, notification, language and Launch-at-Login identities are unchanged. U1 remains `INCONCLUSIVE`; the installed-host gates are not satisfied by source or unit-test evidence.

Local validation: the full `AIUsageBarTests` target passed with 255 tests in 8 suites, including updater-configuration and localization tests. The Release staging configuration also built successfully with the existing staging feed, public key, zero expiration interval, and `0.0.1 (9001)` identity. Exact pushed-SHA CI remains the final implementation evidence.
