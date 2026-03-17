import SwiftUI
import AppKit

extension Notification.Name {
    static let fileConverterQuitRequested = Notification.Name("fileConverterQuitRequested")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let extensionEnabledKey = "fc.extensionEnabled"
    private let extensionSuiteName = "me.Latorre.Alex.FileConverter.FinderSync"
    private let sharedSuiteName = "group.me.Latorre.Alex.FileConverter"
    private var statusItem: NSStatusItem?
    private var preferencesWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        setExtensionEnabled(true)
        NotificationCenter.default.addObserver(self, selector: #selector(handleQuitRequestNotification), name: .fileConverterQuitRequested, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Convert to...")
        statusItem?.button?.action = #selector(handleStatusItemClick)
        statusItem?.button?.target = self
        statusItem?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleStatusItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }
        openPreferences()
    }

    private func showContextMenu() {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func quitApp() {
        setExtensionEnabled(false)
        NSApplication.shared.terminate(nil)
    }

    @objc private func handleQuitRequestNotification() {
        quitApp()
    }

    private func setExtensionEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: extensionEnabledKey)
        UserDefaults.standard.synchronize()

        let sharedDefaults = UserDefaults(suiteName: sharedSuiteName)
        sharedDefaults?.set(enabled, forKey: extensionEnabledKey)
        sharedDefaults?.synchronize()

        let extensionDefaults = UserDefaults(suiteName: extensionSuiteName)
        extensionDefaults?.set(enabled, forKey: extensionEnabledKey)
        extensionDefaults?.synchronize()

        setExtensionDomainValue(enabled, forKey: extensionEnabledKey)
    }

    private func setExtensionDomainValue(_ value: Bool, forKey key: String) {
        let appID = extensionSuiteName as CFString
        CFPreferencesSetAppValue(key as CFString, value as CFPropertyList, appID)
        CFPreferencesAppSynchronize(appID)
    }

    @objc private func openPreferences() {
        showWindow()
    }

    @objc private func openTutorial() {
        showWindow()
    }

    private func showWindow() {
        if preferencesWindowController == nil {
            let view = PreferencesView()
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Settings"
            window.setContentSize(NSSize(width: 420, height: 220))
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
