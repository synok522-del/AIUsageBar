# AIUsageBar

AIUsageBar is a native macOS menu bar app for checking your remaining AI usage without repeatedly opening provider websites.

AIUsageBar 是原生 macOS 選單列 App，讓你快速查看 AI 服務剩餘用量，不必反覆開啟各服務網站。

**Current production release / 目前正式版：AIUsageBar v1.1.0 (Build 5)**

## Download / 下載

- [Download AIUsageBar 1.1.0 Build 5 DMG](https://github.com/synok522-del/AIUsageBar/releases/download/v1.1.0/AIUsageBar-1.1.0-build5.dmg)
- [GitHub Release and release notes / GitHub 發布頁與版本說明](https://github.com/synok522-del/AIUsageBar/releases/tag/v1.1.0)

SHA-256: `fcef7da669c56ada976f76550f4638eadc3b4a6dab4b28b9e16da0bc9f5919e2`

Requires macOS 13 or later. Open the DMG and drag `AIUsageBar.app` to Applications.

系統需求為 macOS 13 以上。打開 DMG，將 `AIUsageBar.app` 拖到「應用程式」資料夾即可安裝。

## Features / 功能

- Check remaining usage, available usage periods, and reset times in one menu bar panel.
- Refresh usage automatically and optionally receive low-usage notifications.
- Use the app in English or Traditional Chinese.
- 在同一個選單列面板查看剩餘用量、可用的用量週期與重置時間。
- 可自動更新用量，並選擇接收低用量通知。
- 支援英文與繁體中文介面。

## Supported Providers / 支援服務

AIUsageBar currently supports **ChatGPT, Claude, and Grok**. Available usage details depend on each provider and account. Provider websites and sign-in methods can change, so occasional sign-in may be required.

目前支援 **ChatGPT、Claude 與 Grok**。可顯示的用量資訊依各服務與帳戶而異。服務網站或登入方式變更時，偶爾可能需要重新登入。

## Automatic Updates / 自動更新

Build 5 is the first production release with an in-app updater. Build 4 and earlier do not include the updater, so those users must manually download and install Build 5. Starting with Build 5, you can check for future releases inside AIUsageBar; update availability and status appear in Settings. Updates use the production Sparkle update channel.

Build 5 是第一個包含 App 內更新功能的正式版本。Build 4 及更早版本不含更新程式，因此需要手動下載並安裝 Build 5。從 Build 5 起，可在 AIUsageBar 內檢查後續版本；更新是否可用與目前狀態會顯示在「設定」。更新使用正式版 Sparkle 更新頻道。

## Screenshots / 畫面截圖

These previews show the main interface; some newer Settings controls may not appear.

以下畫面展示主要介面，部分較新的設定選項可能未顯示。

### Usage panel / 用量面板

![AIUsageBar usage panel in Traditional Chinese](docs/images/aiusagebar-main.png)

### Accounts and settings / 帳戶與設定

![AIUsageBar settings in Traditional Chinese](docs/images/aiusagebar-settings.png)

### Menu bar icon / 選單列圖示

![AIUsageBar menu bar icon](docs/images/aiusagebar-menu-bar-icon.png)

## Privacy / 隱私

Sign-in credentials are stored in macOS Keychain, and website cookies stay in local WebKit storage. The app uses session data to communicate directly with the corresponding provider for sign-in and usage retrieval. The project does not operate a backend or analytics endpoint; credentials and session data are not sent to an AIUsageBar-operated server.

登入憑證保存在 macOS 鑰匙圈，網站 Cookie 保存在本機 WebKit 資料中。App 使用工作階段資料直接與相應服務商進行登入及用量查詢。專案不營運後端或分析端點；登入憑證與工作階段資料不會傳送至 AIUsageBar 營運的伺服器。

AIUsageBar is an independent project and is not affiliated with, endorsed by, or sponsored by OpenAI, Anthropic, or xAI.

AIUsageBar 為獨立專案，與 OpenAI、Anthropic 或 xAI 無隸屬、背書或贊助關係。

## Development / 開發

To open the Build 5 source revision in Xcode:

```sh
git clone https://github.com/synok522-del/AIUsageBar.git
cd AIUsageBar
git checkout ec4586b62e23a6098fc7247ec9f34b6915d8366f
open AIUsageBar.xcodeproj
```

An Xcode development build is not the signed production DMG. Xcode 開發版並非已簽署的正式 DMG。
