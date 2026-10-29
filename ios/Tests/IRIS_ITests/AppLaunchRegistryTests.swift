//
//  AppLaunchRegistryTests.swift
//  IRIS_ITests
//
//  Verifies rejection of private schemes (App-Prefs:) and verified scheme lookup.
//

import XCTest
#if canImport(IRIS_ICore)
@testable import IRIS_ICore
#elseif canImport(IRIS_I)
@testable import IRIS_I
#endif

final class AppLaunchRegistryTests: XCTestCase {

    let registry = AppLaunchRegistry.shared

    func testLookupDefaultRegisteredApps() async {
        let maps = await registry.descriptor(for: "maps")
        XCTAssertNotNil(maps)
        XCTAssertEqual(maps?.urlScheme, "maps:")

        let spotify = await registry.descriptor(for: "spotify")
        XCTAssertNotNil(spotify)
        XCTAssertEqual(spotify?.urlScheme, "spotify:")
    }

    func testUnregisteredAppThrows() async {
        do {
            _ = try await registry.launchApp(name: "NonExistentApp12345")
            XCTFail("Should throw error for non-existent app")
        } catch let err as AppLaunchError {
            switch err {
            case .appNotInstalled, .unregisteredScheme:
                break // Expected
            default:
                XCTFail("Expected appNotInstalled or unregisteredScheme error, got \(err)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testPrivateAppPrefsSchemeRejected() async {
        do {
            _ = try await registry.launchApp(name: "App-Prefs:root=General")
            XCTFail("Private App-Prefs scheme must be rejected")
        } catch let err as AppLaunchError {
            switch err {
            case .unregisteredScheme:
                break // Expected
            default:
                XCTFail("Expected unregisteredScheme error, got \(err)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

