import Foundation

/// Per-device agenda store. No accounts: the client sends an opaque device id
/// (localStorage) and we keep the picked session ids server-side in memory for
/// demo purposes; the UI also mirrors to localStorage so it works offline.
/// Time-zone correctness lives in the data (each Session carries `timezone`);
/// clash detection is pure Swift on wall-clock minutes.
public final class AgendaStore: @unchecked Sendable {
    private var agendas: [String: Set<String>] = [:]  // deviceId -> sessionIds
    private let lock = NSLock()

    public init() {}

    public func get(_ deviceId: String) -> Set<String> {
        lock.lock(); defer { lock.unlock() }
        return agendas[deviceId] ?? []
    }

    public func add(_ deviceId: String, sessionId: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        var set = agendas[deviceId] ?? []
        guard set.count < 100 else { return false }
        set.insert(sessionId)
        agendas[deviceId] = set
        return true
    }

    public func remove(_ deviceId: String, sessionId: String) {
        lock.lock(); defer { lock.unlock() }
        agendas[deviceId]?.remove(sessionId)
    }

    public func clear(_ deviceId: String) {
        lock.lock(); defer { lock.unlock() }
        agendas.removeValue(forKey: deviceId)
    }

    /// Resolve stored ids to Session objects, sorted by day then start.
    public func sessions(for deviceId: String, store: SessionStore) -> [Session] {
        get(deviceId).compactMap { store.byID($0) }.sorted { $0.sortKey < $1.sortKey }
    }

    /// Detect clashes: pairs of talks on the same day whose intervals overlap.
    public func clashes(_ sessions: [Session]) -> [(a: Session, b: Session)] {
        var out: [(Session, Session)] = []
        for i in 0..<sessions.count {
            for j in (i+1)..<sessions.count {
                let a = sessions[i], b = sessions[j]
                if a.day == b.day {
                    let aS = Session.minutes(a.start), aE = aS + a.durationMin
                    let bS = Session.minutes(b.start), bE = bS + b.durationMin
                    if aS < bE && bS < aE { out.append((a, b)) }
                }
            }
        }
        return out
    }

    /// Suggest a swap: find a session in the same day/time window that does not
    /// clash and shares a track or tag with the clashing one.
    public func suggestSwap(for session: Session, in all: [Session], excluding ids: Set<String>) -> Session? {
        let sMin = Session.minutes(session.start)
        let eMin = sMin + session.durationMin
        let candidates = all.filter { s in
            guard !ids.contains(s.id), s.id != session.id else { return false }
            guard s.day == session.day else { return false }
            let cs = Session.minutes(s.start), ce = cs + s.durationMin
            // Must fit inside or overlap the slot loosely (same day, within 60 min window)
            return abs(cs - sMin) <= 60 && !(cs < eMin && sMin < ce)
        }
        // Prefer same track, then shared tags.
        return candidates.sorted { a, b in
            let aTrack = a.track == session.track ? 1 : 0
            let bTrack = b.track == session.track ? 1 : 0
            if aTrack != bTrack { return aTrack > bTrack }
            let aTags = Set(a.tags).intersection(Set(session.tags)).count
            let bTags = Set(b.tags).intersection(Set(session.tags)).count
            return aTags > bTags
        }.first
    }
}
