# 17F-002 tests written

Dummy cookie values only (`dummy-sso-value`, `dummy-sso-rw-value`, `dummy-grok-sso`, `dummy-xai-sso`, `dummy-xcom-sso`). No live secrets.

- Grok login URL and display name are product-scoped
- Grok credential extracts dummy sso and optional sso-rw
- Grok credential prefers grok.com over x.ai and ignores x.com
- Provider cookie matching accepts grok.com / x.ai and rejects x.com
- Refresh timestamp updates when grokSucceeded is true

Existing ChatGPT/Claude tests retained.

Execution: NOT RUN (Linux, no xcodebuild).
