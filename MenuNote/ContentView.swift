//
//  ContentView.swift
//  MenuNote
//
//  Created by Simon Fredsted on 25/10/2026.
//

import SwiftUI

struct ContentView: View {
    @Bindable var store: NoteStore

    var body: some View {
        TextEditor(text: $store.text)
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(minWidth: 200, minHeight: 120)
    }
}

#Preview {
    ContentView(store: NoteStore())
}
