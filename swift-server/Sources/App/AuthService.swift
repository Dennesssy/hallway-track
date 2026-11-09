import Vapor
import GRDB
import Foundation

/// Email-code verification, random handle assignment, and cookie sessions.
///
/// Identity = email. Handle = randomly generated, never derived from email.
/// A verified returning email maps to its existing user row, so the handle
/// is stable across visits.
///
/// Secrets at rest: login codes are stored as HMAC digests and session
/// tokens as SHA-256 digests. The raw values exist only in the e-mail/log
/// line and the cookie.
enum AuthError: Error {
    case badEmail, badCode, noCode
}

struct AuthService {
    let db: DatabasePool
    let codeTTL: TimeInterval = 10 * 60
    let sessionTTL: TimeInterval = 30 * 24 * 60 * 60
    let maxCodeAttempts = 5
    let codeCooldown: TimeInterval = 60
    /// How stale lastSeenAt may get before an authenticated read turns into a write.
    let touchInterval: TimeInterval = 60

    static let sessionCookie = "iaiperk_session"

    // MARK: - Step 1: request a code

    func requestCode(email: String, logger: Logger) async throws {
        let normalized = email.lowercased().trimmingCharacters(in: .whitespaces)
        guard normalized.count <= 254, normalized.contains("@"), normalized.contains(".") else {
            throw Abort(.badRequest, reason: "Enter a valid email address.")
        }

        let code = Secrets.randomCode()
        let digest = Secrets.codeDigest(email: normalized, code: code)

        let waited = try await db.write { db -> Bool in
            if let last = try EmailCodeRecord
                .filter(EmailCodeRecord.Columns.email == normalized)
                .fetchOne(db),
               Date().timeIntervalSince(last.createdAt) < codeCooldown {
                return true
            }
            // Invalidate anything previously issued for this address.
            try db.execute(sql: "DELETE FROM email_codes WHERE email = ?", arguments: [normalized])
            try EmailCodeRecord(email: normalized, code: digest, createdAt: Date(), consumedAt: nil, attempts: 0)
                .insert(db)
            return false
        }
        if waited {
            throw Abort(.tooManyRequests, reason: "A code was just sent. Wait a minute before asking again.")
        }

        // No SMTP configured in this project. With IAIPERK_LOG_CODES=1 the
        // code goes to the server log so the flow is testable locally; leave
        // it off anywhere real users sign in, and wire a mail provider here.
        // Uses the Vapor logger rather than print(): stdout is block-buffered
        // when redirected.
        if ProcessInfo.processInfo.environment["IAIPERK_LOG_CODES"] == "1" {
            logger.notice("[auth] verification code for \(normalized): \(code)")
        } else {
            logger.notice("[auth] verification code issued (delivery not configured)")
        }
    }

    // MARK: - Step 2: verify code, resolve new vs returning, create session

    private enum Outcome {
        case ok(UserRecord, token: String)
        case wrong, locked, used, expired
    }

    /// Everything happens in one transaction, so a wrong guess is counted
    /// (the attempt counter is committed, not rolled back with a throw) and
    /// a successful verify can never leave a half-created user or session.
    func verify(email: String, code: String, req: Request) async throws -> (user: User, token: String) {
        let normalized = email.lowercased().trimmingCharacters(in: .whitespaces)
        let digest = Secrets.codeDigest(email: normalized, code: code.trimmingCharacters(in: .whitespaces))
        let token = Secrets.randomToken()
        let tokenHash = Secrets.sha256Hex(token)
        let ip = req.remoteAddress?.ipAddress ?? req.peerAddress?.ipAddress
        let ua = String((req.headers.first(name: .userAgent) ?? "").prefix(300))
        let ttl = codeTTL, maxAttempts = maxCodeAttempts

        let outcome = try await db.write { db -> Outcome in
            guard let row = try EmailCodeRecord
                .filter(EmailCodeRecord.Columns.email == normalized)
                .fetchOne(db)
            else { return .wrong }

            if row.consumedAt != nil { return .used }
            if Date().timeIntervalSince(row.createdAt) > ttl { return .expired }
            if row.attempts >= maxAttempts { return .locked }

            guard row.code == digest else {
                try db.execute(
                    sql: "UPDATE email_codes SET attempts = attempts + 1 WHERE email = ?",
                    arguments: [normalized]
                )
                return row.attempts + 1 >= maxAttempts ? .locked : .wrong
            }

            try db.execute(
                sql: "UPDATE email_codes SET consumedAt = ? WHERE email = ?",
                arguments: [Date(), normalized]
            )

            let user: UserRecord
            if var rec = try UserRecord.filter(UserRecord.Columns.email == normalized).fetchOne(db) {
                rec.lastSeenAt = Date()
                rec.visitCount += 1
                rec.isReturning = true
                try rec.update(db)
                user = rec
            } else {
                // New user: mint an id and a handle with no relation to the email.
                var handle = Self.generateHandle()
                for _ in 0..<20 {
                    let taken = try Int.fetchOne(
                        db, sql: "SELECT COUNT(*) FROM users WHERE handle = ?", arguments: [handle]
                    ) ?? 0
                    if taken == 0 { break }
                    handle = Self.generateHandle()
                }
                let rec = UserRecord(
                    id: UUID().uuidString, email: normalized, handle: handle,
                    createdAt: Date(), lastSeenAt: Date(), isReturning: false, visitCount: 1
                )
                try rec.insert(db)
                user = rec
            }

            try SessionRecord(
                token: tokenHash, userId: user.id, createdAt: Date(), lastSeenAt: Date(),
                userAgent: ua, ip: ip
            ).insert(db)
            return .ok(user, token: token)
        }

        switch outcome {
        case .ok(let u, let token):
            return (User(id: u.id, email: u.email, handle: u.handle,
                         isReturning: u.visitCount > 1, visitCount: u.visitCount), token)
        case .wrong:
            throw Abort(.unauthorized, reason: "That code is not right.")
        case .locked:
            throw Abort(.tooManyRequests, reason: "Too many wrong codes. Request a new one.")
        case .used:
            throw Abort(.conflict, reason: "That code was already used. Request a new one.")
        case .expired:
            throw Abort(.gone, reason: "That code expired. Request a new one.")
        }
    }

    // MARK: - Session lookup for protected routes

    /// Digest of the request's session cookie, or nil if there is none.
    /// Also what event rows store, so they join to a session without
    /// holding a usable token.
    func sessionHash(for req: Request) -> String? {
        guard let token = req.cookies[Self.sessionCookie]?.string, !token.isEmpty else { return nil }
        return Secrets.sha256Hex(token)
    }

    /// Read-only on the hot path. lastSeenAt is refreshed only when stale,
    /// so authenticated GETs do not each take the single write lock.
    func user(for req: Request) async throws -> User? {
        guard let hash = sessionHash(for: req) else { return nil }
        let ttl = sessionTTL
        let found = try await db.read { db -> (User, Date)? in
            guard let s = try SessionRecord
                .filter(SessionRecord.Columns.token == hash)
                .fetchOne(db),
                Date().timeIntervalSince(s.createdAt) <= ttl,
                let u = try UserRecord.filter(UserRecord.Columns.id == s.userId).fetchOne(db)
            else { return nil }
            return (User(id: u.id, email: u.email, handle: u.handle,
                         isReturning: u.isReturning, visitCount: u.visitCount), s.lastSeenAt)
        }
        guard let (user, lastSeen) = found else { return nil }
        if Date().timeIntervalSince(lastSeen) > touchInterval {
            try? await db.write { db in
                try db.execute(sql: "UPDATE sessions SET lastSeenAt = ? WHERE token = ?",
                               arguments: [Date(), hash])
            }
        }
        return user
    }

    func logout(req: Request) async throws {
        guard let hash = sessionHash(for: req) else { return }
        try await db.write { db in
            try db.execute(sql: "DELETE FROM sessions WHERE token = ?", arguments: [hash])
        }
    }

    // MARK: - Helpers

    static func generateHandle() -> String {
        let adj = ["amber", "quiet", "bright", "swift", "calm", "lucky", "brave", "eager", "keen", "mellow", "sunny", "vivid"]
        let noun = ["falcon", "otter", "cedar", "harbor", "raven", "willow", "lynx", "canyon", "fox", "maple", "sparrow", "comet"]
        let a = adj.randomElement() ?? "swift"
        let n = noun.randomElement() ?? "falcon"
        let num = Int.random(in: 10...99)
        return "\(a)-\(n)-\(num)"
    }
}
