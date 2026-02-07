import Core
import Foundation
import SQLite3

public actor SQLiteDeploymentEventStore: DeploymentEventStore {
    private let dbURL: URL
    private var db: OpaquePointer?
    private var isReady = false

    public init(dbURL: URL? = nil) throws {
        self.dbURL = try dbURL ?? AppPaths.databaseURL()
    }

    public func persist(events: [DeploymentEvent]) async throws {
        guard !events.isEmpty else {
            return
        }

        try ensureReady()
        try execute("BEGIN TRANSACTION")

        do {
            let insertSQL = """
            INSERT OR REPLACE INTO deployment_events
            (id, deployment_id, created_at, level, message)
            VALUES (?, ?, ?, ?, ?)
            """

            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
                throw sqliteError(context: "prepare insert")
            }

            for event in events {
                sqlite3_bind_text(statement, 1, (event.id as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 2, (event.deploymentId as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(statement, 3, event.createdAt.timeIntervalSince1970)
                sqlite3_bind_text(statement, 4, (event.level as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 5, (event.message as NSString).utf8String, -1, SQLITE_TRANSIENT)

                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw sqliteError(context: "insert event")
                }

                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
            }

            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    public func load(deploymentId: String, limit: Int) async throws -> [DeploymentEvent] {
        try ensureReady()

        let sql = """
        SELECT id, deployment_id, created_at, level, message
        FROM deployment_events
        WHERE deployment_id = ?
        ORDER BY created_at DESC
        LIMIT ?
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(context: "prepare select")
        }

        sqlite3_bind_text(statement, 1, (deploymentId as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var rows: [DeploymentEvent] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idPtr = sqlite3_column_text(statement, 0),
                let deploymentPtr = sqlite3_column_text(statement, 1),
                let levelPtr = sqlite3_column_text(statement, 3),
                let messagePtr = sqlite3_column_text(statement, 4)
            else {
                continue
            }

            rows.append(
                DeploymentEvent(
                    id: String(cString: idPtr),
                    deploymentId: String(cString: deploymentPtr),
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                    level: String(cString: levelPtr),
                    message: String(cString: messagePtr)
                )
            )
        }

        return rows
    }

    public func purge(olderThan cutoff: Date) async throws {
        try ensureReady()

        let sql = "DELETE FROM deployment_events WHERE created_at < ?"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(context: "prepare purge")
        }

        sqlite3_bind_double(statement, 1, cutoff.timeIntervalSince1970)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw sqliteError(context: "purge old events")
        }
    }

    public func clear() async throws {
        try ensureReady()
        try execute("DELETE FROM deployment_events")
    }

    private func ensureReady() throws {
        if isReady {
            return
        }

        try openDatabaseIfNeeded()
        try migrateIfNeeded()
        isReady = true
    }

    private func openDatabaseIfNeeded() throws {
        if db != nil {
            return
        }

        let status = sqlite3_open_v2(
            dbURL.path,
            &db,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )

        guard status == SQLITE_OK else {
            throw DeployBarError.persistence("Failed to open SQLite database: \(sqliteErrorMessage())")
        }
    }

    private func migrateIfNeeded() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS deployment_events (
            id TEXT PRIMARY KEY NOT NULL,
            deployment_id TEXT NOT NULL,
            created_at REAL NOT NULL,
            level TEXT NOT NULL,
            message TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_deployment_events_lookup
        ON deployment_events (deployment_id, created_at DESC);
        """

        try execute(sql)
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw sqliteError(context: "execute SQL")
        }
    }

    private func sqliteError(context: String) -> DeployBarError {
        DeployBarError.persistence("SQLite failure during \(context): \(sqliteErrorMessage())")
    }

    private func sqliteErrorMessage() -> String {
        if let db, let ptr = sqlite3_errmsg(db) {
            return String(cString: ptr)
        }
        return "Unknown SQLite error"
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
