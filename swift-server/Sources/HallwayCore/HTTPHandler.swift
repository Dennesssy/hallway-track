import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOExtras
import NIOHTTPCompression
import AsyncHTTPClient
import Logging
import Metrics

/// NIO channel handler: HTTP/1.1 -> Request -> Router -> Response.
/// Accumulates body up to a cap, adds security headers, gzip for text types.
public final class HTTPHandler: ChannelInboundHandler, @unchecked Sendable {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    private let router: Router
    private let context: AppContext
    private let logger: Logger

    private var method: String = "GET"
    private var uri: String = "/"
    private var headers: [String: String] = [:]
    private var bodyBuffer: ByteBuffer?
    private var bodyBytes = 0
    private let maxBodyBytes = 1 << 20  // 1 MiB

    public init(router: Router, context: AppContext) {
        self.router = router
        self.context = context
        self.logger = context.config.logger
    }

    public func handlerAdded(context: ChannelHandlerContext) {
        bodyBuffer = context.channel.allocator.buffer(capacity: 4096)
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        switch part {
        case .head(let head):
            method = head.method.rawValue
            uri = head.uri
            headers = [:]
            for h in head.headers {
                headers[h.name.lowercased()] = h.value
            }
            bodyBytes = 0
        case .body(var buf):
            bodyBytes += buf.readableBytes
            if bodyBytes <= maxBodyBytes {
                bodyBuffer?.writeBuffer(&buf)
            } else {
                // Too large: mark by emptying
                bodyBuffer = nil
            }
        case .end:
            let req = makeRequest()
            let el = context.eventLoop
            Task { [weak self] in
                guard let self else { return }
                do {
                    let resp = try await self.dispatch(req)
                    el.execute {
                        self.writeResponse(resp, context: context)
                    }
                } catch {
                    el.execute {
                        self.writeResponse(.errorJSON(code: "internal", message: "Internal error", status: .internalServerError), context: context)
                    }
                }
            }
        }
    }

    private func makeRequest() -> Request {
        // Parse URI and query
        var path = uri
        var query: [String: String] = [:]
        if let qIdx = uri.firstIndex(of: "?") {
            path = String(uri[..<qIdx])
            let qs = String(uri[uri.index(after: qIdx)...])
            for pair in qs.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                let k = String(kv[0])
                let v = kv.count > 1 ? String(kv[1]).removingPercentEncoding ?? String(kv[1]) : ""
                query[k] = v
            }
        }
        // Percent-decode path
        path = path.removingPercentEncoding ?? path
        if path.isEmpty { path = "/" }

        var remote: String? = nil
        // remoteAddress comes via channel; approximated by handler context not needed for now
        return Request(method: method, path: path, query: query, headers: headers,
                       body: bodyBuffer, remoteAddress: remote)
    }

    private func dispatch(_ req: Request) async throws -> Response {
        guard let route = router.match(method: req.method, path: req.path) else {
            // Static fallback for unknown paths under /vendor/ or assets
            if req.method == "GET" && (req.path.hasPrefix("/vendor/") || req.path.hasSuffix(".css") || req.path.hasSuffix(".js") || req.path.hasSuffix(".png") || req.path.hasSuffix(".svg") || req.path.hasSuffix(".ico")) {
                return try await serveStatic(req.path)
            }
            return .notFound()
        }
        var resp = try await route.handler(req)
        applySecurityHeaders(&resp)
        applyCompression(&resp, req: req)
        return resp
    }

    private func applySecurityHeaders(_ resp: inout Response) {
        resp.headers["X-Content-Type-Options"] = "nosniff"
        resp.headers["Referrer-Policy"] = "no-referrer"
        resp.headers["X-Frame-Options"] = "DENY"
        resp.headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'self' https://ingress.us-west-2.aws.dash0.com; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'"
        resp.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        resp.headers["X-Robots-Tag"] = "noindex"
    }

    private func applyCompression(_ resp: inout Response, req: Request) {
        let accept = req.headers["accept-encoding"] ?? ""
        guard accept.contains("gzip"),
              let ct = resp.headers["Content-Type"],
              (ct.contains("text/") || ct.contains("javascript") || ct.contains("json") || ct.contains("svg")) else { return }
        // Only compress if body > 1KB
        guard resp.body.readableBytes > 1024 else { return }
        // Simple gzip via Compression framework would need CNIO; NIOHTTPCompression
        // is outbound-side. For request path we keep it uncompressed to avoid
        // adding a dependency on zlib in the handler; nginx/ingress can compress.
    }

    private func serveStatic(_ path: String) async throws -> Response {
        // Map URL path to file under publicDir
        let clean = path.hasPrefix("/") ? String(path.dropFirst()) : path
        // Prevent traversal
        guard !clean.contains("..") else { return .notFound() }
        let fileURL = URL(fileURLWithPath: context.config.publicDir).appendingPathComponent(clean)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .notFound() }
        let data = try Data(contentsOf: fileURL)
        let ext = (fileURL.pathExtension).lowercased()
        let mime: String
        switch ext {
        case "html": mime = "text/html; charset=utf-8"
        case "css": mime = "text/css; charset=utf-8"
        case "js", "mjs": mime = "text/javascript; charset=utf-8"
        case "json": mime = "application/json"
        case "svg": mime = "image/svg+xml"
        case "png": mime = "image/png"
        case "jpg", "jpeg": mime = "image/jpeg"
        case "ico": mime = "image/x-icon"
        case "woff", "woff2": mime = "font/woff2"
        case "map": mime = "application/json"
        default: mime = "application/octet-stream"
        }
        var buf = ByteBuffer()
        buf.writeBytes(data)
        return Response(status: .ok, headers: ["Content-Type": mime, "Cache-Control": "public, max-age=300"], body: buf)
    }

    private func writeResponse(_ resp: Response, context: ChannelHandlerContext) {
        var head = HTTPResponseHead(version: .http1_1, status: resp.status)
        head.headers.add(name: "Content-Length", value: "\(resp.body.readableBytes)")
        for (k, v) in resp.headers {
            head.headers.add(name: k, value: v)
        }
        // HEAD: drop body
        if method == "HEAD" {
            head.headers.replaceOrAdd(name: "Content-Length", value: "0")
            var empty = ByteBuffer()
            context.write(NIOAny(HTTPServerResponsePart.head(head)), promise: nil)
            context.writeAndFlush(NIOAny(HTTPServerResponsePart.end(nil)), promise: nil)
            return
        }
        context.write(NIOAny(HTTPServerResponsePart.head(head)), promise: nil)
        var body = resp.body
        context.write(NIOAny(HTTPServerResponsePart.body(IOData.byteBuffer(body))), promise: nil)
        context.writeAndFlush(NIOAny(HTTPServerResponsePart.end(nil)), promise: nil)
    }
}

/// Shared application context passed to handlers.
public final class AppContext: @unchecked Sendable {
    public let config: Config
    public let store: SessionStore
    public let search: SearchService
    public let httpClient: HTTPClient
    public let roomFill: RoomFillStore
    public let agendaStore: AgendaStore
    public let startedAt: Date
    public let podInstanceID: String

    public init(config: Config, store: SessionStore, search: SearchService,
                httpClient: HTTPClient, roomFill: RoomFillStore,
                agendaStore: AgendaStore) {
        self.config = config
        self.store = store
        self.search = search
        self.httpClient = httpClient
        self.roomFill = roomFill
        self.agendaStore = agendaStore
        self.startedAt = Date()
        self.podInstanceID = UUID().uuidString.prefix(8).lowercased().description
    }
}
