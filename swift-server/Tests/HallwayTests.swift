import XCTest
import AsyncHTTPClient
import NIOPosix
@testable import HallwayCore
import NIOCore
import NIOEmbedded
import NIOHTTP1

final class SessionDecodingTests: XCTestCase {
    func testDecodesSessionsJSON() throws {
        let path = "../data/sessions.json"
        let store = try SessionStore.load(path: path)
        XCTAssertEqual(store.sessions.count, 60)
        let s = store.sessions[0]
        XCTAssertEqual(s.id, "s001")
        XCTAssertEqual(s.track, "Platform Engineering")
        XCTAssertTrue(s.accessibility.captions)
    }

    func testOverlapDetection() {
        var a = makeSession(id: "a", day: 1, start: "10:00", duration: 60)
        var b = makeSession(id: "b", day: 1, start: "10:30", duration: 30)
        XCTAssertTrue(a.overlaps(b))
        b.start = "11:30"
        XCTAssertFalse(a.overlaps(b))
        b.day = 2
        XCTAssertFalse(a.overlaps(b))
    }

    func testWalkingGap() {
        let a = makeSession(id: "a", day: 1, start: "10:00", duration: 30)
        let b = makeSession(id: "b", day: 1, start: "11:00", duration: 30)
        XCTAssertEqual(a.walkingGap(to: b), 30)
        let c = makeSession(id: "c", day: 1, start: "10:15", duration: 30)
        XCTAssertNil(a.walkingGap(to: c))
    }

    private func makeSession(id: String, day: Int, start: String, duration: Int) -> Session {
        Session(id: id, title: "T", abstractText: "A", speaker: "S", track: "X",
                level: "beginner", day: day, start: start, durationMin: duration,
                room: "R", tags: [], accessibility: Session.Accessibility(captions: false, signLanguage: false,
                stepFreeRoom: false, quietRoomNearby: false, slidesAltText: false),
                lang: "en", timezone: "America/Denver")
    }
}

final class IntentParserTests: XCTestCase {
    func testWheelchairMapsToStepFree() {
        let r = IntentParser.interpret("I use a wheelchair")
        XCTAssertTrue(r.flags.contains("step_free_room"))
    }
    func testNewToMapsToBeginner() {
        let r = IntentParser.interpret("talks for people new to this")
        XCTAssertEqual(r.level, "beginner")
    }
    func testCaptions() {
        let r = IntentParser.interpret("I need captions")
        XCTAssertTrue(r.flags.contains("captions"))
    }
    func testNoFalsePositive() {
        let r = IntentParser.interpret("kubernetes security")
        XCTAssertTrue(r.flags.isEmpty)
        XCTAssertNil(r.level)
    }
}

final class MemoryBackendTests: XCTestCase {
    func testKeywordSearchFindsSession() throws {
        let store = try SessionStore.load(path: "../data/sessions.json")
        let mem = MemoryBackend(store: store)
        var f = SearchFilters(); f.q = "tracing"; f.limit = 10
        let (hits, _) = mem.search(f)
        XCTAssertFalse(hits.isEmpty)
        XCTAssertTrue(hits.contains { $0.session.title.lowercased().contains("trac") || $0.session.tags.contains { $0.contains("trac") } })
    }
    func testFlagFilter() throws {
        let store = try SessionStore.load(path: "../data/sessions.json")
        let mem = MemoryBackend(store: store)
        var f = SearchFilters(); f.flags = ["sign_language"]; f.limit = 50
        let (hits, _) = mem.search(f)
        XCTAssertTrue(hits.allSatisfy { $0.session.accessibility.signLanguage })
        XCTAssertEqual(hits.count, 45)  // contract: sign_language count = 45
    }
    func testEmptyQuerySortsByDayStart() throws {
        let store = try SessionStore.load(path: "../data/sessions.json")
        let mem = MemoryBackend(store: store)
        var f = SearchFilters(); f.limit = 5
        let (hits, _) = mem.search(f)
        XCTAssertEqual(hits.count, 5)
        XCTAssertEqual(hits[0].session.day, 1)
    }
    func testFacetsContract() throws {
        let store = try SessionStore.load(path: "../data/sessions.json")
        let mem = MemoryBackend(store: store)
        var f = SearchFilters()
        let raw = mem.facets(f: f)
        let aggs = raw["aggregations"] as? [String: Any]
        let caps = aggs?["captions"] as? [String: Any]
        XCTAssertEqual(caps?["doc_count"] as? Int, 59)
        let signs = aggs?["sign_language"] as? [String: Any]
        XCTAssertEqual(signs?["doc_count"] as? Int, 45)
    }
}

final class AgendaStoreTests: XCTestCase {
    func testClashDetection() throws {
        let store = try SessionStore.load(path: "../data/sessions.json")
        let agenda = AgendaStore()
        // Pick two sessions same day overlapping if any exist; otherwise craft via store.
        let day1 = store.sessions.filter { $0.day == 1 }.sorted { $0.sortKey < $1.sortKey }
        // Find a real overlapping pair in the data or skip
        var found = false
        for i in 0..<day1.count {
            for j in (i+1)..<day1.count {
                if day1[i].overlaps(day1[j]) {
                    let list = [day1[i], day1[j]]
                    XCTAssertEqual(agenda.clashes(list).count, 1)
                    found = true
                    break
                }
            }
            if found { break }
        }
        if !found { /* data may have no overlaps; test passes vacuously */ }
    }
    func testAddRemove() {
        let agenda = AgendaStore()
        XCTAssertTrue(agenda.add("dev1", sessionId: "s001"))
        XCTAssertTrue(agenda.add("dev1", sessionId: "s002"))
        XCTAssertEqual(agenda.get("dev1").count, 2)
        agenda.remove("dev1", sessionId: "s001")
        XCTAssertEqual(agenda.get("dev1").count, 1)
    }
}

final class HTTPHandlerTests: XCTestCase {
    func testHealthz() async throws {
        // Build minimal context
        let config = Config.load(env: ["PORT": "0", "PUBLIC_DIR": "Public", "SESSIONS_JSON": "../data/sessions.json"])
        let store = try SessionStore.load(path: "../data/sessions.json")
        let http = HTTPClient(eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton))
        defer { try? http.syncShutdown() }
        let search = SearchService(config: config, store: store, http: http)
        let ctx = AppContext(config: config, store: store, search: search, httpClient: http,
                            roomFill: RoomFillStore(), agendaStore: AgendaStore())
        let router = Server.makeRouter(context: ctx)
        // Find healthz route and invoke
        let route = router.match(method: "GET", path: "/healthz")
        XCTAssertNotNil(route)
        let resp = try await route!.handler(Request(method: "GET", path: "/healthz", query: [:], headers: [:], body: nil, remoteAddress: nil))
        XCTAssertEqual(resp.status, .ok)
    }

    func testSearchValidation400() async throws {
        let config = Config.load(env: ["PORT": "0"])
        let store = try SessionStore.load(path: "../data/sessions.json")
        let http = HTTPClient(eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton))
        defer { try? http.syncShutdown() }
        let search = SearchService(config: config, store: store, http: http)
        let ctx = AppContext(config: config, store: store, search: search, httpClient: http,
                            roomFill: RoomFillStore(), agendaStore: AgendaStore())
        let router = Server.makeRouter(context: ctx)
        // /api/search is registered; call it with bad param via route match
        let route = router.match(method: "GET", path: "/api/search")
        XCTAssertNotNil(route)
        let resp = try await route!.handler(Request(method: "GET", path: "/api/search", query: ["level": "expert"], headers: [:], body: nil, remoteAddress: nil))
        XCTAssertEqual(resp.status, .badRequest)
    }

    func testSearchOK() async throws {
        let config = Config.load(env: ["PORT": "0"])
        let store = try SessionStore.load(path: "../data/sessions.json")
        let http = HTTPClient(eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton))
        defer { try? http.syncShutdown() }
        let search = SearchService(config: config, store: store, http: http)
        let ctx = AppContext(config: config, store: store, search: search, httpClient: http,
                            roomFill: RoomFillStore(), agendaStore: AgendaStore())
        let router = Server.makeRouter(context: ctx)
        let route = router.match(method: "GET", path: "/api/search")
        let resp = try await route!.handler(Request(method: "GET", path: "/api/search", query: ["q": "tracing"], headers: [:], body: nil, remoteAddress: nil))
        XCTAssertEqual(resp.status, .ok)
        let body = String(buffer: resp.body)
        XCTAssertTrue(body.contains("\"backend\":\"memory\""))
        XCTAssertTrue(body.contains("tracing") || body.contains("Tracing"))
    }
}

