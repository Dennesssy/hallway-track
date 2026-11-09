import GRDB
import Foundation
import Vapor

// MARK: - Email verification code (6-digit, single-use, 10 minute TTL)
//
// NOTE ON EMAIL DELIVERY: this app does not send email. SMTP/SendGrid/etc.
// wiring is the operator's job (needs credentials in env). Until that exists,
// the generated code is logged to stdout so the flow can be tested locally.
// Treat that as a development affordance, not production behaviour.

struct EmailCodeRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "email_codes"

    var email: String
    var code: String        // HMAC digest, never the 6 digits
    var createdAt: Date
    var consumedAt: Date?
    var attempts: Int = 0

    enum Columns {
        static let email = Column("email")
        static let code = Column("code")
        static let createdAt = Column("createdAt")
        static let consumedAt = Column("consumedAt")
    }

    static let codeTTL: TimeInterval = 10 * 60
}

// MARK: - Users
//
// Identity is the email; the handle is display-only and randomly generated
// so it carries no relation to the email address. A returning email maps
// back to the existing user row, so the handle stays stable across visits.

struct UserRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "users"

    var id: String          // uuid
    var email: String
    var handle: String      // random, e.g. "amber-falcon-42"
    var createdAt: Date
    var lastSeenAt: Date
    var isReturning: Bool   // true once a second verified session occurs
    var visitCount: Int

    enum Columns {
        static let id = Column("id")
        static let email = Column("email")
        static let handle = Column("handle")
        static let createdAt = Column("createdAt")
        static let lastSeenAt = Column("lastSeenAt")
        static let isReturning = Column("isReturning")
        static let visitCount = Column("visitCount")
    }
}

struct User: Codable {
    let id: String
    let email: String
    let handle: String
    let isReturning: Bool
    let visitCount: Int
}

// MARK: - Sessions (login sessions)

struct SessionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "sessions"

    var token: String       // SHA-256 of the cookie value; the raw value is never stored
    var userId: String
    var createdAt: Date
    var lastSeenAt: Date
    var userAgent: String?
    var ip: String?

    enum Columns {
        static let token = Column("token")
        static let userId = Column("userId")
        static let createdAt = Column("createdAt")
        static let lastSeenAt = Column("lastSeenAt")
        static let ip = Column("ip")
    }
}

// MARK: - Passkeys (WebAuthn / Touch ID / Face ID)
//
// The private key NEVER leaves the device (Apple Secure Enclave / iCloud Keychain).
// We only store the credential ID (to look up which key signed the challenge)
// and the public key (to verify the signature).
// sign_count is a monotonically increasing counter that detects cloned keys.

struct PasskeyRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "passkeys"

    var id: String              // credential_id (Base64URL from WebAuthn)
    var userId: String          // → users.id
    var publicKey: String       // COSE public key, Base64URL-encoded
    var signCount: Int          // replay-attack counter; increment on every verify
    var backedUp: Bool          // true = synced across devices via iCloud Keychain
    var transports: String?     // JSON array e.g. '["internal","hybrid"]'
    var createdAt: Date

    enum Columns {
        static let id = Column("id")
        static let userId = Column("userId")
        static let publicKey = Column("publicKey")
        static let signCount = Column("signCount")
        static let backedUp = Column("backedUp")
        static let transports = Column("transports")
        static let createdAt = Column("createdAt")
    }
}

// MARK: - Events (clicks, views, logins)
//
// "which items are looked at" = item_view events. "whats click" = click
// events carrying the element + item id. Sessions are correlated via
// session_token so every event is attributable to a login session.

struct EventRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "events"

    var id: Int64?
    var kind: String        // "click" | "item_view" | "login" | "logout" | "verify"
    var userId: String?
    var sessionToken: String?   // session digest, not the cookie value
    var target: String?     // element id, tab name, row id...
    var itemId: String?     // gpu provider id or perk id, when applicable
    var meta: String?       // JSON blob
    var createdAt: Date

    enum Columns {
        static let kind = Column("kind")
        static let userId = Column("userId")
        static let sessionToken = Column("sessionToken")
        static let itemId = Column("itemId")
        static let createdAt = Column("createdAt")
    }
}

// MARK: - Chat with 24h retention

struct ChatMessageRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "chat_messages"

    var id: Int64?
    var userId: String
    var handle: String
    var body: String
    var createdAt: Date

    enum Columns {
        static let createdAt = Column("createdAt")
        static let userId = Column("userId")
    }
}

// Content conformance declared here, next to the type, because Sendable
// retroactive conformance must live in the same file.
struct ChatMessage: Codable, Content {
    let id: Int64
    let handle: String
    let body: String
    let createdAt: Date
}
