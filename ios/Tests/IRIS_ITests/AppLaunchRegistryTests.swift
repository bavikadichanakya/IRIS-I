//
//  AppLaunchRegistryTests.swift
//  IRIS_ITests
//
//  Verifies rejection of private schemes (App-Prefs:), verified scheme lookup,
//  and strict error handling for unsupported apps without fake scheme guessing.
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

        let youtube = await registry.descriptor(for: "youtube")
        XCTAssertNotNil(youtube)
        XCTAssertEqual(youtube?.urlScheme, "youtube:")

        let instagram = await registry.descriptor(for: "instagram")
        XCTAssertNotNil(instagram)
        XCTAssertEqual(instagram?.urlScheme, "instagram:")

        let safari = await registry.descriptor(for: "safari")
        XCTAssertNotNil(safari)
        let browser = await registry.descriptor(for: "browser")
        XCTAssertNotNil(browser)

        let calc = await registry.descriptor(for: "calc")
        XCTAssertNotNil(calc)
        XCTAssertEqual(calc?.appName, "Calculator")

        let clock = await registry.descriptor(for: "clock")
        XCTAssertNotNil(clock)
        XCTAssertEqual(clock?.appName, "Clock")
    }

    func testUnregisteredAppThrowsUnsupportedWithoutSynthesizingScheme() async {
        do {
            _ = try await registry.launchApp(name: "TotallyUnknownApp12345")
            XCTFail("Should throw error for non-existent app")
        } catch let err as AppLaunchError {
            switch err {
            case .unsupportedApp(let name):
                XCTAssertEqual(name, "TotallyUnknownApp12345")
            case .appNotInstalled, .unregisteredScheme:
                break // Also acceptable error modes
            default:
                XCTFail("Expected unsupportedApp, appNotInstalled or unregisteredScheme, got \(err)")
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
            case .unregisteredScheme, .unsupportedApp:
                break // Expected
            default:
                XCTFail("Expected unregisteredScheme or unsupportedApp error, got \(err)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
