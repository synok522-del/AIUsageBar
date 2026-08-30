# 17F-004 tests written

- Welcome stays hidden when only Grok is logged in
- Provider visibility shows only authenticated Grok
- Provider visibility order is ChatGPT then Claude then Grok
- Unauthenticated Grok is hidden
- Zero remaining Grok does not hide authenticated Grok
- Fetch failure does not hide authenticated Grok
- Logging out Grok does not hide ChatGPT or Claude
- Grok window label uses seconds not a hardcoded five hours

Execution: NOT RUN (Linux, no xcodebuild).
