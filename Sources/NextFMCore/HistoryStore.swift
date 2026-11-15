import Foundation
import CSQLite

/// A connection stays inside this actor. Page data and its checkpoint commit together.
public actor HistoryStore {
    private var database: OpaquePointer?
    public init(url: URL) throws {
        var connection: OpaquePointer?
        guard sqlite3_open(url.path, &connection) == SQLITE_OK else {
            if let connection { sqlite3_close(connection) }
            throw StoreError.operation("Could not open the listening history database.")
        }
        database = connection
        let schema = """
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS scrobbles (
          user TEXT NOT NULL, id TEXT NOT NULL, timestamp INTEGER NOT NULL,
          payload BLOB NOT NULL, PRIMARY KEY(user, id));
        CREATE INDEX IF NOT EXISTS history_date ON scrobbles(user, timestamp DESC);
        CREATE TABLE IF NOT EXISTS checkpoints (user TEXT PRIMARY KEY, payload BLOB NOT NULL);
        """
        guard sqlite3_exec(connection, schema, nil, nil, nil) == SQLITE_OK else {
            sqlite3_close(connection)
            throw StoreError.operation("Could not prepare the listening history database.")
        }
    }
    // The app owns one store for its lifetime. Explicit close also supports test teardown.
    public func close() { sqlite3_close(database); database = nil }

    public func load(user: String) throws -> [Scrobble] {
        let statement = try prepare("SELECT payload FROM scrobbles WHERE user = ? ORDER BY timestamp DESC, id")
        defer { sqlite3_finalize(statement) }
        bind(user.lowercased(), to: statement, at: 1)
        var result: [Scrobble] = []
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            result.append(try JSONDecoder().decode(Scrobble.self, from: blob(statement)))
            status = sqlite3_step(statement)
        }
        guard status == SQLITE_DONE else { throw failure() }
        return result
    }

    public func checkpoint(user: String) throws -> SyncCheckpoint? {
        let statement = try prepare("SELECT payload FROM checkpoints WHERE user = ?")
        defer { sqlite3_finalize(statement) }
        bind(user.lowercased(), to: statement, at: 1)
        let status = sqlite3_step(statement)
        if status == SQLITE_DONE { return nil }
        guard status == SQLITE_ROW else { throw failure() }
        return try JSONDecoder().decode(SyncCheckpoint.self, from: blob(statement))
    }

    public func save(_ items: [Scrobble], user: String, checkpoint: SyncCheckpoint) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            let statement = try prepare("INSERT OR REPLACE INTO scrobbles(user,id,timestamp,payload) VALUES(?,?,?,?)")
            defer { sqlite3_finalize(statement) }
            let encoder = JSONEncoder()
            for item in items {
                sqlite3_reset(statement); sqlite3_clear_bindings(statement)
                bind(user.lowercased(), to: statement, at: 1)
                bind(item.id, to: statement, at: 2)
                sqlite3_bind_int64(statement, 3, Int64(item.timestamp))
                bind(try encoder.encode(item), to: statement, at: 4)
                guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
            }
            let state = try prepare("INSERT OR REPLACE INTO checkpoints(user,payload) VALUES(?,?)")
            defer { sqlite3_finalize(state) }
            bind(user.lowercased(), to: state, at: 1)
            bind(try encoder.encode(checkpoint), to: state, at: 2)
            guard sqlite3_step(state) == SQLITE_DONE else { throw failure() }
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }

    public func clear(user: String) throws {
        for table in ["scrobbles", "checkpoints"] {
            let statement = try prepare("DELETE FROM \(table) WHERE user = ?")
            defer { sqlite3_finalize(statement) }
            bind(user.lowercased(), to: statement, at: 1)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        return statement
    }
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
    }
    private func bind(_ value: String, to statement: OpaquePointer, at index: Int32) {
        _ = value.withCString { sqlite3_bind_text(statement, index, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
    }
    private func bind(_ data: Data, to statement: OpaquePointer, at index: Int32) {
        _ = data.withUnsafeBytes { sqlite3_bind_blob(statement, index, $0.baseAddress, Int32(data.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
    }
    private func blob(_ statement: OpaquePointer) -> Data {
        Data(bytes: sqlite3_column_blob(statement, 0)!, count: Int(sqlite3_column_bytes(statement, 0)))
    }
    private func failure() -> StoreError {
        .operation(database.map { String(cString: sqlite3_errmsg($0)) } ?? "History database is closed.")
    }
}

public enum StoreError: LocalizedError {
    case operation(String)
    public var errorDescription: String? { switch self { case .operation(let message): message } }
}
