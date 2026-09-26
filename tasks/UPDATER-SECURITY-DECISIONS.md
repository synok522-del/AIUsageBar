# AIUsageBar Updater — Production Security Decisions

## Signed-feed failure expiration

**Staging:** `SUSignedFeedFailureExpirationInterval = 0`.

**Production:** `HUMAN_DECISION_REQUIRED`. No production value is embedded in the app, project settings, or release scripts by default.

**Recommendation:** `0` seconds (never expire feed-signature failures), consistent with the current fail-closed trust model. This is a recommendation only; it is not frozen or applied to a production build.

**Security rationale:** With `SURequireSignedFeed` enabled, `0` prevents a long-running signed-feed validation failure from falling back to presenting an update from an unverified feed. The signed archive, Developer ID, and notarization checks remain separate safeguards, but they do not authenticate feed eligibility in the same way as the feed's EdDSA signature.

**Recovery implications:** A lost/unavailable EdDSA key can leave existing updater clients unable to consume new feed items indefinitely. Recovery depends on restoring the original key from verified backups, a carefully staged signing-key rotation, or directing users to a manually verified installer. A nonzero expiration interval improves recovery when the old feed key is lost, but Sparkle may then present a newly found update after feed-signing failures have persisted for that interval. Sparkle documents this as a key-rotation failsafe; release notes are omitted and informational-only updates are unsupported in this mode. This is a meaningful availability/security trade-off, so the production value remains a human decision.

**Authoritative evidence:**

- The app pins Sparkle 2.10.0 to revision `eef1a539a373c1f1a320624b1130fc5de7b2e100` in `Package.resolved`.
- In that exact source revision, [`SUAppcastDriver.m`](https://github.com/sparkle-project/Sparkle/blob/eef1a539a373c1f1a320624b1130fc5de7b2e100/Sparkle/SUAppcastDriver.m) defines the default as `1728000` seconds (20 days). Its signature-failure path records the first failure date; a zero interval disables expiry, while a nonzero interval allows the bounded recovery path after the configured duration.
- [Sparkle's customization reference](https://sparkle-project.org/documentation/customization/#security-settings) states that the default is `1728000` seconds, zero disables expiration, and expiration is a failsafe when the feed signing key is unavailable and updates can be served through key rotation.

`generate-production-info.py` requires both an explicit public key and an explicit non-negative expiration value. It has no default and refuses to overwrite an existing generated plist. The Build 5 and Build 6 archive scripts cannot silently select the production policy.

## U1 human gates

U1 remains `INCONCLUSIVE`; this downstream implementation does not change that status. The following are still required on a disposable isolated Mac/VM before production release:

- `UPDATE_DISCOVERY`
- `REPLACEMENT`
- `RELAUNCH`
- `MENUBAR_RETURN`
- `SESSION_PRESERVATION`
- `TAHOE_COMPATIBILITY`

The release gate also requires production signing-key custody/restore evidence, the human decision above, and exact-SHA macOS CI evidence. No check here substitutes for installed-host proof.
