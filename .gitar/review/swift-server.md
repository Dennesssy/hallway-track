# Swift server (SwiftNIO)

- Never block an event loop: no synchronous file, network or sleep calls inside request handlers. Use async/await and NIO's non-blocking APIs.
- Every request path returns a typed error response, never a crash: no `try!`, no force unwraps, no `fatalError` outside startup.
- Error bodies use the shared shape `{"error":{"code","param","message"}}` and never leak Elasticsearch details or stack traces.
- Validate every query parameter (length, enum, range). Unknown parameters are rejected with 400.
- Every response sets the security headers (nosniff, no-referrer, frame denial, Content-Security-Policy with no inline script).
- Shutdown is graceful: in-flight requests finish, event loop groups are shut down.
- Outbound Elasticsearch calls have timeouts and a bounded retry; a failure falls back and says so.
