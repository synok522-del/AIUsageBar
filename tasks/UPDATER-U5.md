# AIUsageBar Updater — U5 Build 6 Proof Preparation

**U5_STATUS: PREPARATION_IMPLEMENTED_PROOF_NOT_RUN**

Build 6 is reserved as AIUsageBar `1.1.1` / build `6`. `Packaging/UpdaterProduction/prepare-build6-proof.sh` prepares a signed Developer ID archive/export using the same explicit production public key and feed-expiration choice as Build 5. It does not publish a versioned asset or appcast and does not claim update proof.

The proof must use the exact signed/notarized/stapled Build 5 and Build 6 DMG bytes intended for humans, with a signed isolated proof feed. Discovery, replacement, relaunch, MenuBarExtra return, session preservation, and Tahoe compatibility remain Human Gates from U1. No proof artifact was built or installed in this run.
