import GRDB
import Foundation

enum Seeds {
    static func run() throws {
        let db = AppDatabase.shared!

        // Check if data already exists
        let count = try db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM gpu_providers") ?? 0
        }

        let seedDir = ProcessInfo.processInfo.environment["IAIPERK_SEED_DIR"]
            ?? FileManager.default.currentDirectoryPath + "/SeedData"

        if count > 0 {
            // Providers are seeded once. Perks are catalogue data with no user
            // rows attached, so they are refreshed from the JSON on every start.
            let perks = try JSONDecoder().decode(
                [Perk].self, from: Data(contentsOf: URL(fileURLWithPath: seedDir + "/perks-mix-verbose.json")))
            try db.write { db in
                for p in perks {
                    try PerkRecord(
                        id: p.id, name: p.name, account: p.account, cat: p.cat, bonus: p.bonus,
                        minDeposit: p.minDeposit, fee: p.fee, bonusType: p.bonusType, expiry: p.expiry,
                        dd: p.dd, details: p.details, link: p.link, phase: p.phase
                    ).save(db)
                }
            }
            print("Database already seeded with \(count) providers; refreshed \(perks.count) perks")
            return
        }

        // Load GPU providers from JSON
        let gpuURL = URL(fileURLWithPath: seedDir + "/gpu-providers-v2.json")
        let gpuData = try Data(contentsOf: gpuURL)
        let gpuProviders = try JSONDecoder().decode([GPUProvider].self, from: gpuData)

        // Load perks from JSON
        let perksURL = URL(fileURLWithPath: seedDir + "/perks-mix-verbose.json")
        let perksData = try Data(contentsOf: perksURL)
        let perks = try JSONDecoder().decode([Perk].self, from: perksData)

        try db.write { db in
            // Insert GPU providers
            for p in gpuProviders {
                let record = GPUProviderRecord(
                    id: p.id,
                    name: p.name,
                    type: p.type,
                    offerType: p.offerType,
                    account: p.account,
                    bonus: p.bonus,
                    bonusType: p.bonusType,
                    expiry: p.expiry,
                    expiryDetails: p.expiryDetails,
                    creditCardRequired: p.creditCardRequired,
                    region: p.region,
                    details: p.details,
                    link: p.link,
                    stackingPotential: p.stackingPotential,
                    sourceCategory: p.sourceCategory,
                    lastVerified: p.lastVerified,
                    confidenceLevel: p.confidenceLevel
                )
                try record.insert(db)

                // Insert hardware details (ignore duplicates)
                if let hardware = p.hardwareDetails {
                    for h in hardware {
                        let hw = HardwareRecord(
                            providerId: p.id,
                            model: h.model,
                            vramGB: h.vramGB
                        )
                        try? hw.insert(db) // ignore duplicates
                    }
                }
            }

            // Insert perks
            for p in perks {
                let record = PerkRecord(
                    id: p.id,
                    name: p.name,
                    account: p.account,
                    cat: p.cat,
                    bonus: p.bonus,
                    minDeposit: p.minDeposit,
                    fee: p.fee,
                    bonusType: p.bonusType,
                    expiry: p.expiry,
                    dd: p.dd,
                    details: p.details,
                    link: p.link,
                    phase: p.phase
                )
                try record.insert(db)
            }
        }

        print("Seeded \(gpuProviders.count) GPU providers and \(perks.count) perks into SQLite")
    }
}
