# AIUsageBar

AIUsageBar is a lightweight macOS menu bar app for monitoring remaining AI usage.

The current beta supports:

- ChatGPT
- Claude

## Features

- Live remaining usage for supported providers
- Compact two-bar menu bar status
- Claude five-hour and weekly quotas
- ChatGPT usage status
- Automatic refresh
- Low-usage notifications at 20% remaining
- Launch at Login
- Secure credential storage using the macOS Keychain
- Native macOS interface built with SwiftUI and MenuBarExtra

## Screenshots

Final screenshots are not included yet. Add real screenshots here before publishing a public beta release.

<!-- Screenshot placeholder: menu bar status -->
<!-- Screenshot placeholder: usage panel -->

## Requirements

- macOS 13.0 or later
- A ChatGPT and/or Claude account for the corresponding usage view

## Installation

The intended beta distribution is a signed and notarized DMG. Open the release DMG, move `AIUsageBar.app` to Applications, and launch it from there. The release app has passed Apple notarization and Gatekeeper validation.

AIUsageBar is distributed directly and is not available through the Mac App Store. Building from source is an option for contributors and local development, but a locally built app should not be treated as the signed beta artifact.

The first run opens the app as a menu bar item. Use Settings to sign in to ChatGPT or Claude.

## Privacy

- Credentials and session tokens are stored locally in the macOS Keychain.
- Web login uses the provider websites through the app's WebKit session; provider website cookies remain in the local WebKit data store.
- Usage information is fetched directly from the supported provider endpoints used by the app.
- Based on the current source code, AIUsageBar does not intentionally upload credentials to an AIUsageBar server. The project has no AIUsageBar backend or analytics endpoint.

## Disclaimer

AIUsageBar is an independent project and is not affiliated with, endorsed by, or sponsored by OpenAI or Anthropic.

ChatGPT and Claude names are used only to identify compatible services. This project does not include or use official provider logos.

## Release readiness

### App icon

The macOS `AppIcon` asset catalog contains the final provider-neutral artwork based on the AIUsageBar two-horizontal-bar identity, with the standard 16, 32, 128, 256, and 512 point slots at 1x and 2x.

### Current release configuration

- Bundle identifier: `synok522.AIUsageBar`
- Marketing version: `1.0.0`
- Build number: `1`
- Deployment target: macOS 13.0
- App Sandbox: disabled in the current project
- `LSUIElement`: enabled, so the app runs as a menu bar app without a Dock icon
- Launch at Login: uses `SMAppService.mainApp`

The external beta artifact is signed with Developer ID Application, uses Hardened Runtime, is notarized by Apple, and is intended to pass Gatekeeper assessment. These properties apply to the exported release artifact; a local source build may have different signing status.
