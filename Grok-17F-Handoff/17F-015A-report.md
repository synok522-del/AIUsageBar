# Sprint 17F-015A — Test compile fix

**Base:** `ba17c3ab47be7a24148a3e72e2e5d9732c4a5691`  
**Branch:** `review/17f-015a-test-compile-fix`  
**Production UI:** unchanged  
**Merge to main:** NO

## Root cause

Two test helper closures called mutating `Data` APIs with `UnsafeRawBufferPointer` (`$0` / `bytes`) from `withUnsafeBytes`. On the Mac toolchain those pointers are immutable values, so the build failed before any test ran.

## Failing locations

1. `AIUsageBarTests.swift` `protoFloat` — `data.append(contentsOf: $0)`
2. `AIUsageBarTests.swift` `grpcWebFrame` — `header.replaceSubrange(1..<5, with: bytes)` inside `withUnsafeBytes`

## Fix

Write little-endian float bits and big-endian gRPC-Web length with explicit `UInt8` appends. Same protobuf / frame bytes; T1–T16 intent preserved.

## Production

No production source changes.
