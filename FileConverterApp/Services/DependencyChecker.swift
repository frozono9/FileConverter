//
//  DependencyChecker.swift
//  FileConverter
//

import Foundation

class DependencyChecker {
    static let shared = DependencyChecker()
    
    private let dependencyMap = [
        "ffmpeg": "brew install ffmpeg",
        "pandoc": "brew install pandoc",
        "magick": "brew install imagemagick",
        "tesseract": "brew install tesseract",
        "pdftotext": "brew install poppler",
        "libreoffice": "brew install --cask libreoffice",
        "python3": "Check Python 3 installation"
    ]
    
    func checkAll() -> [String: Bool] {
        var results = [String: Bool]()
        for tool in dependencyMap.keys {
            results[tool] = isInstalled(tool)
        }
        return results
    }
    
    func isInstalled(_ tool: String) -> Bool {
        if tool == "libreoffice" {
            return FileManager.default.fileExists(atPath: "/Applications/LibreOffice.app")
        }
        
        // Check for common brew paths
        let paths = ["/opt/homebrew/bin/\(tool)", "/usr/local/bin/\(tool)"]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        return false
    }
    
    func toolPath(for tool: String) -> String {
        let paths = ["/opt/homebrew/bin/\(tool)", "/usr/local/bin/\(tool)"]
        return paths.first { FileManager.default.fileExists(atPath: $0) } ?? tool
    }
}
