import Foundation
import NIOCore

/// Room-fill signal (R17): simulated check-ins update per-room occupancy.
/// Metrics are exposed for OTEL and read by the UI badge and Quiet route.
public final class RoomFillStore: @unchecked Sendable {
    private var occupancy: [String: Int] = [:]   // room -> checked-in count
    private var capacity: [String: Int] = [:]    // room -> nominal capacity
    private let lock = NSLock()
    private var subscribers: [(String) -> Void] = []

    public init() {
        // Nominal capacities; clearly simulated.
        for (room, cap) in [
            "Great Salt Hall": 170, "Meeting Room A": 40, "Meeting Room B": 30,
            "Workshop Loft": 25, "Quiet Study": 12, "Keynote Balcony": 60
        ] {
            capacity[room] = cap
            occupancy[room] = 0
        }
    }

    public func checkIn(room: String, count: Int = 1) {
        lock.lock()
        occupancy[room, default: 0] += count
        lock.unlock()
        notify()
    }

    public func reset() {
        lock.lock()
        for k in occupancy.keys { occupancy[k] = 0 }
        lock.unlock()
        notify()
    }

    /// Simulate a burst: N attendees check into a room over a short window.
    public func simulateRush(room: String, attendees: Int) {
        for _ in 0..<attendees {
            checkIn(room: room, count: 1)
            Thread.sleep(forTimeInterval: 0.02)
        }
    }

    public func fill(_ room: String) -> Double {
        lock.lock(); defer { lock.unlock() }
        let cap = capacity[room] ?? 50
        let occ = occupancy[room] ?? 0
        return min(1.0, Double(occ) / Double(cap))
    }

    public func fillPercent(_ room: String) -> Int {
        Int((fill(room) * 100).rounded())
    }

    public func occupancySnapshot() -> [String: (occupancy: Int, capacity: Int, pct: Int)] {
        lock.lock(); defer { lock.unlock() }
        var out: [String: (Int, Int, Int)] = [:]
        for (room, cap) in capacity {
            let occ = occupancy[room] ?? 0
            out[room] = (occ, cap, Int((Double(occ)/Double(cap)*100).rounded()))
        }
        return out
    }

    public func onChange(_ cb: @escaping (String) -> Void) {
        lock.lock(); subscribers.append(cb); lock.unlock()
    }

    private func notify() {
        lock.lock(); let subs = subscribers; lock.unlock()
        let snap = occupancySnapshot()
        let json = (try? JSONSerialization.data(withJSONObject: snap.mapValues { ["occupancy": $0.occupancy, "capacity": $0.capacity, "pct": $0.pct] })) ?? Data()
        let str = String(data: json, encoding: .utf8) ?? "{}"
        for cb in subs { cb(str) }
    }
}
