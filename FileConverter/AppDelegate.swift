import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var preferencesWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "File Converter")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Tutorial", action: #selector(openTutorial), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
    }

    @objc private func openPreferences() {
        showWindow(tabIndex: 0)
    }

    @objc private func openTutorial() {
        showWindow(tabIndex: 1)
    }

    private func showWindow(tabIndex: Int) {
        if preferencesWindowController == nil {
            let view = PreferencesView()
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Preferences"
            window.setContentSize(NSSize(width: 450, height: 350))
            window.styleMask = NSWindow.StyleMask([.titled, .closable, .miniaturizable])
            preferencesWindowController = NSWindowController(window: window)
        }

        NSApp.activate(ignoringOtherApps: true)
        preferencesWindowController?.showWindow(nil)
    }

    @objc private func checkDependencies() {
        let checker = DependencyChecker.shared
        let results = checker.checkAll()

        let lines = results.keys.sorted().map { tool in
            let ok = results[tool] == true ? "OK" : "Missing"
            let hint = checker.installHint(for: tool)
            return "\(tool): \(ok)\(ok == "Missing" ? " (\(hint))" : "")"
        }

        showAlert(title: "Dependency Check", message: lines.joined(separator: "\n"))
    }

    @objc private func convertFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let inputURL = panel.url else {
            return
        }

        let formats = FileType.outputFormats(for: inputURL.pathExtension)
        guard !formats.isEmpty else {
            showAlert(title: "Unsupported Format", message: "No conversions are available for .\(inputURL.pathExtension.lowercased()) files.")
            return
        }

        let accessory = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 28))
        accessory.addItems(withTitles: formats.map { $0.uppercased() })

        let alert = NSAlert()
        alert.messageText = "Convert \(inputURL.lastPathComponent)"
        alert.informativeText = "Choose an output format:"
        alert.accessoryView = accessory
        alert.addButton(withTitle: "Convert")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let selectedFormat = formats[accessory.indexOfSelectedItem]

        Task {
            do {
                let outputURL = try await ConversionRouter.shared.convert(inputURL: inputURL, toFormat: selectedFormat)
                await MainActor.run {
                    self.showAlert(title: "Conversion Complete", message: "Saved: \(outputURL.path)")
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "Conversion Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}
