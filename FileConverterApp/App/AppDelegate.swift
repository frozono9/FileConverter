//
//  AppDelegate.swift
//  FileConverter
//

import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "arrow.2.squarepath",
                                            accessibilityDescription: "File Converter")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Check Dependencies", action: #selector(checkDeps), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu

        // Register as a Login Item
        do {
            try SMAppService.mainApp.register()
        } catch {
            print("Failed to register login item: \(error)")
        }
    }

    @objc func openPreferences() {
        // Implementation for opening Preferences view
    }
    
    @objc func checkDeps() {
        let results = DependencyChecker.shared.checkAll()
        print("Dependency results: \(results)")
    }
}
