import Vapor
import GRDB
import Crypto
import Foundation

func routes(_ app: Application) throws {
    // Serve index.html at root
    app.get { req async throws -> Response in
        let path = app.directory.publicDirectory + "index.html"
        return req.fileio.streamFile(at: path)
    }
    let dbQueue = AppDatabase.shared!
    let auth = AuthService(db: dbQueue)
    let batcher = EventBatcher(db: dbQueue, logger: app.logger)
    let analytics = AnalyticsService(db: dbQueue, batcher: batcher)
    app.lifecycle.use(FlushOnShutdown(batcher: batcher))

    // Liveness for container health checks; touches the database.
    app.get("healthz") { req async throws -> HTTPStatus in
        _ = try await dbQueue.read { db in try Int.fetchOne(db, sql: "SELECT 1") }
        return .ok
    }

    /// Operator-only endpoints (viewer list with e-mail addresses). Off
    /// unless IAIPERK_ADMIN_EMAIL names the signed-in account.
    let adminEmail = ProcessInfo.processInfo.environment["IAIPERK_ADMIN_EMAIL"]?.lowercased()
    func requireAdmin(_ req: Request) async throws {
        guard let user = try await auth.user(for: req) else {
            throw Abort(.unauthorized, reason: "Sign in first.")
        }
        guard let adminEmail, !adminEmail.isEmpty, user.email == adminEmail else {
            throw Abort(.forbidden)
        }
    }

    // MARK: - Email-code auth

    struct CodeRequest: Content { var email: String }
    struct CodeResponse: Content { var ok: Bool; var message: String; var handle: String? }
    struct VerifyRequest: Content { var email: String; var code: String }
    struct VerifyResponse: Content {
        var ok: Bool
        var handle: String
        var email: String
        var isReturning: Bool
    }
    struct MeResponse: Content { var authenticated: Bool; var handle: String?; var email: String?; var isReturning: Bool }

    app.post("api", "auth", "request-code") { req async throws -> CodeResponse in
        let payload = try req.content.decode(CodeRequest.self)
        try await auth.requestCode(email: payload.email, logger: req.logger)
        // The real code is never echoed to the client.
        return CodeResponse(ok: true, message: "Check your email for a code.", handle: nil)
    }

    app.post("api", "auth", "verify") { req async throws -> Response in
        let payload = try req.content.decode(VerifyRequest.self)
        let (user, token) = try await auth.verify(email: payload.email, code: payload.code, req: req)

        await analytics.record(
            EventPayload(kind: EventKind.login, target: "verify", itemId: nil, meta: nil),
            user: user, sessionHash: Secrets.sha256Hex(token), trusted: true
        )

        let res = Response(status: .ok)
        let body = VerifyResponse(ok: true, handle: user.handle, email: user.email, isReturning: user.isReturning)
        try res.content.encode(body)
        res.headers.replaceOrAdd(name: .contentType, value: "application/json")
        res.cookies["iaiperk_session"] = HTTPCookies.Value(
            string: token,
            expires: Date().addingTimeInterval(60 * 60 * 24 * 30),
            isSecure: Environment.get("IAIPERK_COOKIE_SECURE") == "1",
            isHTTPOnly: true,
            sameSite: .lax
        )
        return res
    }

    app.post("api", "auth", "logout") { req async throws -> Response in
        let user = try await auth.user(for: req)
        if let hash = auth.sessionHash(for: req) {
            try await auth.logout(req: req)
            await analytics.record(
                EventPayload(kind: EventKind.logout, target: "logout", itemId: nil, meta: nil),
                user: user, sessionHash: hash, trusted: true
            )
        }
        let res = Response(status: .ok)
        try res.content.encode(CodeResponse(ok: true, message: "Signed out.", handle: nil))
        res.headers.replaceOrAdd(name: .contentType, value: "application/json")
        // Empty value + past expiry is how you clear a cookie.
        res.cookies["iaiperk_session"] = HTTPCookies.Value(string: "", expires: Date(), isHTTPOnly: true, sameSite: .lax)
        return res
    }

    app.get("api", "me") { req async throws -> MeResponse in
        guard let user = try await auth.user(for: req) else {
            return MeResponse(authenticated: false, handle: nil, email: nil, isReturning: false)
        }
        return MeResponse(authenticated: true, handle: user.handle, email: user.email, isReturning: user.isReturning)
    }

    // MARK: - Analytics events (click / item_view)

    app.post("api", "events") { req async throws -> HTTPStatus in
        let payload = try req.content.decode(EventPayload.self)
        await analytics.record(payload, user: try await auth.user(for: req),
                               sessionHash: auth.sessionHash(for: req))
        return .noContent
    }

    /// Who looked at what. Operator-only (see requireAdmin); no IPs echoed here.
    app.get("api", "viewers") { req async throws -> [AnalyticsService.ViewerRow] in
        try await requireAdmin(req)
        return try await analytics.viewers()
    }

    // MARK: - Chat

    app.post("api", "chat") { req async throws -> ChatMessage in
        guard let user = try await auth.user(for: req) else {
            throw Abort(.unauthorized, reason: "Sign in to chat.")
        }
        struct Body: Content { var body: String }
        let payload = try req.content.decode(Body.self)
        return try await analytics.post(body: payload.body, user: user)
    }

    app.get("api", "chat") { req async throws -> [ChatMessage] in
        guard try await auth.user(for: req) != nil else {
            throw Abort(.unauthorized, reason: "Sign in to read chat.")
        }
        return try await analytics.recent()
    }

    // MARK: - 24h chat purge
    //
    // Fires on startup and then hourly. Chat only: users/sessions/events are
    // left alone so login is unaffected by the purge.

    // Declared @Sendable because it runs on a scheduled task, not on the
    // request thread.
    let log = app.logger
    let sweeper: @Sendable () async -> Void = {
        do {
            let n = try await analytics.purgeOldChat()
            if n > 0 { log.notice("[retention] purged \(n) chat messages older than 24h") }
        } catch {
            log.error("[retention] purge failed: \(error)")
        }
    }

    if app.environment != .testing {
        app.eventLoopGroup.any().scheduleRepeatedTask(initialDelay: .seconds(0), delay: .seconds(3600)) { _ in
            Task { await sweeper() }
        }
    }

    // MARK: - Passkey / WebAuthn routes
    //
    // Flow A — Sign-in:   GET /challenge  →  navigator.credentials.get()  →  POST /authenticate
    // Flow B — Register:  POST /register/options (auth required)  →  navigator.credentials.create()  →  POST /register
    //
    // Crypto: P-256 ECDSA with SHA-256 (WebAuthn alg -7). We verify the
    // signature over SHA-256(authenticatorData ‖ SHA-256(clientDataJSON))
    // using swift-crypto's P256.Signing.PublicKey, which accepts the DER
    // SPKI encoding we extract from the COSE_Key stored at registration.

    let rpId   = ProcessInfo.processInfo.environment["IAIPERK_RP_ID"] ?? "iaiperk.orb.local"
    let rpName = ProcessInfo.processInfo.environment["IAIPERK_RP_NAME"] ?? "iaiperk"

    // Helpers shared by authenticate + register/options
    func makeChallenge() -> String {
        // 32 crypto-random bytes, Base64URL-encoded (no padding)
        let bytes = (0..<32).map { _ in UInt8.random(in: 0...255, using: &Secrets.systemRNG) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    func storeChallenge(_ challenge: String, db: DatabasePool) async throws {
        // Prune expired (>5 min old) challenges while we're here
        try await db.write { db in
            try db.execute(sql: "DELETE FROM passkey_challenges WHERE createdAt < ?",
                           arguments: [Date().addingTimeInterval(-300)])
            try db.execute(sql: "INSERT INTO passkey_challenges(challenge, createdAt) VALUES (?,?)",
                           arguments: [challenge, Date()])
        }
    }

    func consumeChallenge(_ challenge: String, db: DatabasePool) async throws -> Bool {
        try await db.write { db in
            let count = try Int.fetchOne(db,
                sql: "SELECT COUNT(*) FROM passkey_challenges WHERE challenge=? AND createdAt > ?",
                arguments: [challenge, Date().addingTimeInterval(-300)]) ?? 0
            if count > 0 {
                try db.execute(sql: "DELETE FROM passkey_challenges WHERE challenge=?", arguments: [challenge])
                return true
            }
            return false
        }
    }

    // Base64URL → Data (pads if needed)
    func b64urlDecode(_ s: String) -> Data? {
        var base64 = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let rem = base64.count % 4
        if rem != 0 { base64 += String(repeating: "=", count: 4 - rem) }
        return Data(base64Encoded: base64)
    }

    // Pull the authData byte string out of a CBOR attestation object
    // {"fmt":…, "attStmt":…, "authData": bstr} without a full CBOR parser.
    // We scan for the encoded map key "authData" (0x68 + 8 UTF-8 bytes) and
    // decode the byte-string header that must follow it. A candidate is only
    // accepted when its declared length fits the remaining bytes, so garbage
    // matches fall through and scanning continues.
    func extractAuthData(from attObj: Data) -> Data? {
        let bytes = [UInt8](attObj)
        let marker = [UInt8]([0x68]) + Array("authData".utf8)
        var i = 0
        while i + marker.count <= bytes.count {
            defer { i += 1 }
            guard Array(bytes[i..<i + marker.count]) == marker else { continue }
            var pos = i + marker.count
            guard pos < bytes.count else { continue }
            let header = bytes[pos]
            guard header >> 5 == 2 else { continue }          // major type 2: byte string
            let info = Int(header & 0x1F)
            var length: Int
            switch info {
            case 0...23:
                length = info
            case 24 where pos + 1 < bytes.count:
                length = Int(bytes[pos + 1]); pos += 1
            case 25 where pos + 2 < bytes.count:
                length = Int(bytes[pos + 1]) << 8 | Int(bytes[pos + 2]); pos += 2
            case 26 where pos + 4 < bytes.count:
                length = Int(bytes[pos + 1]) << 24 | Int(bytes[pos + 2]) << 16
                       | Int(bytes[pos + 3]) << 8 | Int(bytes[pos + 4]); pos += 4
            default:
                continue                                       // indefinite/unsupported → keep scanning
            }
            let start = pos + 1
            guard length > 0, start + length <= bytes.count else { continue }
            return Data(bytes[start..<start + length])
        }
        return nil
    }

    // COSE ES256 key {1:2, 3:-7, -1:1, -2:x(32B), -3:y(32B)} → DER SPKI so
    // swift-crypto can import it as a P-256 key. Authenticators emit
    // canonical CBOR (keys ordered 1, 3, -1, -2, -3), so the first
    // "<keyByte> 58 20" run after the previous coordinate is the real key;
    // a stray match inside the 32-byte values would fail the P-256 import
    // the register route performs anyway.
    func coseKeyToSPKI(_ cose: Data) -> Data? {
        let bytes = [UInt8](cose)
        func find(_ seq: [UInt8], from start: Int) -> Int? {
            guard start >= 0, start <= bytes.count else { return nil }
            var i = start
            while i + seq.count <= bytes.count {
                if Array(bytes[i..<i + seq.count]) == seq { return i }
                i += 1
            }
            return nil
        }
        // 0x21 = key -2 (x), 0x22 = key -3 (y); 0x58 0x20 = 32-byte string header
        guard let xAt = find([0x21, 0x58, 0x20], from: 0) else { return nil }
        guard let yAt = find([0x22, 0x58, 0x20], from: xAt + 3 + 32) else { return nil }
        let x = bytes[(xAt + 3)..<(xAt + 3 + 32)]
        let y = bytes[(yAt + 3)..<(yAt + 3 + 32)]
        // Fixed 26-byte SPKI header for P-256 (RFC 5480) + uncompressed point 0x04‖x‖y
        let spkiHeader: [UInt8] = [
            0x30, 0x59,                                     // SEQUENCE, 89 bytes
            0x30, 0x13,                                     //   SEQUENCE, 19 bytes
            0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, // OID id-ecPublicKey
            0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, // OID prime256v1
            0x03, 0x42, 0x00                                //   BIT STRING, 0 unused bits
        ]
        return Data(spkiHeader + [0x04] + x + y)
    }

    // ── GET /api/auth/passkey/challenge ─────────────────────────────────────
    struct ChallengeResponse: Content { var challenge: String; var rpId: String }

    app.get("api", "auth", "passkey", "challenge") { req async throws -> ChallengeResponse in
        let ch = makeChallenge()
        try await storeChallenge(ch, db: dbQueue)
        return ChallengeResponse(challenge: ch, rpId: rpId)
    }

    // ── POST /api/auth/passkey/authenticate ─────────────────────────────────
    struct AssertionRequest: Content {
        var id: String
        var rawId: String
        var type: String
        struct AssertionResponse: Codable {
            var authenticatorData: String   // Base64 (not URL) from the JS btoa()
            var clientDataJSON: String
            var signature: String
            var userHandle: String?
        }
        var response: AssertionResponse
    }
    struct PasskeyAuthResponse: Content { var ok: Bool; var handle: String; var email: String }

    app.post("api", "auth", "passkey", "authenticate") { req async throws -> Response in
        let body = try req.content.decode(AssertionRequest.self)

        // 1. Decode all the base64 blobs sent by the browser (btoa = standard base64)
        guard
            let authDataRaw  = Data(base64Encoded: body.response.authenticatorData),
            let clientJSON   = Data(base64Encoded: body.response.clientDataJSON),
            let sigRaw       = Data(base64Encoded: body.response.signature)
        else { throw Abort(.badRequest, reason: "Invalid base64 in assertion.") }

        // 2. Parse clientDataJSON and verify type + challenge
        struct ClientData: Decodable { var type: String; var challenge: String; var origin: String }
        let clientData = try JSONDecoder().decode(ClientData.self, from: clientJSON)
        guard clientData.type == "webauthn.get" else {
            throw Abort(.badRequest, reason: "Wrong ceremony type.")
        }

        // 3. Consume the challenge (replay protection)
        guard try await consumeChallenge(clientData.challenge, db: dbQueue) else {
            throw Abort(.badRequest, reason: "Challenge not found or expired.")
        }

        // 4. Look up the passkey record by credential ID
        let credId = body.id
        guard let passkeyRow = try await dbQueue.read({ db in
            try PasskeyRecord.filter(PasskeyRecord.Columns.id == credId).fetchOne(db)
        }) else {
            throw Abort(.unauthorized, reason: "No passkey registered for this credential.")
        }

        // 5. Verify the P-256 signature
        //    WebAuthn verification message = authData ‖ SHA256(clientDataJSON)
        let cdHash = Data(SHA256.hash(data: clientJSON))
        var message = authDataRaw
        message.append(cdHash)

        // publicKey is the COSE_Key stored as Base64URL at registration.
        // We stored it as the raw SPKI DER bytes for easy re-import.
        guard
            let pubKeyData = b64urlDecode(passkeyRow.publicKey),
            let pubKey = try? P256.Signing.PublicKey(derRepresentation: pubKeyData)
        else { throw Abort(.internalServerError, reason: "Could not load public key.") }

        // The browser sends a DER-encoded signature; swift-crypto accepts it.
        guard
            let sig = try? P256.Signing.ECDSASignature(derRepresentation: sigRaw),
            pubKey.isValidSignature(sig, for: message)
        else { throw Abort(.unauthorized, reason: "Signature verification failed.") }

        // 6. Update signCount (simple clone-detection: reject rollback)
        // authData bytes 33-36 are the sign count (big-endian uint32)
        let newCount = authDataRaw.count >= 37
            ? Int(authDataRaw[33]) << 24 | Int(authDataRaw[34]) << 16
              | Int(authDataRaw[35]) << 8  | Int(authDataRaw[36])
            : 0
        // Note: synced passkeys (backedUp=true) legitimately send signCount=0
        if !passkeyRow.backedUp && newCount <= passkeyRow.signCount && newCount != 0 {
            throw Abort(.unauthorized, reason: "Sign count decreased — possible cloned key.")
        }

        // 7. Resolve user and issue session cookie (same path as email OTP)
        let (user, token) = try await dbQueue.write { db -> (User, String) in
            try db.execute(sql: "UPDATE passkeys SET signCount=? WHERE id=?",
                           arguments: [newCount, credId])
            guard var u = try UserRecord.filter(UserRecord.Columns.id == passkeyRow.userId).fetchOne(db) else {
                throw Abort(.unauthorized, reason: "User not found.")
            }
            u.lastSeenAt = Date(); u.visitCount += 1; u.isReturning = true
            try u.update(db)
            let tok = Secrets.randomToken()
            let hash = Secrets.sha256Hex(tok)
            let ip = req.remoteAddress?.ipAddress ?? req.peerAddress?.ipAddress
            let ua = String((req.headers.first(name: .userAgent) ?? "").prefix(300))
            try SessionRecord(token: hash, userId: u.id, createdAt: Date(), lastSeenAt: Date(),
                              userAgent: ua, ip: ip).insert(db)
            return (User(id: u.id, email: u.email, handle: u.handle,
                         isReturning: u.isReturning, visitCount: u.visitCount), tok)
        }

        let res = Response(status: .ok)
        try res.content.encode(PasskeyAuthResponse(ok: true, handle: user.handle, email: user.email))
        res.headers.replaceOrAdd(name: .contentType, value: "application/json")
        res.cookies[AuthService.sessionCookie] = HTTPCookies.Value(
            string: token,
            expires: Date().addingTimeInterval(60 * 60 * 24 * 30),
            isSecure: Environment.get("IAIPERK_COOKIE_SECURE") == "1",
            isHTTPOnly: true,
            sameSite: .lax
        )
        return res
    }

    // ── POST /api/auth/passkey/register/options ──────────────────────────────
    struct RegistrationOptions: Content {
        struct RP: Codable { var name: String; var id: String }
        struct UserInfo: Codable { var id: String; var name: String; var displayName: String }
        struct CredParam: Codable { var type: String; var alg: Int }
        var challenge: String
        var rp: RP
        var user: UserInfo
        var pubKeyCredParams: [CredParam]
        var timeout: Int
        var attestation: String
    }

    app.post("api", "auth", "passkey", "register", "options") { req async throws -> RegistrationOptions in
        guard let user = try await auth.user(for: req) else {
            throw Abort(.unauthorized, reason: "Sign in first to register a passkey.")
        }
        let ch = makeChallenge()
        try await storeChallenge(ch, db: dbQueue)
        // Encode userId as Base64URL for the WebAuthn user.id buffer
        let userIdB64 = Data(user.id.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return RegistrationOptions(
            challenge: ch,
            rp: .init(name: rpName, id: rpId),
            user: .init(id: userIdB64, name: user.email, displayName: user.handle),
            pubKeyCredParams: [.init(type: "public-key", alg: -7)],  // ES256 / P-256
            timeout: 60000,
            attestation: "none"
        )
    }

    // ── POST /api/auth/passkey/register ──────────────────────────────────────
    struct RegistrationRequest: Content {
        var id: String
        var rawId: String
        var type: String
        struct AttestationResponse: Codable {
            var attestationObject: String   // Base64 (btoa)
            var clientDataJSON: String
            var transports: [String]
        }
        var response: AttestationResponse
    }

    app.post("api", "auth", "passkey", "register") { req async throws -> CodeResponse in
        guard let user = try await auth.user(for: req) else {
            throw Abort(.unauthorized, reason: "Sign in first.")
        }
        let body = try req.content.decode(RegistrationRequest.self)

        guard
            let clientJSON = Data(base64Encoded: body.response.clientDataJSON),
            let _ = Data(base64Encoded: body.response.attestationObject)
        else { throw Abort(.badRequest, reason: "Invalid base64 in registration.") }

        // Verify ceremony type + challenge
        struct ClientData: Decodable { var type: String; var challenge: String; var origin: String }
        let clientData = try JSONDecoder().decode(ClientData.self, from: clientJSON)
        guard clientData.type == "webauthn.create" else {
            throw Abort(.badRequest, reason: "Wrong ceremony type.")
        }
        guard try await consumeChallenge(clientData.challenge, db: dbQueue) else {
            throw Abort(.badRequest, reason: "Challenge not found or expired.")
        }

        // Extract the COSE public key from the attestation object.
        // For "none" attestation with packed/self format the authenticatorData
        // is at a fixed offset inside the CBOR attestation object. We parse it
        // minimally: skip the first 55 bytes of authData (rpIdHash[32] + flags[1]
        // + signCount[4] + aaguid[16] + credIdLen[2]) to get the credIdLen,
        // skip past the credential ID, then read the COSE key bytes.
        // We store the raw COSE key bytes as Base64URL; at verification time
        // we decode it as a DER SPKI key with swift-crypto.
        //
        // For this local-only deployment we store the raw credential ID as sent
        // by the browser (body.id) and the COSE public key extracted below.
        // A production server must do full CBOR parsing; here we use a pragmatic
        // approach: store the credential and try re-importing at verify time.

        guard let attObjData = Data(base64Encoded: body.response.attestationObject) else {
            throw Abort(.badRequest, reason: "Bad attestationObject.")
        }

        // Minimal CBOR decode: attestation object is a CBOR map with keys
        // "fmt", "attStmt", "authData". The authData value is a byte string.
        // We scan for the authData byte string by looking for the CBOR text
        // key "authData" (68 61 75 74 68 44 61 74 61) followed by a byte string header.
        guard let authData = extractAuthData(from: attObjData) else {
            throw Abort(.badRequest, reason: "Could not extract authData from attestation object.")
        }

        // authData layout (WebAuthn §6.1):
        // [0..31]  rpIdHash (32 bytes)
        // [32]     flags (1 byte)
        // [33..36] signCount (4 bytes, big-endian)
        // [37..52] aaguid (16 bytes)
        // [53..54] credentialIdLength (2 bytes, big-endian)
        // [55..55+L-1] credentialId
        // [55+L..] credentialPublicKey (COSE_Key, variable)
        guard authData.count > 55 else {
            throw Abort(.badRequest, reason: "authData too short.")
        }
        let credIdLen = Int(authData[53]) << 8 | Int(authData[54])
        let pubKeyOffset = 55 + credIdLen
        guard authData.count > pubKeyOffset else {
            throw Abort(.badRequest, reason: "authData credIdLen out of bounds.")
        }
        let coseKeyBytes = authData[pubKeyOffset...]

        // Convert COSE key (ES256 P-256) to DER SPKI for swift-crypto import.
        // COSE ES256 key map: {1:2, 3:-7, -1:1, -2:<x 32B>, -3:<y 32B>}
        // DER SPKI for P-256: fixed 26-byte header + 0x04 + x(32) + y(32)
        guard let spkiDER = coseKeyToSPKI(Data(coseKeyBytes)) else {
            throw Abort(.badRequest, reason: "Could not parse COSE public key.")
        }

        // Verify the key round-trips (we can import it later at verify time)
        guard let _ = try? P256.Signing.PublicKey(derRepresentation: spkiDER) else {
            throw Abort(.badRequest, reason: "Public key import failed — unsupported curve or format.")
        }

        let pubKeyB64url = spkiDER.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let transportsJSON = try String(data: JSONEncoder().encode(body.response.transports), encoding: .utf8) ?? "[]"

        try await dbQueue.write { db in
            // Upsert: re-registering the same device replaces the old record
            if var existing = try PasskeyRecord.filter(PasskeyRecord.Columns.id == body.id).fetchOne(db) {
                existing.publicKey = pubKeyB64url
                existing.signCount = 0
                existing.transports = transportsJSON
                try existing.update(db)
            } else {
                try PasskeyRecord(id: body.id, userId: user.id, publicKey: pubKeyB64url,
                                  signCount: 0, backedUp: true,
                                  transports: transportsJSON, createdAt: Date()).insert(db)
            }
        }
        return CodeResponse(ok: true, message: "Passkey registered.", handle: user.handle)
    }

    // GPU Providers
    app.get("api", "gpu") { req async throws -> [GPUProvider] in
        try await dbQueue.read { db in
            let records = try GPUProviderRecord.fetchAll(db)
            return records.map { $0.toGPUProvider(db: db) }
        }
    }

    app.get("api", "gpu", ":id") { req async throws -> GPUProvider in
        let id = req.parameters.get("id")!
        return try await dbQueue.read { db in
            guard let record = try GPUProviderRecord.filter(GPUProviderRecord.Columns.id == id).fetchOne(db) else {
                throw Abort(.notFound)
            }
            return record.toGPUProvider(db: db)
        }
    }

    // Perks
    app.get("api", "perks") { req async throws -> [Perk] in
        try await dbQueue.read { db in
            let records = try PerkRecord.fetchAll(db)
            return records.map { $0.toPerk() }
        }
    }

    app.get("api", "perks", ":id") { req async throws -> Perk in
        let id = req.parameters.get("id")!
        return try await dbQueue.read { db in
            guard let record = try PerkRecord.filter(PerkRecord.Columns.id == id).fetchOne(db) else {
                throw Abort(.notFound)
            }
            return record.toPerk()
        }
    }
}

// Extension to convert GRDB records to API models
extension GPUProviderRecord {
    func toGPUProvider(db: Database) -> GPUProvider {
        let hardware = try? HardwareRecord
            .filter(HardwareRecord.Columns.providerId == id)
            .fetchAll(db)
            .map { HardwareSpec(model: $0.model, vramGB: $0.vramGB) }

        return GPUProvider(
            id: id,
            name: name,
            type: type,
            offerType: offerType,
            account: account,
            bonus: bonus,
            bonusType: bonusType,
            expiry: expiry,
            expiryDetails: expiryDetails,
            creditCardRequired: creditCardRequired,
            hardware: nil, // We can add this later if needed
            hardwareDetails: hardware,
            region: region,
            details: details,
            link: link,
            bestFor: nil,
            eligibility: nil,
            requirements: nil,
            limitations: nil,
            stackingPotential: stackingPotential,
            sourceCategory: sourceCategory,
            lastVerified: lastVerified,
            confidenceLevel: confidenceLevel
        )
    }
}

extension PerkRecord {
    func toPerk() -> Perk {
        Perk(
            id: id,
            name: name,
            account: account,
            cat: cat,
            bonus: bonus,
            minDeposit: minDeposit,
            fee: fee,
            bonusType: bonusType,
            expiry: expiry,
            dd: dd,
            details: details,
            link: link,
            phase: phase
        )
    }
}

/// Writes buffered analytics events before the process exits.
struct FlushOnShutdown: LifecycleHandler {
    let batcher: EventBatcher
    func shutdown(_ application: Application) {
        let done = DispatchSemaphore(value: 0)
        Task { await batcher.flush(); done.signal() }
        _ = done.wait(timeout: .now() + 3)
    }
}
