//
//  PersonalMemoryStore.swift
//  IRIS-I
//
//  Authoritative persistent memory engine backed by local SQLite.
//  Preserves conversation history, tool execution records, personal notes,
//  user preferences, and injects context into the ReAct LLM prompt.
//

import Foundation
import SQLite3

public struct InteractionMemoryItem: Identifiable, Sendable {
    public let id: String
    public let conversationId: String
    public let userRequest: String
    public let assistantResponse: String
    public let toolName: String?
    public let executionState: String
    public let toolOutcome: String
    public let isVerified: Bool
    public let durationMs: Double
    public let createdAt: Date

    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

public struct PersonalNoteItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let content: String
    public let category: String
    public let importance: Int
    public let createdAt: Date
    public let updatedAt: Date

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: updatedAt)
    }
}

public struct PreferenceItem: Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let value: String
    public let category: String
    public let updatedAt: Date
}

public final class PersonalMemoryStore: @unchecked Sendable {
    public static let shared = PersonalMemoryStore()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.iris.memory.store", qos: .userInitiated)
    private let dbPath: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let memoryDir = appSupport.appendingPathComponent("IRIS-I/Memory", isDirectory: true)
        try? FileManager.default.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        self.dbPath = memoryDir.appendingPathComponent("iris_memory.sqlite3")

        openAndInitDatabase()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    private func openAndInitDatabase() {
        queue.sync {
            if sqlite3_open(dbPath.path, &db) != SQLITE_OK {
                print("[MEMORY_STORE] Failed to open SQLite database at \(dbPath.path)")
                return
            }

            // Create interaction records table
            let createInteractionsSQL = """
            CREATE TABLE IF NOT EXISTS conversation_records (
                id TEXT PRIMARY KEY,
                conversation_id TEXT,
                user_request TEXT,
                assistant_response TEXT,
                tool_name TEXT,
                execution_state TEXT,
                tool_outcome TEXT,
                is_verified INTEGER,
                duration_ms REAL,
                created_at REAL
            );
            """

            // Create personal notes table
            let createNotesSQL = """
            CREATE TABLE IF NOT EXISTS personal_notes (
                id TEXT PRIMARY KEY,
                title TEXT,
                content TEXT,
                category TEXT,
                importance INTEGER,
                created_at REAL,
                updated_at REAL
            );
            """

            // Create user preferences table
            let createPreferencesSQL = """
            CREATE TABLE IF NOT EXISTS user_preferences (
                key TEXT PRIMARY KEY,
                value TEXT,
                category TEXT,
                updated_at REAL
            );
            """

            execute(sql: createInteractionsSQL)
            execute(sql: createNotesSQL)
            execute(sql: createPreferencesSQL)

            seedInitialDefaultsIfNeeded()
        }
    }

    private func execute(sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let err = errMsg {
                let msg = String(cString: err)
                print("[MEMORY_STORE] SQL Error: \(msg)")
                sqlite3_free(errMsg)
            }
        }
    }

    private func seedInitialDefaultsIfNeeded() {
        if allNotesInternal().isEmpty {
            let initialNotes = [
                ("Default Music Player", "Prefers Apple Music over Spotify for Siri voice commands.", "Media", 2),
                ("Daily Standup Routine", "Set recurring reminder for team standup at 10:00 AM.", "Routines", 3),
                ("Location Context", "Primary work area: Cupertino / San Francisco Bay Area.", "Context", 2)
            ]
            for (title, content, category, imp) in initialNotes {
                _ = addNoteInternal(title: title, content: content, category: category, importance: imp)
            }
        }

        if allPreferencesInternal().isEmpty {
            let initialPrefs = [
                ("preferred_voice", "Samantha (Enhanced Local)", "Voice"),
                ("confirmation_required_calls", "true", "Security"),
                ("confirmation_required_messages", "true", "Security"),
                ("wake_word_phrase", "Hey IRIS", "Activation")
            ]
            for (k, v, c) in initialPrefs {
                setPreferenceInternal(key: k, value: v, category: c)
            }
        }
    }

    // MARK: - Conversation Memory Operations

    public func saveInteraction(
        request: String,
        response: String,
        executionRecord: ExecutionRecord? = nil,
        conversationId: String = "default"
    ) {
        queue.async {
            let id = UUID().uuidString
            let now = Date().timeIntervalSince1970
            let toolName = executionRecord?.selectedTool ?? ""
            let execState = executionRecord?.executionState.rawValue ?? "completedVerified"
            let outcome = executionRecord?.toolOutcome.rawValue ?? "completedVerified"
            let verified = (executionRecord?.isVerified ?? false) ? 1 : 0
            let duration = executionRecord?.durationMs ?? 0.0

            let sql = """
            INSERT INTO conversation_records (id, conversation_id, user_request, assistant_response, tool_name, execution_state, tool_outcome, is_verified, duration_ms, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (conversationId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (request as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (response as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 5, (toolName as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 6, (execState as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 7, (outcome as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 8, Int32(verified))
                sqlite3_bind_double(stmt, 9, duration)
                sqlite3_bind_double(stmt, 10, now)

                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("[MEMORY_STORE] Failed to insert conversation record")
                }
            }
            sqlite3_finalize(stmt)
        }
    }

    public func recentInteractions(limit: Int = 20) -> [InteractionMemoryItem] {
        queue.sync {
            var items: [InteractionMemoryItem] = []
            let sql = "SELECT id, conversation_id, user_request, assistant_response, tool_name, execution_state, tool_outcome, is_verified, duration_ms, created_at FROM conversation_records ORDER BY created_at DESC LIMIT ?;"

            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(limit))

                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = String(cString: sqlite3_column_text(stmt, 0))
                    let convId = String(cString: sqlite3_column_text(stmt, 1))
                    let req = String(cString: sqlite3_column_text(stmt, 2))
                    let res = String(cString: sqlite3_column_text(stmt, 3))
                    let tool = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                    let execState = String(cString: sqlite3_column_text(stmt, 5))
                    let outcome = String(cString: sqlite3_column_text(stmt, 6))
                    let isVer = sqlite3_column_int(stmt, 7) == 1
                    let dur = sqlite3_column_double(stmt, 8)
                    let created = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 9))

                    items.append(InteractionMemoryItem(
                        id: id,
                        conversationId: convId,
                        userRequest: req,
                        assistantResponse: res,
                        toolName: tool?.isEmpty == true ? nil : tool,
                        executionState: execState,
                        toolOutcome: outcome,
                        isVerified: isVer,
                        durationMs: dur,
                        createdAt: created
                    ))
                }
            }
            sqlite3_finalize(stmt)
            return items
        }
    }

    public func deleteInteraction(id: String) {
        queue.sync {
            let sql = "DELETE FROM conversation_records WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    // MARK: - Personal Notes Operations

    public func addNote(title: String, content: String, category: String = "General", importance: Int = 1) -> String {
        queue.sync {
            addNoteInternal(title: title, content: content, category: category, importance: importance)
        }
    }

    private func addNoteInternal(title: String, content: String, category: String, importance: Int) -> String {
        let id = UUID().uuidString
        let now = Date().timeIntervalSince1970
        let sql = "INSERT INTO personal_notes (id, title, content, category, importance, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?);"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (title as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (content as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (category as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 5, Int32(importance))
            sqlite3_bind_double(stmt, 6, now)
            sqlite3_bind_double(stmt, 7, now)

            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        return id
    }

    public func allNotes() -> [PersonalNoteItem] {
        queue.sync {
            allNotesInternal()
        }
    }

    private func allNotesInternal() -> [PersonalNoteItem] {
        var items: [PersonalNoteItem] = []
        let sql = "SELECT id, title, content, category, importance, created_at, updated_at FROM personal_notes ORDER BY importance DESC, updated_at DESC;"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let title = String(cString: sqlite3_column_text(stmt, 1))
                let content = String(cString: sqlite3_column_text(stmt, 2))
                let cat = String(cString: sqlite3_column_text(stmt, 3))
                let imp = Int(sqlite3_column_int(stmt, 4))
                let created = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
                let updated = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))

                items.append(PersonalNoteItem(
                    id: id,
                    title: title,
                    content: content,
                    category: cat,
                    importance: imp,
                    createdAt: created,
                    updatedAt: updated
                ))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    public func deleteNote(id: String) {
        queue.sync {
            let sql = "DELETE FROM personal_notes WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    // MARK: - Preferences Operations

    public func setPreference(key: String, value: String, category: String = "General") {
        queue.sync {
            setPreferenceInternal(key: key, value: value, category: category)
        }
    }

    private func setPreferenceInternal(key: String, value: String, category: String) {
        let now = Date().timeIntervalSince1970
        let sql = "INSERT OR REPLACE INTO user_preferences (key, value, category, updated_at) VALUES (?, ?, ?, ?);"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (value as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (category as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 4, now)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    public func allPreferences() -> [PreferenceItem] {
        queue.sync {
            allPreferencesInternal()
        }
    }

    private func allPreferencesInternal() -> [PreferenceItem] {
        var items: [PreferenceItem] = []
        let sql = "SELECT key, value, category, updated_at FROM user_preferences ORDER BY category, key;"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let k = String(cString: sqlite3_column_text(stmt, 0))
                let v = String(cString: sqlite3_column_text(stmt, 1))
                let c = String(cString: sqlite3_column_text(stmt, 2))
                let updated = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))

                items.append(PreferenceItem(key: k, value: v, category: c, updatedAt: updated))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    public func deletePreference(key: String) {
        queue.sync {
            let sql = "DELETE FROM user_preferences WHERE key = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    // MARK: - Prompt Context Injection

    /// Generates contextual memory markdown for injection into the ReAct LLM system prompt
    public func contextForPrompt(_ prompt: String) -> String {
        let notes = allNotes()
        let prefs = allPreferences()

        guard !notes.isEmpty || !prefs.isEmpty else { return "" }

        var lines: [String] = []
        lines.append("\n[PERSISTENT USER MEMORY & PREFERENCES]")

        if !prefs.isEmpty {
            lines.append("User Preferences:")
            for p in prefs.prefix(5) {
                lines.append("- \(p.key): \(p.value)")
            }
        }

        if !notes.isEmpty {
            lines.append("Important Personal Notes:")
            for n in notes.prefix(5) {
                lines.append("- \(n.title): \(n.content)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

