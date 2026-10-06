# AIUsageBar Updater — U4 Build 5 RC Preparation

**U4_STATUS: PREPARATION_IMPLEMENTED_ARTIFACT_NOT_PRODUCED**

Build 5 is reserved as AIUsageBar `1.1.0` / build `5`. The Xcode app target now defaults to that identity; the staging script still overrides it with the U1 staging versions. `Packaging/UpdaterProduction/prepare-build5-rc.sh` prepares a signed Developer ID archive/export only when given a production public key and an explicit expiration value.

The script was not run: no production EdDSA key/custody exists yet, and the expiration value requires a human decision. No Build 5 installer or release was produced. A Build 5 candidate cannot pass its release gate until notarization/stapling, final DMG signing and verification, EdDSA signing, exact-SHA CI, and human installation checks are complete.
