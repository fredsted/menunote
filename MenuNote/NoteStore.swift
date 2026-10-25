//
//  NoteStore.swift
//  MenuNote
//

import Foundation
import Observation

/// Loads and saves the note as a plain text file at the path from settings.
@Observable
final class NoteStore {
    var text = ""
    private(set) var errorMessage: String?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var savedText = ""

    init(settings: AppSettings) {
        self.settings = settings
        load()
    }

    /// Saves the current note, then opens an existing file instead.
    func openFile(_ url: URL) {
        save()
        do {
            try settings.setNoteURL(url)
            load()
        } catch {
            report(error, "open")
        }
    }

    /// Writes the current note to `url` and keeps using that file from now on.
    func moveFile(to url: URL) {
        do {
            try text.write(to: url, atomically: false, encoding: .utf8)
            try settings.setNoteURL(url)
            savedText = text
            errorMessage = nil
        } catch {
            report(error, "move")
        }
    }

    /// Goes back to the default file, carrying the current note over if that file doesn't exist yet.
    func resetToDefaultFile() {
        save()
        do {
            try settings.setNoteURL(nil)
            load(creatingWith: text)
        } catch {
            report(error, "reset")
        }
    }

    /// Picks up external edits, unless there are unsaved changes.
    func reloadIfUnchanged() {
        if text == savedText {
            load()
        }
    }

    func save() {
        guard text != savedText else { return }
        do {
            // Non-atomic: the sandbox only grants access to the file itself, not a temp file beside it.
            try text.write(to: settings.noteURL, atomically: false, encoding: .utf8)
            savedText = text
            errorMessage = nil
        } catch {
            report(error, "save")
        }
    }

    private func load(creatingWith initialText: String = "") {
        let url = settings.noteURL
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                text = try String(contentsOf: url, encoding: .utf8)
            } else {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try initialText.write(to: url, atomically: false, encoding: .utf8)
                text = initialText
            }
            savedText = text
            errorMessage = nil
        } catch {
            report(error, "load")
        }
    }

    private func report(_ error: Error, _ action: String) {
        errorMessage = error.localizedDescription
        NSLog("MenuNote: failed to \(action) note: \(error)")
    }
}
