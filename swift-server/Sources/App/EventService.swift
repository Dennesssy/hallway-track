import Vapor
import GRDB
import Foundation

/// Click / view / login logging plus chat with a 24h retention window.
enum EventKind {
    static let click = "click"
    static let itemView = "item_view"
    static let login = "login"
    static let logout = "logout"
}

struct EventPayload: Content {
    var kind: String
    var target: String?
    var itemId: String?
    var meta: [String: String]?
}

/// Group commit for analytics. Events land in memory and are written in one
/// transaction every ~50 ms (or at 200 events), so a burst of clicks costs
/// one fsync-bearing commit instead of one per click. Trade-off: a crash
/// loses at most the last ~50 ms of analytics events; nothing else uses this.
actor EventBatcher {
    private let db: DatabasePool
    private var buffer: [EventRecord] = []
    private var flushPending = false
    private let maxBatch = 200
    private let maxBuffered = 10_000
    private let logger: Logger

    init(db: DatabasePool, logger: Logger) {
        self.db = db
        self.logger = logger
    }

    func add(_ record: EventRecord) {
        guard buffer.count < maxBuffered else { return }   // shed load rather than grow without bound
        buffer.append(record)
        if buffer.count >= maxBatch {
            Task { await self.flush() }
        } else if !flushPending {
            flushPending = true
            Task {
                try? await Task.sleep(nanoseconds: 50_000_000)
                await self.flush()
            }
        }
    }

    func flush() async {
        flushPending = false
        guard !buffer.isEmpty else { return }
        let batch = buffer
        buffer = []
        do {
            try await db.write { db in
                for r in batch { try r.insert(db) }
            }
        } catch {
            logger.error("[events] batch of \(batch.count) failed: \(error)")
            buffer.insert(contentsOf: batch.prefix(maxBuffered - buffer.count), at: 0)
        }
    }
}

struct AnalyticsService {
    let db: DatabasePool
    let batcher: EventBatcher

    static let chatRetention: TimeInterval = 24 * 60 * 60

    /// Kinds a browser may report. login/logout are written by the server only.
    static let clientKinds: Set<String> = [EventKind.click, EventKind.itemView]

    func record(_ payload: EventPayload, user: User?, sessionHash: String?, trusted: Bool = false) async {
        guard trusted || Self.clientKinds.contains(payload.kind) else { return }

        let metaJSON: String? = {
            guard let meta = payload.meta, !meta.isEmpty else { return nil }
            let capped = Dictionary(uniqueKeysWithValues:
                meta.prefix(20).map { (String($0.key.prefix(60)), String($0.value.prefix(200))) })
            guard let d = try? JSONEncoder().encode(capped) else { return nil }
            return String(data: d, encoding: .utf8)
        }()

        // No ip column on events: a session already carries the ip recorded
        // at login, so an event joins to it via the session digest instead of
        // duplicating the address on every row.
        await batcher.add(EventRecord(
            id: nil,
            kind: payload.kind,
            userId: user?.id,
            sessionToken: sessionHash,
            target: payload.target.map { String($0.prefix(200)) },
            itemId: payload.itemId.map { String($0.prefix(200)) },
            meta: metaJSON,
            createdAt: Date()
        ))
    }

    // MARK: - Chat

    func post(body: String, user: User) async throws -> ChatMessage {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw Abort(.badRequest, reason: "Message is empty.")
        }
        guard trimmed.count <= 2000 else {
            throw Abort(.badRequest, reason: "Message is too long (2000 max).")
        }

        let id: Int64? = try await db.write { db in
            let rec = ChatMessageRecord(id: nil, userId: user.id, handle: user.handle, body: trimmed, createdAt: Date())
            try rec.insert(db)
            return rec.id
        }
        return ChatMessage(id: id ?? 0, handle: user.handle, body: trimmed, createdAt: Date())
    }

    /// Last 100 messages within the retention window, oldest first.
    func recent() async throws -> [ChatMessage] {
        let cutoff = Date().addingTimeInterval(-Self.chatRetention)
        return try await db.read { db in
            let rows = try ChatMessageRecord
                .filter(ChatMessageRecord.Columns.createdAt >= cutoff)
                .order(ChatMessageRecord.Columns.createdAt.desc)
                .limit(100)
                .fetchAll(db)
            return rows.reversed().map {
                ChatMessage(id: $0.id ?? 0, handle: $0.handle, body: $0.body, createdAt: $0.createdAt)
            }
        }
    }

    /// Delete chat older than 24h. Chat only — users, sessions and events
    /// are deliberately NOT touched, so analytics survive the purge and a
    /// purged user can still log back in with their email.
    func purgeOldChat() async throws -> Int {
        let cutoff = Date().addingTimeInterval(-Self.chatRetention)
        return try await db.write { db in
            try ChatMessageRecord
                .filter(ChatMessageRecord.Columns.createdAt < cutoff)
                .deleteAll(db)
        }
    }

    // MARK: - Viewer reporting (the "what/who/where" readout)

    struct ViewerRow: Content {
        var email: String
        var handle: String
        var isReturning: Bool
        var visitCount: Int
        var views: Int
        var clicks: Int
        var lastSeen: Date
    }

    func viewers() async throws -> [ViewerRow] {
        try await db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT u.email, u.handle, u.isReturning, u.visitCount, u.lastSeenAt,
                       COALESCE(SUM(e.kind = 'item_view'), 0) AS views,
                       COALESCE(SUM(e.kind = 'click'), 0) AS clicks
                FROM users u LEFT JOIN events e ON e.userId = u.id
                GROUP BY u.id
                """)
            return rows.map { r in
                ViewerRow(email: r["email"], handle: r["handle"], isReturning: r["isReturning"],
                          visitCount: r["visitCount"], views: r["views"], clicks: r["clicks"],
                          lastSeen: r["lastSeenAt"])
            }
        }
    }
}

// ViewerRow already declares Content conformance where it's defined.

