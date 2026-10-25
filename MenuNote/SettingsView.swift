//
//  SettingsView.swift
//  MenuNote
//

import AppKit
import Carbon.HIToolbox
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settings: AppSettings
    var store: NoteStore

    private let fontFamilies = NSFontManager.shared.availableFontFamilies

    var body: some View {
        Form {
            Section("Note File") {
                Text(displayPath(settings.noteURL))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(settings.noteURL.path)
                HStack {
                    Button("Open Existing…", action: openExisting)
                    Button("Move To…", action: moveTo)
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([settings.noteURL])
                    }
                    Spacer()
                    Button("Reset", action: store.resetToDefaultFile)
                        .disabled(settings.isDefaultNoteLocation)
                        .help("Use the default file inside the app's container")
                }
                if let error = store.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            Section("Shortcut") {
                LabeledContent("Open note") {
                    HotKeyRecorder(hotKey: $settings.hotKey, isRecording: $settings.isRecordingHotKey)
                }
            }

            Section("Font") {
                Picker("Family", selection: $settings.fontFamily) {
                    ForEach(fontFamilies, id: \.self) { family in
                        Text(family).font(.custom(family, size: 13)).tag(family)
                    }
                }
                LabeledContent("Size") {
                    HStack {
                        TextField("Size", value: $settings.fontSize, format: .number)
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                        Stepper("Size", value: $settings.fontSize, in: 6...72)
                            .labelsHidden()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func openExisting() {
        let panel = NSOpenPanel()
        panel.message = "Choose a text file to use as your note."
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.openFile(url)
    }

    private func moveTo() {
        let panel = NSSavePanel()
        panel.message = "Choose where to keep your note."
        panel.nameFieldStringValue = settings.noteURL.lastPathComponent
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.moveFile(to: url)
    }

    /// Abbreviates the user's real home folder (NSHomeDirectory() is the container in the sandbox).
    private func displayPath(_ url: URL) -> String {
        guard let home = getpwuid(getuid())?.pointee.pw_dir.map({ String(cString: $0) }) else { return url.path }
        return url.path.hasPrefix(home + "/") ? "~" + url.path.dropFirst(home.count) : url.path
    }
}

/// A button that records the next key combination pressed while it's active.
struct HotKeyRecorder: View {
    @Binding var hotKey: HotKey?
    @Binding var isRecording: Bool

    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 4) {
            Button(isRecording ? "Type shortcut…" : (hotKey?.displayString ?? "None")) {
                isRecording ? stopRecording() : startRecording()
            }
            .frame(minWidth: 120)
            if hotKey != nil && !isRecording {
                Button {
                    hotKey = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("Clear shortcut")
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == kVK_Escape {
                stopRecording()
            } else if event.modifierFlags.intersection([.control, .option, .command]).isEmpty {
                // Require at least one of ⌃⌥⌘ so plain typing isn't hijacked system-wide.
                NSSound.beep()
            } else {
                hotKey = HotKey(event: event)
                stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }
}
