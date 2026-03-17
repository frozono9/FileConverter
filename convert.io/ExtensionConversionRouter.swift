import Foundation

enum ExtensionConversionRouterError: LocalizedError {
    case unsupported

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Unsupported conversion type."
        }
    }
}

enum ExtensionConversionRouter {
    static let createCopyPreferenceKey = "fc.createCopyOnConversion"
    static let suiteName = "group.me.Latorre.Alex.FileConverter"

    static func convert(inputURL: URL, toFormat: String) async throws -> URL {
        let sharedDefaults = UserDefaults(suiteName: suiteName)
        let createCopy = (sharedDefaults?.object(forKey: createCopyPreferenceKey) as? Bool)
            ?? (UserDefaults.standard.object(forKey: createCopyPreferenceKey) as? Bool)
            ?? true
        
        let outputURL = makeOutputURL(inputURL: inputURL, toFormat: toFormat, createCopy: createCopy)
        let inputExt = inputURL.pathExtension.lowercased()
        let outputExt = toFormat.lowercased()

        if ["mp4", "mov", "mkv", "webm", "m4v", "mp3", "wav", "flac", "aac", "m4a", "ogg", "aiff"].contains(inputExt) {
            _ = try await ExtensionShell.run([toolPath("ffmpeg"), "-y", "-i", inputURL.path, outputURL.path])
            return try finalizeOutput(inputURL: inputURL, outputURL: outputURL, createCopy: createCopy)
        }

        if ["jpg", "jpeg", "png", "webp", "heic", "tiff", "bmp", "gif", "svg", "cr2", "nef", "arw"].contains(inputExt) {
            _ = try await ExtensionShell.run([toolPath("magick"), inputURL.path, outputURL.path])
            return try finalizeOutput(inputURL: inputURL, outputURL: outputURL, createCopy: createCopy)
        }

        if ["doc", "docx", "odt", "pptx", "pages", "xlsx", "xls", "ods", "numbers"].contains(inputExt) {
            let soffice = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
            _ = try await ExtensionShell.run([soffice, "--headless", "--convert-to", outputExt, inputURL.path, "--outdir", outputURL.deletingLastPathComponent().path])
            return try finalizeOutput(inputURL: inputURL, outputURL: outputURL, createCopy: createCopy)
        }

        if ["md", "html", "txt", "pdf", "epub", "rtf"].contains(inputExt) {
            _ = try await ExtensionShell.run([toolPath("pandoc"), inputURL.path, "-o", outputURL.path])
            return try finalizeOutput(inputURL: inputURL, outputURL: outputURL, createCopy: createCopy)
        }

        if ["csv", "tsv", "json"].contains(inputExt), ["csv", "tsv", "txt", "json"].contains(outputExt) {
            let data = try Data(contentsOf: inputURL)
            try data.write(to: outputURL)
            return try finalizeOutput(inputURL: inputURL, outputURL: outputURL, createCopy: createCopy)
        }

        throw ExtensionConversionRouterError.unsupported
    }

    private static func makeOutputURL(inputURL: URL, toFormat: String, createCopy: Bool) -> URL {
        let folder = inputURL.deletingLastPathComponent()
        let base = inputURL.deletingPathExtension().lastPathComponent
        let candidate = folder.appendingPathComponent("\(base).\(toFormat.lowercased())")

        if !createCopy {
            return candidate
        }

        if !FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        var index = 1
        var outputURL = candidate
        while FileManager.default.fileExists(atPath: outputURL.path) {
            outputURL = folder.appendingPathComponent("\(base)_converted_\(index).\(toFormat.lowercased())")
            index += 1
        }

        return outputURL
    }

    private static func finalizeOutput(inputURL: URL, outputURL: URL, createCopy: Bool) throws -> URL {
        guard !createCopy else {
            return outputURL
        }

        let inputPath = inputURL.standardizedFileURL.path
        let outputPath = outputURL.standardizedFileURL.path
        
        // If they are the same file (e.g. converting png to png), don't delete
        guard inputPath != outputPath else {
            return outputURL
        }

        if FileManager.default.fileExists(atPath: inputURL.path) {
            try FileManager.default.removeItem(at: inputURL)
        }
        return outputURL
    }

    private static func toolPath(_ name: String) -> String {
        let candidates = ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)"]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? name
    }
}
