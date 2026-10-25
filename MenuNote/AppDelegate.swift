//
//  AppDelegate.swift
//  MenuNote
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store = NoteStore()
    private var statusItem: NSStatusItem!
    private var panel: NotePanel!
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
        contextMenu.addItem(.separator())
        contextMenu.addItem(withTitle: "Quit MenuNote", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        panel = NotePanel(contentViewController: NSHostingController(rootView: ContentView(store: store)))
        panel.delegate = self
        panel.onEscape = { [weak self] in self?.closeNote() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.save()
    }

    func applicationDidResignActive(_ notification: Notification) {
        store.save()
    }

    func windowWillClose(_ notification: Notification) {
        store.save()
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

    private func showNote() {
        if let buttonFrame = statusItem.button?.window?.frame {
            let size = panel.frame.size
            var origin = NSPoint(x: buttonFrame.midX - size.width / 2, y: buttonFrame.minY - size.height - 4)
            if let screen = statusItem.button?.window?.screen?.visibleFrame {
                origin.x = min(max(origin.x, screen.minX + 8), screen.maxX - size.width - 8)
            }
            panel.setFrameOrigin(origin)
        }
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    private func closeNote() {
        store.save()
        panel.orderOut(nil)
    }

    @objc private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}

/// Floating, resizable panel that reports the Escape key.
final class NotePanel: NSPanel {
    var onEscape: (() -> Void)?

    init(contentViewController: NSViewController) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        self.contentViewController = contentViewController
        title = "MenuNote"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        minSize = NSSize(width: 200, height: 120)
        setContentSize(NSSize(width: 320, height: 240))
        setFrameAutosaveName("NotePanel")
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
