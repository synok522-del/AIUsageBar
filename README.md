# AIUsageBar

Keep an eye on your remaining **ChatGPT, Claude, and Grok usage** from the macOS menu bar.

**English version · English + Traditional Chinese localization · v3 Reliability**

AIUsageBar brings available usage balances, usage windows, and reset times into one lightweight native panel, so you can check your remaining allowance without opening each provider’s website.

[Product introduction](docs/intro.md) · [Release availability](#download-and-install) · [繁體中文摘要](#繁體中文摘要)

## English + Traditional Chinese

The interface supports **English and Traditional Chinese**, including the usage panel, settings, sign-in flows, notifications, and status messages. English is the development language and fallback; macOS language preferences determine the app language.

## v3 Reliability

The `v3/release-candidate` branch focuses on dependable usage monitoring. “v3” names this reliability work; the designated release artifact is still **AIUsageBar 1.0.0 (build 4)**.

- **Last-good data:** retains eligible, account-scoped usage from the last successful refresh during temporary failures.
- **Stale status:** marks retained readings as stale with last-update information, so older values are not mistaken for fresh data.
- **HTTP 429 backoff:** delays retries after rate limits, with exponential backoff and respect for the provider’s `Retry-After` value.
- **Sleep/wake refresh:** refreshes after the Mac wakes, coalescing repeated wake events and respecting active backoff.
- **Per-provider single-flight and deadline:** duplicate refresh requests share one logical refresh per provider; deadlines end stalled work, and late results cannot overwrite newer state.
- **Account switching protection:** invalidates old refresh work and scopes retained data to account identity to prevent results from a previous account appearing after a switch.
- **Grok recovery:** improves session recovery and recovery-state handling, while asking for sign-in again when user action is needed.

These safeguards improve recovery from temporary failures. Available readings still depend on each provider’s account, session, and endpoints.

## Features

- ChatGPT, Claude, and Grok remaining usage in one menu bar panel.
- Provider-supplied usage windows and reset times, where available.
- Automatic refresh and low-usage notifications below 20% remaining.
- Optional launch at login.
- Native SwiftUI interface with credentials and session tokens stored in macOS Keychain.

## Download and install

**Designated final release artifact:** `AIUsageBar-1.0.0-build4.dmg` — version **1.0.0 (4)**, **Developer ID signed, Apple notarized, stapled, and Gatekeeper accepted**.

**Artifact provenance:** `AIUsageBar-1.0.0-build4.dmg` was built from product source SHA `df65e6b9541721eefc7b18fb4365c12f7a2aa10a`. The later release documentation commit `ee62a668dc32f2a46cd6c0ec3ff9f7f311809546` is documentation-only and is not the binary's build source; the DMG was not built from that documentation HEAD. Subsequent test and audit cleanup commits leave the production source unchanged.

**Publication status (checked September 13, 2026):** this exact artifact is not yet available among the public GitHub Release assets. The existing `v1.0.0` release contains an older, differently named DMG (`AIUsageBar-1.0.0-build4-main-0cf9989-notarized.dmg`) with a different checksum. It is not the designated artifact described here.

[Check GitHub Releases for availability](https://github.com/synok522-del/AIUsageBar/releases). A direct download link will be added when the exact final artifact is published.

SHA-256 for `AIUsageBar-1.0.0-build4.dmg`:

```text
49d4ecc16ea149d8d05e780cd9512ecaba2bbd49a6c118dfc1250c55ff4e3415
```

Requires **macOS 13.0 or later** and an account for each provider you want to monitor.

1. Once published, download `AIUsageBar-1.0.0-build4.dmg` from GitHub Releases and compare its SHA-256 with the value above.
2. Open the DMG and drag `AIUsageBar.app` to **Applications**.
3. Launch AIUsageBar from Applications; its icon appears in the menu bar.
4. Open **Settings** and sign in to ChatGPT, Claude, or Grok. Connect only the services you use.
5. Optionally enable low-usage notifications and launch at login.

## Screenshots

The existing screenshots below show the Traditional Chinese interface; English localization is also supported.

### Usage panel

![AIUsageBar usage panel in Traditional Chinese](docs/images/aiusagebar-main.png)

Remaining usage and available reset times for ChatGPT, Claude, and Grok in one panel.

### Accounts and settings

![AIUsageBar settings in Traditional Chinese](docs/images/aiusagebar-settings.png)

Manage provider sign-in, sign out, notifications, and launch at login.

### Menu bar icon

![AIUsageBar menu bar icon](docs/images/aiusagebar-menu-bar-icon.png)

## Privacy and data

- Credentials and session tokens are stored locally in macOS Keychain.
- Sign-in uses provider websites and in-app WebKit sessions; website cookies remain in the local WebKit data store.
- Usage data comes directly from the provider endpoints used by the app.
- The project has no AIUsageBar backend or analytics endpoint; credentials are not intentionally uploaded to an AIUsageBar server.

AIUsageBar is an independent project, unaffiliated with and not endorsed or sponsored by OpenAI, Anthropic, or xAI. Provider website, sign-in, cookie, or endpoint changes can affect usage retrieval.

## 繁體中文摘要

AIUsageBar 是輕量的 macOS 選單列 App，集中顯示 **ChatGPT／Claude／Grok 剩餘用量、用量週期與重置時間**，支援 **英文與繁體中文介面**。

v3 Reliability 強化最後成功資料保留（last-good）、過期資料標示（stale）、429 退避重試、睡眠喚醒後更新、各服務獨立的單一進行中更新與逾時期限、切換帳號保護，以及 Grok session 復原。

正式指定安裝檔為 **`AIUsageBar-1.0.0-build4.dmg`**，已完成 Developer ID 簽署、Apple 公證、staple 與 Gatekeeper 驗證。**此檔案尚未公開於 GitHub Releases**；現有舊檔案並非本次指定版本。公開後請依上方安裝步驟操作，並核對 SHA-256。
