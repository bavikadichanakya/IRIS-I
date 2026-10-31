//
//  PersonalMemoryStoreTests.swift
//  IRIS_ITests
//
//  Verifies SQLite persistent storage, CRUD operations on notes and preferences,
//  interaction logging, and prompt context markdown generation.
//

import XCTest
@testable import IRIS_I

final class PersonalMemoryStoreTests: XCTestCase {

    func testNotesCRUD() {
        let store = PersonalMemoryStore.shared
        let title = "Test Unit Note"
        let content = "Testing persistent memory SQLite storage"

        let noteId = store.addNote(title: title, content: content, category: "Test", importance: 3)
        XCTAssertFalse(noteId.isEmpty)

        let allNotes = store.allNotes()
        XCTAssertTrue(allNotes.contains { $0.id == noteId && $0.title == title })

        store.deleteNote(id: noteId)
        let afterDelete = store.allNotes()
        XCTAssertFalse(afterDelete.contains { $0.id == noteId })
    }

    func testPreferencesPersistence() {
        let store = PersonalMemoryStore.shared
        let key = "test_custom_key"
        let val = "test_value_42"

        store.setPreference(key: key, value: val, category: "UnitTesting")
        let prefs = store.allPreferences()
        XCTAssertTrue(prefs.contains { $0.key == key && $0.value == val })

        store.deletePreference(key: key)
        let afterDelete = store.allPreferences()
        XCTAssertFalse(afterDelete.contains { $0.key == key })
    }

    func testPromptContextInjection() {
        let store = PersonalMemoryStore.shared
        let context = store.contextForPrompt("Hello assistant")
        XCTAssertFalse(context.isEmpty)
        XCTAssertTrue(context.contains("[PERSISTENT USER MEMORY & PREFERENCES]"))
    }

    func testInteractionSaving() {
        let store = PersonalMemoryStore.shared
        let record = ExecutionRecord(
            userRequest: "What is my battery level?",
            interpretedIntent: "Query battery",
            selectedTool: "SystemInfoTool",
            executionState: .completedVerified,
            toolOutcome: .completedVerified,
            isVerified: true
        )

        store.saveInteraction(request: "What is my battery level?", response: "Battery is at 80%", executionRecord: record)

        // Give SQLite async write a short moment
        let exp = expectation(description: "Wait for SQLite write")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let recent = store.recentInteractions(limit: 5)
            XCTAssertTrue(recent.contains { $0.userRequest == "What is my battery level?" })
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    func testFreshDatabaseStartsEmpty() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("iris_fresh_test_\(UUID().uuidString).sqlite3")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let freshStore = PersonalMemoryStore(customPath: tempURL)
        XCTAssertTrue(freshStore.allNotes().isEmpty, "Fresh database must start with zero notes.")
        XCTAssertTrue(freshStore.allPreferences().isEmpty, "Fresh database must start with zero preferences.")
        XCTAssertTrue(freshStore.recentInteractions(limit: 10).isEmpty, "Fresh database must start with zero conversation records.")
    }
}

