//
//  MenuNoteApp.swift
//  MenuNote
//
//  Created by Simon Fredsted on 25/10/2026.
//

import SwiftUI

@main
struct MenuNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The app lives in the menu bar; all UI is driven by AppDelegate.
        Settings {
            EmptyView()
        }
    }
}
