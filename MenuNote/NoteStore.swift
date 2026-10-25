//
//  NoteStore.swift
//  MenuNote
//

import Foundation
import Observation

/// Loads and saves the note as a plain text file in Application Support.
@Observable
final class NoteStore {
    var text: String

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var savedText: String

    init() {
        let directory = URL.applicationSupportDirectory.appending(path: "MenuNote", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appending(path: "Note.txt")

        let loaded = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        text = loaded
        savedText = loaded
    }

    func save() {
        guard text != savedText else { return }
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            savedText = text
        } catch {
            NSLog("MenuNote: failed to save note: \(error)")
        }
    }
}
