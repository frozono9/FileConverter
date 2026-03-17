import Foundation

final class DependencyChecker {
    static let shared = DependencyChecker()

    private let installCommands: [String: String] = [
        "ffmpeg": "brew install ffmpeg",
        "pandoc": "brew install pandoc",
        "magick": "brew install imagemagick",
        "potrace": "brew install potrace",
        "vpype": "pip3 install vpype",
        "python3": "brew install python",
        "soffice": "brew install --cask libreoffice"
    ]

    private init() {}

    func checkAll() -> [String: Bool] {
        installCommands.keys.reduce(into: [:]) { partial, tool in
            partial[tool] = isInstalled(tool)
        }
    }

    func installHint(for tool: String) -> String {
        installCommands[tool] ?? "Install manually"
    }

    func isInstalled(_ tool: String) -> Bool {
        if tool == "soffice" {
            return FileManager.default.fileExists(atPath: "/Applications/LibreOffice.app/Contents/MacOS/soffice")
        }

        let candidates = [
            "/opt/homebrew/bin/\(tool)",
            "/usr/local/bin/\(tool)",
            "/usr/bin/\(tool)"
        ]
        return candidates.contains(where: { FileManager.default.fileExists(atPath: $0) })
    }

    func toolPath(_ tool: String) -> String {
        if tool == "soffice" {
            return "/Applications/LibreOffice.app/Contents/MacOS/soffice"
        }

        let candidates = [
            "/opt/homebrew/bin/\(tool)",
            "/usr/local/bin/\(tool)",
            "/usr/bin/\(tool)"
        ]

        return candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? tool
    }
}
