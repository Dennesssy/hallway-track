import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix
import Logging

/// Tiny router on top of NIOHTTP1. Patterns are exact paths or prefixes ending in "*".
public final class Router: @unchecked Sendable {
    public struct Route: Sendable {
        public var method: String
        public var pattern: String
        public var handler: @Sendable (Request) async throws -> Response
    }

    public private(set) var routes: [Route] = []

    public init() {}

    public func get(_ pattern: String, _ handler: @escaping @Sendable (Request) async throws -> Response) {
        routes.append(Route(method: "GET", pattern: pattern, handler: handler))
    }
    public func post(_ pattern: String, _ handler: @escaping @Sendable (Request) async throws -> Response) {
        routes.append(Route(method: "POST", pattern: pattern, handler: handler))
    }
    public func put(_ pattern: String, _ handler: @escaping @Sendable (Request) async throws -> Response) {
        routes.append(Route(method: "PUT", pattern: pattern, handler: handler))
    }
    public func delete(_ pattern: String, _ handler: @escaping @Sendable (Request) async throws -> Response) {
        routes.append(Route(method: "DELETE", pattern: pattern, handler: handler))
    }

    public func match(method: String, path: String) -> Route? {
        // Exact matches first
        for r in routes where r.method == method && r.pattern == path { return r }
        // Then prefix patterns
        for r in routes where r.method == method && r.pattern.hasSuffix("*") {
            let prefix = String(r.pattern.dropLast())
            if path.hasPrefix(prefix) { return r }
        }
        // HEAD falls back to GET
        if method == "HEAD" {
            for r in routes where r.method == "GET" && (r.pattern == path || (r.pattern.hasSuffix("*") && path.hasPrefix(String(r.pattern.dropLast())))) {
                return r
            }
        }
        return nil
    }
}

/// Normalized request view passed to handlers.
public struct Request: Sendable {
    public var method: String
    public var path: String
    public var query: [String: String]
    public var headers: [String: String]
    public var body: ByteBuffer?
    public var remoteAddress: String?

    public init(method: String, path: String, query: [String: String], headers: [String: String], body: ByteBuffer?, remoteAddress: String?) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
        self.remoteAddress = remoteAddress
    }
    public subscript(_ name: String) -> String? { query[name] }

    public func queryValues(_ name: String) -> [String] {
        // Supports repeated params like flags=captions&flags=step_free_room
        // Our router flattens to last-wins; we also accept comma lists.
        guard let v = query[name] else { return [] }
        return v.split(separator: ",").map { String($0) }
    }

    public var demoMode: Bool { query["demo"] == "1" }
}

/// Response with status, headers and body.
public struct Response: Sendable {
    public var status: HTTPResponseStatus
    public var headers: [String: String]
    public var body: ByteBuffer

    public init(status: HTTPResponseStatus = .ok, headers: [String: String] = [:], body: ByteBuffer = ByteBuffer()) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    public static func text(_ s: String, status: HTTPResponseStatus = .ok, headers: [String: String] = [:]) -> Response {
        var h = headers
        h["Content-Type"] = "text/plain; charset=utf-8"
        var buf = ByteBuffer()
        buf.writeString(s)
        return Response(status: status, headers: h, body: buf)
    }

    public static func html(_ s: String, status: HTTPResponseStatus = .ok, headers: [String: String] = [:]) -> Response {
        var h = headers
        h["Content-Type"] = "text/html; charset=utf-8"
        var buf = ByteBuffer()
        buf.writeString(s)
        return Response(status: status, headers: h, body: buf)
    }

    public static func json(_ obj: Any, status: HTTPResponseStatus = .ok, headers: [String: String] = [:]) -> Response {
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
        } catch {
            return .text("{\"error\":\"encode_failed\"}", status: .internalServerError)
        }
        var buf = ByteBuffer()
        buf.writeBytes(data)
        var h = headers
        h["Content-Type"] = "application/json"
        return Response(status: status, headers: h, body: buf)
    }

    public static func errorJSON(code: String, message: String, status: HTTPResponseStatus, param: String? = nil) -> Response {
        var err: [String: Any] = ["code": code, "message": message]
        if let param { err["param"] = param }
        return .json(["error": err], status: status)
    }

    public static func redirect(to path: String) -> Response {
        Response(status: .found, headers: ["Location": path])
    }

    public static func notFound() -> Response {
        .errorJSON(code: "not_found", message: "Not found", status: .notFound)
    }
}
