import Foundation
import AppKit

struct AppRelocator {
    static func ensureRunningFromApplications() -> Bool {
        let bundleURL = Bundle.main.bundleURL
        let bundlePath = bundleURL.path
        let applicationsURLList = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
        
        guard let applicationsURL = applicationsURLList.first else { return true }
        
        if bundlePath.hasPrefix(applicationsURL.path) {
            return true
        }
        
        // Allow local development runs from Xcode/derived build products.
        if bundlePath.contains("DerivedData") ||
            bundlePath.contains("/Build/Products/Debug/") ||
            bundlePath.contains("/build/Build/Products/Debug/") ||
            bundlePath.contains("build_release") {
           return true
        }
        
        let alert = NSAlert()
        alert.messageText = "Recommended: move FileConverter to Applications"
        alert.informativeText = "Finder integration is more reliable from /Applications. You can continue now and move it later."
        alert.addButton(withTitle: "Open Applications Folder")
        alert.addButton(withTitle: "Continue Anyway")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(applicationsURL)
        }

        return true
    }
}
