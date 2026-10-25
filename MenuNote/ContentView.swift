//
//  ContentView.swift
//  MenuNote
//
//  Created by Simon Fredsted on 25/10/2026.
//

import SwiftUI

struct ContentView: View {
    @Bindable var store: NoteStore
    var settings: AppSettings

    var body: some View {
        TextEditor(text: $store.text)
            .font(Font(settings.font as CTFont))
            .scrollContentBackground(.hidden)
            .frame(minWidth: 200, minHeight: 120)
            .background(Self.editorBackground.ignoresSafeArea())
    }

    /// Pure white in Light Mode; the standard text background in Dark Mode.
    private static let editorBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .textBackgroundColor : .white
    })
}

#Preview {
    let settings = AppSettings()
    ContentView(store: NoteStore(settings: settings), settings: settings)
}
