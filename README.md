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

- macOS 15.2 or later
- A ChatGPT and/or Claude account for the corresponding usage view

## Installation

AIUsageBar is not currently distributed through the Mac App Store or a signed public download.

For the current beta, build from source:

1. Clone this repository.
2. Open `AIUsageBar.xcodeproj` in Xcode.
3. Select the `AIUsageBar` scheme and a macOS destination.
4. Build and run the app.

The first run opens the app as a menu bar item. Use Settings to sign in to ChatGPT or Claude. A locally generated unsigned DMG may be used for internal testing, but it is not an externally trusted beta distribution until it is Developer ID signed and notarized.

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

The macOS `AppIcon` asset catalog contains the standard 16, 32, 128, 256, and 512 point slots at 1x and 2x. The repository currently does not contain final artwork files for those slots. Final provider-neutral artwork based on the AIUsageBar two-horizontal-bar identity is still required before an external beta release.

### Current release configuration

- Bundle identifier: `synok522.AIUsageBar`
- Marketing version: `1.0.0`
- Build number: `1`
- Deployment target: macOS 15.2
- App Sandbox: disabled in the current project
- `LSUIElement`: enabled, so the app runs as a menu bar app without a Dock icon
- Launch at Login: uses `SMAppService.mainApp`

The current local environment has no Developer ID signing identity and no notarization credentials. Release artifacts built here must be treated as local or internal test artifacts until signed and notarized.
