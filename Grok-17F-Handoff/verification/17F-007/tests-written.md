# 17F-007 tests written

Dummy cookie values only. No live secrets.

F1:
- Grok remaining percent uses totalQueries even when totalTokens is present
- Grok remaining percent uses totalQueries when totalTokens is absent
- Grok remaining percent ignores zero or missing totalTokens when totalQueries is valid
- Grok remaining percent never divides remainingQueries by totalTokens
- Grok missing or zero totalQueries does not invent a percent

F2:
- Grok does not fabricate a reset timestamp from windowSizeSeconds
- Grok uses a genuine reset timestamp when one is present
- Live 140/140/7200 has empty reset text

F3:
- Grok credential requires grok.com and ignores x.ai and x.com
- Provider cookie matching accepts grok.com and rejects x.ai / x.com

F6:
- 1800 seconds → 30 分鐘, not 1 小時
- 90 seconds → 1 分鐘 30 秒
- 45 seconds → 45 秒
- 3599 seconds → 59 分鐘 59 秒, not 1 小時

Execution: NOT RUN (Linux, no xcodebuild).
