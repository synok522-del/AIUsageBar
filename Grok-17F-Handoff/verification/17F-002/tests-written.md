# 17F-002 tests written

Dummy cookie values only (`dummy-sso-value`, `dummy-sso-rw-value`, `dummy-grok-sso`, `dummy-xai-sso`, `dummy-xcom-sso`). No live secrets.

- Grok login URL and display name are product-scoped
- Grok credential extracts dummy sso and optional sso-rw
- Grok credential requires grok.com and ignores x.ai and x.com (17F-007)
- Provider cookie matching accepts grok.com and rejects x.ai / x.com (17F-007)
- Refresh timestamp updates when grokSucceeded is true

Existing ChatGPT/Claude tests retained.

Execution: NOT RUN (Linux, no xcodebuild).
