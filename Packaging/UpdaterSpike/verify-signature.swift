import Foundation
import CryptoKit

// Public-key-only release verification; not used by the app's updater.
// Feed framing follows Sparkle 2.10.0 SPUExtractSignedFeed.m.
let args = CommandLine.arguments
func reject(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}
guard args.count == 4 else { reject("Usage: verify-signature PUBLIC_KEY FILE SIGNATURE|--feed") }
do {
    guard let keyData = Data(base64Encoded: args[1]), keyData.count == 32 else { reject("Invalid public key") }
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
    let data = try Data(contentsOf: URL(fileURLWithPath: args[2]))
    var content = data
    var signature = args[3]
    if signature == "--feed" {
        let prefix = Data("<!-- sparkle-signatures:\n".utf8)
        guard let start = data.range(of: prefix, options: .backwards),
              let end = data.range(of: Data("-->".utf8), in: start.upperBound..<data.endIndex),
              let block = String(data: data[start.upperBound..<end.lowerBound], encoding: .utf8)
        else { reject("Missing feed signature block") }
        content = data[..<start.lowerBound]
        var fields: [String: String] = [:]
        for line in block.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 { fields[String(parts[0])] = parts[1].trimmingCharacters(in: .whitespaces) }
        }
        guard let value = fields["edSignature"], let length = fields["length"], Int(length) == content.count
        else { reject("Invalid feed signature metadata or length") }
        signature = value
        guard String(data: data[end.upperBound...], encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
        else { reject("Unexpected data after feed signature") }
    }
    guard let sig = Data(base64Encoded: signature), sig.count == 64,
          key.isValidSignature(sig, for: content) else { reject("REJECT: invalid EdDSA signature") }
    print("PASS: EdDSA signature verified with public key; signed bytes: \(content.count)")
} catch { reject("Verification failed: \(error)") }
