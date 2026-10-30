//
//  IRIS_IApp.swift
//  IRIS-I
//
//  Main application entrypoint.
//

import SwiftUI
#if canImport(AppIntents)
import AppIntents
#endif

@main
struct IRIS_IApp: App {
    init() {
        #if canImport(AppIntents)
        if #available(iOS 16.0, *) {
            IRISAppShortcutsProvider.updateAppShortcutParameters()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
