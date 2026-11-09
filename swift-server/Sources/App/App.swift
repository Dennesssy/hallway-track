import Vapor

@main
struct IaiPerkApp {
    static func main() throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        umask(0o077)   // new files (database, WAL, pepper) are owner-only
        let app = Application(env)
        defer { app.shutdown() }

        app.http.server.configuration.responseCompression = .enabled

        // Serve static files from Public/ (index.html, etc.)
        app.middleware.use(FileMiddleware(
            publicDirectory: app.directory.publicDirectory
        ))

        try AppDatabase.setup()
        try Seeds.run()

        try routes(app)

        try app.run()
    }
}
