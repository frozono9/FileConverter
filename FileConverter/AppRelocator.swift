import Foundation
import AppKit

struct AppRelocator {
    static func moveToApplicationsIfNeeded() {
        let bundleURL = Bundle.main.bundleURL
        let applicationsURLList = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
        
        guard let applicationsURL = applicationsURLList.first else { return }
        
        if bundleURL.path.hasPrefix(applicationsURL.path) {
            return
        }
        
        // Skip if we are currently debugging in DerivedData or Downloads/Source
        if bundleURL.path.contains("DerivedData") || bundleURL.path.contains("build_release") {
           return
        }

        let appName = bundleURL.lastPathComponent
        let destinationURL = applicationsURL.appendingPathComponent(appName)
        
        let alert = NSAlert()
        alert.messageText = "Move to Applications folder?"
        alert.informativeText = "To ensure the Finder extension works correctly, the app should be in your Applications folder."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Stay in Downloads")
        
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                try FileManager.default.copyItem(at: bundleURL, to: destinationURL)
                
                // Relaunch the new copy
                let configuration = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: destinationURL, configuration: configuration) { _, _ in
                    NSApplication.shared.terminate(nil)
                }
            } catch {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Could not move app"
                errorAlert.informativeText = error.localizedDescription
                errorAlert.runModal()
            }
        }
    }
}
