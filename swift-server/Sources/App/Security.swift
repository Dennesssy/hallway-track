import Crypto
import Foundation

/// Hashing and randomness for secrets at rest. Session tokens and login
/// codes are stored only as digests, so a copy of the database file cannot
/// be replayed as a login.
enum Secrets {
    private static var pepper = Data()

    /// Server-side key for hashing login codes. Six-digit codes have only a
    /// million values, so a plain hash would be reversible; the HMAC key
    /// lives outside the database (env var, or a 0600 file beside it).
    static func loadPepper(nextTo dbPath: String) throws {
        if let env = ProcessInfo.processInfo.environment["IAIPERK_PEPPER"], env.count >= 16 {
            pepper = Data(env.utf8)
            return
        }
        let url = URL(fileURLWithPath: dbPath).deletingLastPathComponent().appendingPathComponent("pepper")
        if let existing = try? Data(contentsOf: url), existing.count >= 32 {
            pepper = existing
            return
        }
        let fresh = Data((0..<32).map { _ in UInt8.random(in: 0...255, using: &systemRNG) })
        try fresh.write(to: url, options: .atomic)
        chmod(url.path, 0o600)
        pepper = fresh
    }

    static var systemRNG = SystemRandomNumberGenerator()

    static func sha256Hex(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func codeDigest(email: String, code: String) -> String {
        let key = SymmetricKey(data: pepper)
        let mac = HMAC<SHA256>.authenticationCode(for: Data("\(email)|\(code)".utf8), using: key)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    static func randomToken() -> String {
        (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255, using: &systemRNG)) }.joined()
    }

    /// Uniform over 000000...999999 (no modulo bias).
    static func randomCode() -> String {
        String(format: "%06d", Int.random(in: 0..<1_000_000, using: &systemRNG))
    }
}
