import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOExtras
import Logging
import AsyncHTTPClient

/// Server bootstrap on SwiftNIO. No Vapor.
public enum Server {
    public static func makeRouter(context: AppContext) -> Router {
        let r = Router()
        registerCoreRoutes(r, context: context)
        registerAPIRoutes(r, context: context)
        registerUITestRoutes(r, context: context)   // HTML fragments for tests
        return r
    }

    private static func registerCoreRoutes(_ r: Router, context ctx: AppContext) {
        r.get("/healthz") { _ in
            Response.json(["status": "ok"])
        }
        r.get("/readyz") { _ in
            let esOK = await ctx.search.elastic?.ping() ?? false
            let backend = ctx.search.backendName
            let ready = backend == "memory" || esOK
            if ready {
                return Response.json(["status": "ready", "backend": backend, "index": ctx.config.elasticIndex, "docs": ctx.search.docs])
            } else {
                return Response.json(["status": "not_ready", "backend": backend, "reason": "elastic_unreachable"], status: .serviceUnavailable)
            }
        }
        r.get("/api/meta") { req in
            Response.json([
                "commit": ctx.config.gitCommit,
                "pod": ctx.config.podName,
                "backend": ctx.search.backendName,
                "semantic_mode": ctx.search.semanticMode ?? NSNull(),
                "index": ctx.config.elasticIndex,
                "docs": ctx.search.docs,
                "version": "1.0.0",
                "pod_instance": ctx.podInstanceID,
                "uptime_s": Int(Date().timeIntervalSince(ctx.startedAt))
            ])
        }
        // Keynote Rush trigger (R22): fires a real burst of simulated traffic.
        r.post("/api/rush") { req in
            let attendees = Int(req.query["n"] ?? "170") ?? 170
            let room = req.query["room"] ?? "Great Salt Hall"
            Task {
                // Simulate attendees opening agenda + searching.
                for i in 0..<attendees {
                    ctx.roomFill.checkIn(room: room, count: 1)
                    // Each attendee does a search.
                    var f = SearchFilters()
                    f.q = ["tracing", "kubernetes", "platform", "observability", "security", "finops", "edge", "ai"][i % 8]
                    f.limit = 10
                    _ = await ctx.search.search(f)
                    if i % 10 == 0 { try? await Task.sleep(nanoseconds: 50_000_000) }
                }
            }
            return Response.json(["ok": true, "attendees": attendees, "room": room, "note": "simulated load started"])
        }
        // Room fill snapshot (R17).
        r.get("/api/rooms") { _ in
            Response.json(ctx.roomFill.occupancySnapshot().mapValues { ["occupancy": $0.occupancy, "capacity": $0.capacity, "pct": $0.pct] })
        }
        r.post("/api/rooms/checkin") { req in
            let room = req.query["room"] ?? "Great Salt Hall"
            let n = Int(req.query["n"] ?? "1") ?? 1
            ctx.roomFill.checkIn(room: room, count: n)
            return Response.json(["ok": true, "room": room, "pct": ctx.roomFill.fillPercent(room)])
        }
        r.post("/api/rooms/reset") { _ in
            ctx.roomFill.reset()
            return Response.json(["ok": true])
        }
        // Agenda API (R16): per-device, no accounts.
        r.get("/api/agenda") { req in
            let device = req.query["device"] ?? "anon"
            let sessions = ctx.agendaStore.sessions(for: device, store: ctx.store)
            let clashes = ctx.agendaStore.clashes(sessions)
            return Response.json([
                "device": device,
                "count": sessions.count,
                "sessions": sessions.map { sessionJSON($0) },
                "clashes": clashes.map { ["a": $0.a.id, "b": $0.b.id] },
                "timezone": ctx.config.timezone
            ])
        }
        r.post("/api/agenda/add") { req in
            let device = req.query["device"] ?? "anon"
            let sid = req.query["id"] ?? ""
            guard ctx.store.byID(sid) != nil else {
                return Response.errorJSON(code: "not_found", message: "Session not found", status: .notFound)
            }
            let ok = ctx.agendaStore.add(device, sessionId: sid)
            return Response.json(["ok": ok, "count": ctx.agendaStore.get(device).count])
        }
        r.post("/api/agenda/remove") { req in
            let device = req.query["device"] ?? "anon"
            let sid = req.query["id"] ?? ""
            ctx.agendaStore.remove(device, sessionId: sid)
            return Response.json(["ok": true, "count": ctx.agendaStore.get(device).count])
        }
        r.post("/api/agenda/swap") { req in
            let device = req.query["device"] ?? "anon"
            let sid = req.query["id"] ?? ""
            guard let s = ctx.store.byID(sid) else {
                return Response.errorJSON(code: "not_found", message: "Session not found", status: .notFound)
            }
            let current = ctx.agendaStore.sessions(for: device, store: ctx.store)
            let ids = Set(current.map(\.id))
            if let swap = ctx.agendaStore.suggestSwap(for: s, in: ctx.store.sessions, excluding: ids) {
                return Response.json(["ok": true, "suggestion": sessionJSON(swap), "reason": "same slot, no clash"])
            }
            return Response.json(["ok": false, "reason": "no alternative in slot"])
        }
    }

    private static func sessionJSON(_ s: Session) -> [String: Any] {
        [
            "id": s.id, "title": s.title, "speaker": s.speaker, "track": s.track,
            "level": s.level, "day": s.day, "start": s.start, "duration_min": s.durationMin,
            "room": s.room, "abstract": s.abstractText, "tags": s.tags,
            "accessibility": [
                "captions": s.accessibility.captions,
                "sign_language": s.accessibility.signLanguage,
                "step_free_room": s.accessibility.stepFreeRoom,
                "quiet_room_nearby": s.accessibility.quietRoomNearby,
                "slides_alt_text": s.accessibility.slidesAltText
            ],
            "lang": s.lang, "timezone": s.timezone
        ]
    }

    private static func registerAPIRoutes(_ r: Router, context ctx: AppContext) {
        r.get("/api/search") { req in
            do {
                let f = try parseSearchFilters(req)
                let resp = await ctx.search.search(f)
                var out: [String: Any] = [
                    "q": f.q,
                    "backend": resp.backend,
                    "semantic_mode": resp.semanticMode ?? NSNull(),
                    "total": resp.total,
                    "limit": f.limit,
                    "latency_ms": resp.latencyMS,
                    "demo_slow": resp.demoSlow,
                    "trace_id": req.headers["x-trace-id"] ?? NSNull(),
                    "results": resp.results.map { hitJSON($0, fill: ctx.roomFill) }
                ]
                if let fr = resp.fallbackReason { out["fallback_reason"] = fr }
                if !resp.interpretedFilters.isEmpty { out["interpreted"] = resp.interpretedFilters }
                var headers = ["X-Backend": resp.backend]
                if resp.fallbackReason != nil { headers["X-Fallback"] = "memory" }
                return Response.json(out, headers: headers)
            } catch let e as SearchFilters.ParameterError {
                return Response.errorJSON(code: e.code, message: e.message, status: .badRequest, param: e.param)
            } catch {
                return Response.errorJSON(code: "internal", message: "Search failed", status: .internalServerError)
            }
        }
        r.get("/api/facets") { req in
            do {
                let f = try parseSearchFilters(req, allowQ: false)
                let (total, tracks, levels, days, rooms, access) = await ctx.search.facets(f)
                return Response.json([
                    "total": total,
                    "tracks": tracks, "levels": levels, "days": days, "rooms": rooms,
                    "accessibility": access
                ])
            } catch let e as SearchFilters.ParameterError {
                return Response.errorJSON(code: e.code, message: e.message, status: .badRequest, param: e.param)
            } catch {
                return Response.errorJSON(code: "internal", message: "Facets failed", status: .internalServerError)
            }
        }
    }

    private static func hitJSON(_ h: SearchHit, fill: RoomFillStore) -> [String: Any] {
        var d: [String: Any] = [
            "id": h.session.id, "title": h.session.title, "speaker": h.session.speaker,
            "track": h.session.track, "level": h.session.level, "day": h.session.day,
            "start": h.session.start, "duration_min": h.session.durationMin, "room": h.session.room,
            "abstract": h.session.abstractText, "tags": h.session.tags,
            "score": h.score,
            "accessibility": [
                "captions": h.session.accessibility.captions,
                "sign_language": h.session.accessibility.signLanguage,
                "step_free_room": h.session.accessibility.stepFreeRoom,
                "quiet_room_nearby": h.session.accessibility.quietRoomNearby,
                "slides_alt_text": h.session.accessibility.slidesAltText
            ],
            "room_fill_pct": fill.fillPercent(h.session.room)
        ]
        if let m = h.match { d["match"] = m.rawValue }
        if let ex = h.explanation { d["explanation"] = ex }
        return d
    }

    private static func parseSearchFilters(_ req: Request, allowQ: Bool = true) throws -> SearchFilters {
        var f = SearchFilters()
        if !allowQ && req.query["q"] != nil {
            throw SearchFilters.ParameterError(param: "q", message: "q not allowed on facets", code: "invalid_parameter")
        }
        f.q = (req.query["q"] ?? "").trimmingCharacters(in: .whitespaces)
        if f.q.count > 200 {
            throw SearchFilters.ParameterError(param: "q", message: "q too long (max 200)", code: "invalid_parameter")
        }
        if let t = req.query["track"], !t.isEmpty {
            guard SearchFilters.tracks.contains(t) else {
                throw SearchFilters.ParameterError(param: "track", message: "unknown track", code: "invalid_parameter")
            }
            f.track = t
        }
        if let l = req.query["level"], !l.isEmpty {
            guard SearchFilters.levels.contains(l) else {
                throw SearchFilters.ParameterError(param: "level", message: "unknown level", code: "invalid_parameter")
            }
            f.level = l
        }
        if let d = req.query["day"], !d.isEmpty {
            guard let di = Int(d), (1...3).contains(di) else {
                throw SearchFilters.ParameterError(param: "day", message: "day must be 1-3", code: "invalid_parameter")
            }
            f.day = di
        }
        // flags may be repeated or comma-separated; we accept both.
        var flagSet = Set<String>()
        if let flagsParam = req.query["flags"] {
            for part in flagsParam.split(separator: ",") {
                let name = String(part)
                guard SearchFilters.flagNames.contains(name) else {
                    throw SearchFilters.ParameterError(param: "flags", message: "unknown flag \(name)", code: "invalid_parameter")
                }
                flagSet.insert(name)
            }
        }
        // Also accept individual flag params like captions=true
        for name in SearchFilters.flagNames {
            if let v = req.query[name] {
                if v == "true" { flagSet.insert(name) }
                else if v == "false" {
                    throw SearchFilters.ParameterError(param: name, message: "only true is allowed", code: "invalid_parameter")
                } else {
                    throw SearchFilters.ParameterError(param: name, message: "must be true", code: "invalid_parameter")
                }
            }
        }
        f.flags = flagSet
        if let quiet = req.query["quiet"] {
            guard quiet == "true" || quiet == "1" else {
                throw SearchFilters.ParameterError(param: "quiet", message: "must be true", code: "invalid_parameter")
            }
            f.quietRoute = true
        }
        if let lim = req.query["limit"], !lim.isEmpty {
            guard let li = Int(lim), (1...50).contains(li) else {
                throw SearchFilters.ParameterError(param: "limit", message: "limit must be 1-50", code: "invalid_parameter")
            }
            f.limit = li
        }
        if let slow = req.query["slow"] {
            guard slow == "true" || slow == "1" else {
                throw SearchFilters.ParameterError(param: "slow", message: "must be true", code: "invalid_parameter")
            }
            f.slow = true
        }
        return f
    }

    /// /ui/* endpoints return HTML fragments for htmx. These are thin wrappers
    //  over the JSON paths so tests can assert on markup.
    private static func registerUITestRoutes(_ r: Router, context ctx: AppContext) {
        r.get("/ui/results") { req in
            // Rendered by Views in the app target; here we return a placeholder
            // that tests can match. The real implementation lives in App.
            Response.text("UI results fragment (implemented in App target)")
        }
    }
}
