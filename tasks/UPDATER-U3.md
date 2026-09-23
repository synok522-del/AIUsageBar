# AIUsageBar Updater — U3 Release Preparation Tooling

**U3_STATUS: IMPLEMENTED_GATED_NOT_RELEASED**

The production plist generator requires an explicit public key and expiration interval; no key or expiration policy is stored in Git. The Build 5/6 scripts use the existing Xcode project, exact Sparkle 2.10.0 pin, Developer ID archive/export flow, and separate fresh output directories. They verify bundle ID, version/build, HTTPS feed, signed-feed security settings, Team ID, Hardened Runtime, and universal architectures.

The scripts stop after signed Developer ID export. Notarization, stapling, final DMG creation/signing, EdDSA artifact signing, public feed verification/publication, and installed-host behavior remain separate gates. No release asset, tag, Pages feed, or production release was changed.

Production `SUSignedFeedFailureExpirationInterval` remains `HUMAN_DECISION_REQUIRED`; see `tasks/UPDATER-SECURITY-DECISIONS.md`.
