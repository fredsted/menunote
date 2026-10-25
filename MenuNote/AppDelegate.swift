//
//  AppDelegate.swift
//  MenuNote
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let settings = AppSettings()
    private lazy var store = NoteStore(settings: settings)
    private let hotKey = GlobalHotKey()
    private var statusItem: NSStatusItem!
    private var panel: NotePanel!
    private var settingsWindow: NSWindow?
    private let contextMenu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "MenuNote")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        contextMenu.addItem(withTitle: "About MenuNote", action: #selector(showAbout), keyEquivalent: "").target = self
        contextMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        contextMenu.addItem(.separator())
        contextMenu.addItem(withTitle: "Quit MenuNote", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        panel = NotePanel(contentViewController: NSHostingController(rootView: ContentView(store: store, settings: settings)))
        panel.delegate = self
        panel.onEscape = { [weak self] in self?.closeNote() }
        addMenuButton(to: panel)

        hotKey.onPress = { [weak self] in self?.toggleNoteFromHotKey() }
        observeHotKey()
    }

    /// Puts a ••• button on the right of the title bar that opens the app menu.
    private func addMenuButton(to window: NSWindow) {
        let button = NSButton(
            image: NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "Menu")!,
            target: self,
            action: #selector(menuButtonClicked(_:))
        )
        button.isBordered = false
        button.contentTintColor = .secondaryLabelColor
        button.symbolConfiguration = .init(pointSize: 12, weight: .semibold)
        button.frame = NSRect(x: 0, y: 0, width: 30, height: 20)

        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = button
        accessory.layoutAttribute = .trailing
        window.addTitlebarAccessoryViewController(accessory)
    }

    @objc private func menuButtonClicked(_ sender: NSButton) {
        let below = NSPoint(x: 0, y: sender.isFlipped ? sender.bounds.maxY + 4 : -4)
        contextMenu.popUp(positioning: nil, at: below, in: sender)
    }

    /// Keeps the registered global hotkey in sync with settings.
    private func observeHotKey() {
        withObservationTracking {
            hotKey.register(settings.isRecordingHotKey ? nil : settings.hotKey)
        } onChange: {
            Task { @MainActor in self.observeHotKey() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.save()
    }

    func applicationDidResignActive(_ notification: Notification) {
        store.save()
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === panel {
            store.save()
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            // Attach the menu only for this click so left clicks still reach us.
            statusItem.menu = contextMenu
            sender.performClick(nil)
            statusItem.menu = nil
        } else if panel.isVisible {
            closeNote()
        } else {
            showNote()
        }
    }

    /// Hides the note if it's open and focused; otherwise shows and focuses it,
    /// so a note sitting behind another app's window is brought forward rather than hidden.
    private func toggleNoteFromHotKey() {
        if panel.isVisible && panel.isKeyWindow && NSApp.isActive {
            closeNote()
        } else {
            showNote()
        }
    }

    private func showNote() {
        if !panel.isVisible {
            store.reloadIfUnchanged()
            positionPanel()
        }
        NSApp.unhide(nil)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    private func positionPanel() {
        if let buttonFrame = statusItem.button?.window?.frame {
            let size = panel.frame.size
            var origin = NSPoint(x: buttonFrame.midX - size.width / 2, y: buttonFrame.minY - size.height - 4)
            if let screen = statusItem.button?.window?.screen?.visibleFrame {
                origin.x = min(max(origin.x, screen.minX + 8), screen.maxX - size.width - 8)
            }
            panel.setFrameOrigin(origin)
        }
    }

    private func closeNote() {
        store.save()
        panel.orderOut(nil)
        // Hand focus back to the previous app, unless Settings is still open.
        if settingsWindow?.isVisible != true {
            NSApp.hide(nil)
        }
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings, store: store)))
            window.title = "MenuNote Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            // Match the floating note panel so Settings can appear above it.
            window.level = panel.level
            window.center()
            settingsWindow = window
        }
        NSApp.unhide(nil)
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func showAbout() {
        NSApp.unhide(nil)
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
        // AppKit doesn't expose the About panel, so find it: the only other titled, visible window.
        // (The status item's window is untitled.) Lift it to the note panel's level so it shows above.
        for window in NSApp.windows where window.isVisible && window.styleMask.contains(.titled)
            && window !== panel && window !== settingsWindow {
            window.level = panel.level
            window.orderFront(nil)
        }
    }
}

/// Floating, resizable panel that reports the Escape key.
final class NotePanel: NSPanel {
    static let defaultSize = NSSize(width: 555, height: 306)

    var onEscape: (() -> Void)?

    init(contentViewController: NSViewController) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        self.contentViewController = contentViewController
        title = "MenuNote"
        titleVisibility = .visible
        titlebarAppearsTransparent = true
        standardWindowButton(.zoomButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        minSize = NSSize(width: 200, height: 120)
        setFrame(NSRect(origin: .zero, size: Self.defaultSize), display: false)
        setFrameAutosaveName("NotePanel") // Restores the user's size, if saved.
    }

    override var canBecomeKey: Bool { true }

    // Intercept Escape before the text view turns it into autocomplete.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown && event.keyCode == 53 {
            onEscape?()
            return
        }
        super.sendEvent(event)
    }
}
