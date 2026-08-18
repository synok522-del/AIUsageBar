# AIUsageBar v1.0.0-beta.1

## Highlights

- ChatGPT and Claude usage monitoring
- Compact two-bar menu bar status
- Automatic refresh
- Low-usage notifications
- Launch at Login
- Native macOS UI

## Known limitations

- This beta is not currently signed with a Developer ID certificate or notarized.
- The current repository has the complete macOS AppIcon slot structure, but final provider-neutral two-bar artwork still needs to be supplied.
- There is no App Store distribution or published signed binary yet.
- Provider website, authentication, cookie, or endpoint changes may affect login or usage retrieval.
- ChatGPT and Claude must be authenticated separately through their respective WebView login flows.
- The app currently supports only ChatGPT and Claude.

## Distribution status

The safest current path is to build the Release configuration from source for local or internal testing. A locally created unsigned DMG is not considered ready for external beta distribution until Developer ID signing and notarization are available.
