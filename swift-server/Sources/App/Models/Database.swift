import GRDB
import Foundation

struct AppDatabase {
    /// WAL-mode pool: many concurrent readers plus one writer. A plain
    /// DatabaseQueue runs every query, reads included, one at a time.
    static var shared: DatabasePool!
    static var path = ""

    static func setup() throws {
        let env = ProcessInfo.processInfo.environment
        path = env["IAIPERK_DB"]
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("iaiperk.sqlite").path
        let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var config = Configuration()
        config.busyMode = .timeout(5)
        config.maximumReaderCount = 8
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA synchronous = NORMAL")   // safe under WAL
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        let dbQueue = try DatabasePool(path: path, configuration: config)
        shared = dbQueue
        try Secrets.loadPepper(nextTo: path)

        // Owner-only: the file holds emails and login hashes.
        for suffix in ["", "-wal", "-shm"] {
            chmod(path + suffix, 0o600)
        }

        try dbQueue.write { db in
            try db.create(table: "gpu_providers", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("type", .text).notNull()
                t.column("offerType", .text).notNull()
                t.column("account", .text)
                t.column("bonus", .integer)
                t.column("bonusType", .text)
                t.column("expiry", .text)
                t.column("expiryDetails", .text)
                t.column("creditCardRequired", .boolean).notNull().defaults(to: false)
                t.column("region", .text).notNull()
                t.column("details", .text).notNull()
                t.column("link", .text)
                t.column("stackingPotential", .boolean).notNull().defaults(to: false)
                t.column("sourceCategory", .text).notNull()
                t.column("lastVerified", .text)
                t.column("confidenceLevel", .text)
            }

            try db.create(table: "provider_hardware", ifNotExists: true) { t in
                t.column("provider_id", .text).notNull()
                    .references("gpu_providers", onDelete: .cascade)
                t.column("model", .text).notNull()
                t.column("vram_gb", .double)
                t.primaryKey(["provider_id", "model"])
            }

            try db.create(table: "perks", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("account", .text).notNull()
                t.column("cat", .text).notNull()
                t.column("bonus", .integer)
                t.column("minDeposit", .integer)
                t.column("fee", .double)
                t.column("bonusType", .text).notNull()
                t.column("expiry", .text)
                t.column("dd", .text)
                t.column("details", .text).notNull()
                t.column("link", .text).notNull()
                t.column("phase", .integer).notNull()
            }

            try createIdentityTables(db)
        }

        var migrator = DatabaseMigrator()
        // v2: secrets are now stored as digests. Raw tokens/codes written by
        // the earlier version are useless as digests, so drop them (users
        // sign in again) and clear raw tokens from event rows.
        migrator.registerMigration("v2-hash-secrets") { db in
            try db.execute(sql: "DELETE FROM sessions")
            try db.execute(sql: "DELETE FROM email_codes")
            try db.execute(sql: "UPDATE events SET sessionToken = NULL")
            let cols = try db.columns(in: "email_codes").map(\.name)
            if !cols.contains("attempts") {
                try db.execute(sql: "ALTER TABLE email_codes ADD COLUMN attempts INTEGER NOT NULL DEFAULT 0")
            }
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS events_userId ON events(userId)")
        }
        try migrator.migrate(dbQueue)
    }

    /// Identity, session, event and chat tables. Kept separate so the
    /// 24h chat purge can never touch auth or analytics retention.
    static func createIdentityTables(_ db: Database) throws {
        try db.create(table: "email_codes", ifNotExists: true) { t in
            t.column("email", .text).notNull()
            t.column("code", .text).notNull()
            t.column("createdAt", .datetime).notNull()
            t.column("consumedAt", .datetime)
            t.primaryKey(["email", "code"])
        }

        try db.create(table: "users", ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("email", .text).notNull().unique()
            t.column("handle", .text).notNull()
            t.column("createdAt", .datetime).notNull()
            t.column("lastSeenAt", .datetime).notNull()
            t.column("isReturning", .boolean).notNull().defaults(to: false)
            t.column("visitCount", .integer).notNull().defaults(to: 1)
        }

        try db.create(table: "sessions", ifNotExists: true) { t in
            t.column("token", .text).primaryKey()
            t.column("userId", .text).notNull()
                .references("users", onDelete: .cascade)
            t.column("createdAt", .datetime).notNull()
            t.column("lastSeenAt", .datetime).notNull()
            t.column("userAgent", .text)
            t.column("ip", .text)
        }
        // GRDB 7: no ifNotExists on index creation, and autoincrement PKs
        // use autoIncrementedPrimaryKey.
        try? db.create(indexOn: "sessions", columns: ["userId"])

        try db.create(table: "passkeys", ifNotExists: true) { t in
            t.primaryKey("id", .text)
            t.column("userId", .text).notNull()
                .references("users", column: "id", onDelete: .cascade)
            t.column("publicKey", .text).notNull()
            t.column("signCount", .integer).notNull().defaults(to: 0)
            t.column("backedUp", .boolean).notNull().defaults(to: true)
            t.column("transports", .text)
            t.column("createdAt", .datetime).notNull()
        }

        // Short-lived WebAuthn challenges (TTL 5 min). One row per in-flight
        // authentication or registration ceremony; cleaned up on use or expiry.
        try db.create(table: "passkey_challenges", ifNotExists: true) { t in
            t.column("challenge", .text).primaryKey()   // Base64URL 32 random bytes
            t.column("createdAt", .datetime).notNull()
        }

        try db.create(table: "events", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("kind", .text).notNull()
            t.column("userId", .text)
            t.column("sessionToken", .text)
            t.column("target", .text)
            t.column("itemId", .text)
            t.column("meta", .text)
            t.column("createdAt", .datetime).notNull()
        }
        try? db.create(indexOn: "events", columns: ["kind"])
        try? db.create(indexOn: "events", columns: ["itemId"])
        try? db.create(indexOn: "events", columns: ["sessionToken"])

        try db.create(table: "chat_messages", ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("userId", .text).notNull()
            t.column("handle", .text).notNull()
            t.column("body", .text).notNull()
            t.column("createdAt", .datetime).notNull()
        }
        try? db.create(indexOn: "chat_messages", columns: ["createdAt"])
    }
}

struct GPUProviderRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "gpu_providers"

    var id: String
    var name: String
    var type: String
    var offerType: String
    var account: String?
    var bonus: Int?
    var bonusType: String?
    var expiry: String?
    var expiryDetails: String?
    var creditCardRequired: Bool
    var region: String
    var details: String
    var link: String?
    var stackingPotential: Bool
    var sourceCategory: String
    var lastVerified: String?
    var confidenceLevel: String?

    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let type = Column("type")
        static let offerType = Column("offerType")
        static let creditCardRequired = Column("creditCardRequired")
        static let region = Column("region")
        static let stackingPotential = Column("stackingPotential")
    }
}

struct HardwareRecord {
    static let databaseTableName = "provider_hardware"

    let providerId: String
    let model: String
    let vramGB: Double?

    enum Columns {
        static let providerId = Column("provider_id")
        static let model = Column("model")
        static let vramGB = Column("vram_gb")
    }
}

extension HardwareRecord: FetchableRecord {
    init(row: Row) {
        providerId = row["provider_id"]
        model = row["model"]
        vramGB = row["vram_gb"]
    }
}

extension HardwareRecord: PersistableRecord {
    func encode(to container: inout PersistenceContainer) {
        container["provider_id"] = providerId
        container["model"] = model
        container["vram_gb"] = vramGB
    }
}

struct PerkRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "perks"

    var id: String
    var name: String
    var account: String
    var cat: String
    var bonus: Int?
    var minDeposit: Int?
    var fee: Double?
    var bonusType: String
    var expiry: String?
    var dd: String?
    var details: String
    var link: String
    var phase: Int

    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let cat = Column("cat")
        static let phase = Column("phase")
    }
}
