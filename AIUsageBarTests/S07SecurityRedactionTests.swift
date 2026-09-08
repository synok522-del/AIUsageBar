import Foundation
import Testing
@testable import AIUsageBar

struct S07SecurityRedactionTests {
    @Test("T-7-01 Log redaction strips bearer tokens")
    func logRedactionStripsBearerTokens() {
        let redacted = V2LogRedactor.redactForLog("Authorization: Bearer eyJhbGciOi-not-a-real-jwt")
        #expect(redacted.contains("eyJhbGciOi-not-a-real-jwt") == false)
        #expect(redacted.contains("[redacted-token]"))
    }

    @Test("T-7-02 Log redaction strips session cookies")
    func logRedactionStripsSessionCookies() {
        let raw = """
        Cookie: sso=dummy-sso-value; __Secure-next-auth.session-token=dummy-chatgpt; sessionKey=dummy-claude
        """
        let redacted = V2LogRedactor.redactForLog(raw)
        #expect(redacted.contains("dummy-sso-value") == false)
        #expect(redacted.contains("dummy-chatgpt") == false)
        #expect(redacted.contains("dummy-claude") == false)
        #expect(redacted.contains("[redacted-cookie]"))
    }

    @Test("T-7-03 Log redaction strips emails")
    func logRedactionStripsEmails() {
        let redacted = V2LogRedactor.redactForLog("user=lab-user@example.com")
        #expect(redacted.contains("lab-user@example.com") == false)
        #expect(redacted.contains("[redacted-email]"))
    }

    @Test("T-7-04 Usage source protocols expose no chat/transcript APIs")
    func usageSourceProtocolsExposeNoChatAPIs() throws {
        let source = try String(
            contentsOf: V2SecuritySurface.usageSourceSourceURL(from: #filePath),
            encoding: .utf8
        )
        #expect(source.contains("protocol V2UsageSource"))
        #expect(source.contains("func load(envelope:"))
        #expect(source.contains("func fetchChat") == false)
        #expect(source.contains("transcript") == false)
        #expect(source.contains("conversation") == false)
    }

    @Test("T-7-05 Codex parser still has no auth.json path")
    func codexParserHasNoAuthJSONPath() throws {
        #expect(CodexRateLimitsParser.filesystemAccess == .forbidden)
        let source = try String(
            contentsOf: V2SecuritySurface.codexParserSourceURL(from: #filePath),
            encoding: .utf8
        )
        #expect(source.contains("auth.json") == false)
        #expect(source.contains("~/.codex") == false)
        #expect(source.contains("parse(path:") == false)
    }

    @Test("T-7-06 Cursor parser is not wired to live state.vscdb in app target")
    func cursorParserNotWiredToLiveStateVscdb() throws {
        #expect(CursorUsageFixtureParser.filesystemAccess == .forbidden)
        let source = try String(
            contentsOf: V2SecuritySurface.cursorParserSourceURL(from: #filePath),
            encoding: .utf8
        )
        #expect(source.contains("state.vscdb") == false)
        #expect(source.contains("parse(path:") == false)
    }

    @Test("T-7-07 Foreign-cookie reuse (Tier 6) is not enabled")
    func foreignCookieReuseIsNotEnabled() {
        #expect(V2ForeignCookieReuse.enabled == false)
        var foreign = URLRequest(url: URL(string: "https://example.com/steal")!)
        foreign.setValue("sso=dummy-sso", forHTTPHeaderField: "Cookie")
        let rewritten = GrokRedirectPolicy.requestAfterRedirect(foreign)
        #expect(rewritten?.value(forHTTPHeaderField: "Cookie") == nil)
    }

    @Test("T-7-08 Compliance notes exist in V2_SECURITY_REVIEW.md with PASS/FAIL/UNCLEAR per provider")
    func complianceNotesExistWithVerdicts() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/V2_SECURITY_REVIEW.md")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("| ChatGPT | Production | **PASS**"))
        #expect(source.contains("| Claude | Production | **PASS**"))
        #expect(source.contains("| Grok | Production | **PASS**"))
        #expect(source.contains("| Cursor | HOLD, not a card | **PASS** (HOLD)"))
        #expect(source.contains("| Gemini | HOLD, not a card | **PASS** (HOLD)"))
        #expect(source.contains("| Codex | Challenger, default off | **PASS** (not production)"))
        #expect(source.contains("| Copilot | Architecture benchmark only | **PASS** (docs)"))
        #expect(source.contains("Production-needed items (ChatGPT, Claude, Grok) are **PASS**."))
    }
}
