//
//  AppSettings.swift
//  MenuNote
//

import AppKit
import Observation

/// User preferences, persisted in UserDefaults.
@Observable
final class AppSettings {
    /// Inside the app's sandbox container, so it works without any file access grants.
    static let defaultNoteURL = URL.documentsDirectory.appending(path: "MenuNote.txt")
    static let defaultFontFamily = "Helvetica Neue"
    static let defaultFontSize = 13.0
    static let defaultHotKey = HotKey(keyCode: 45, modifiers: [.control, .option, .command], keyName: "N")

    private enum Keys {
        static let noteBookmark = "noteBookmark"
        static let fontFamily = "fontFamily"
        static let fontSize = "fontSize"
        static let hotKey = "hotKey"
    }

    @ObservationIgnored private let defaults = UserDefaults.standard

    /// The note file. Anything other than the default is a user-chosen file kept
    /// accessible across launches with a security-scoped bookmark.
    private(set) var noteURL = AppSettings.defaultNoteURL

    @ObservationIgnored private var accessedURL: URL?

    var fontFamily: String {
        didSet { defaults.set(fontFamily, forKey: Keys.fontFamily) }
    }

    var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Keys.fontSize) }
    }

    /// `nil` means the user has cleared the shortcut.
    var hotKey: HotKey? {
        didSet { defaults.set(try? JSONEncoder().encode(hotKey), forKey: Keys.hotKey) }
    }

    /// True while the shortcut recorder is listening, so the global hotkey doesn't fire.
    var isRecordingHotKey = false

    init() {
        fontFamily = defaults.string(forKey: Keys.fontFamily) ?? Self.defaultFontFamily
        let size = defaults.double(forKey: Keys.fontSize)
        fontSize = size > 0 ? size : Self.defaultFontSize
        if let data = defaults.data(forKey: Keys.hotKey) {
            hotKey = try? JSONDecoder().decode(HotKey?.self, from: data)
        } else {
            hotKey = Self.defaultHotKey
        }
        if let bookmark = defaults.data(forKey: Keys.noteBookmark) {
            restoreNoteBookmark(bookmark)
        }
    }

    var isDefaultNoteLocation: Bool { noteURL == Self.defaultNoteURL }

    /// Switches to a user-chosen file (which must exist), or back to the default with `nil`.
    func setNoteURL(_ url: URL?) throws {
        if let url {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(bookmark, forKey: Keys.noteBookmark)
        } else {
            defaults.removeObject(forKey: Keys.noteBookmark)
        }
        accessNoteURL(url)
    }

    private func restoreNoteBookmark(_ bookmark: Data) {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &isStale) else {
            NSLog("MenuNote: couldn't resolve note bookmark, using default location")
            return
        }
        accessNoteURL(url)
        if isStale, let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            defaults.set(fresh, forKey: Keys.noteBookmark)
        }
    }

    private func accessNoteURL(_ url: URL?) {
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
        if let url, url.startAccessingSecurityScopedResource() {
            accessedURL = url
        }
        noteURL = url ?? Self.defaultNoteURL
    }

    var font: NSFont {
        NSFontManager.shared.font(withFamily: fontFamily, traits: [], weight: 5, size: fontSize)
            ?? .systemFont(ofSize: fontSize)
    }
}
