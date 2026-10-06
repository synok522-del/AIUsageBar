# Production updater build preparation

The app uses Sparkle's stock controller and user driver. The production appcast is reserved at `https://synok522-del.github.io/AIUsageBar/appcast.xml`; no production feed, key, or signed artifact is published by these scripts.

The default project build does not contain a production updater key or failure-expiration value. The app detects incomplete updater configuration and does not start Sparkle. The staging plist remains separate and continues to use the existing U1 staging key/feed.

Before archive preparation, a release operator must supply the **public** EdDSA key and explicitly choose `SUSignedFeedFailureExpirationInterval`. The production private key is never an input to Xcode or these scripts. `tasks/UPDATER-SECURITY-DECISIONS.md` records the current recommendation and the unresolved decision.

From a clean committed checkout of `main`, a `release/*` branch, or `feature/in-app-updater-u2-u5` (the script records the source SHA in the output directory):

```sh
Packaging/UpdaterProduction/prepare-build5-rc.sh \
  /path/to/new-output-directory \
  '<production public EdDSA key>' \
  '<human-approved expiration seconds>' \
  '<full source SHA>'

Packaging/UpdaterProduction/prepare-build6-proof.sh \
  /path/to/another-new-output-directory \
  '<same production public EdDSA key>' \
  '<same human-approved expiration seconds>' \
  '<full source SHA>'
```

Build 5 is fixed at version `1.1.0` / build `5`; Build 6 is fixed at `1.1.1` / build `6`. Each command requires a clean checkout on `feature/in-app-updater-u2-u5` or `v3/release-candidate` and a full expected source SHA that must equal `HEAD`. It creates a Developer ID archive and export in a fresh output directory and checks the exported plist, signature, team, hardened runtime, and universal slices. It does **not** notarize, staple, create/sign a DMG, sign or publish an appcast, upload artifacts, or run an installed update. Those steps remain release-gated.

The Build 6 script is preparation only. It does not prove a real Build 5 → Build 6 update. Run the unchanged U1 human procedure, then a Build 5 → Build 6 proof on a disposable isolated Mac/VM, and record actual results before considering the final release gate.
