# Sprint 17F-015B — Swift Testing #expect mutating-state compile fix

**Base:** `7dc5cde1f93760ecd5e163971a6a94d357b0b601`  
**Branch:** `review/17f-015b-test-compile-fix`  
**Production source:** NO  
**Merge to main:** NO

## Failures

- T12: `#expect(state.shouldNotify(...))` (was line 1958)
- T13: `#expect(state.shouldNotify(...))` (was line 1986)

`#expect` expands to a closure where `$0` is immutable; `shouldNotify` is `mutating`.

## Fix

Call `shouldNotify` first, then `#expect` the `Bool`.

## 17F-015A helpers

REVERTED. Mac evidence showed they were not the compiler failures; 015 already compiled those helpers.
