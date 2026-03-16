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
    static func convert(inputURL: URL, toFormat: String) async throws -> URL {
        let outputURL = makeOutputURL(inputURL: inputURL, toFormat: toFormat)
        let inputExt = inputURL.pathExtension.lowercased()
        let outputExt = toFormat.lowercased()

        if ["mp4", "mov", "avi", "mkv", "webm", "m4v", "mp3", "wav", "flac", "aac", "m4a", "ogg", "aiff"].contains(inputExt) {
            _ = try await ExtensionShell.run([toolPath("ffmpeg"), "-y", "-i", inputURL.path, outputURL.path])
            return outputURL
        }

        if ["jpg", "jpeg", "png", "webp", "heic", "tiff", "bmp", "gif", "svg", "cr2", "nef", "arw"].contains(inputExt) {
            _ = try await ExtensionShell.run([toolPath("magick"), inputURL.path, outputURL.path])
            return outputURL
        }

        if ["doc", "docx", "odt", "pptx", "pages", "xlsx", "xls", "ods", "numbers"].contains(inputExt) {
            let soffice = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
            _ = try await ExtensionShell.run([soffice, "--headless", "--convert-to", outputExt, inputURL.path, "--outdir", outputURL.deletingLastPathComponent().path])
            return outputURL
        }

        if ["md", "html", "txt", "pdf", "epub", "rtf"].contains(inputExt) {
            _ = try await ExtensionShell.run([toolPath("pandoc"), inputURL.path, "-o", outputURL.path])
            return outputURL
        }

        if ["csv", "tsv", "json"].contains(inputExt), ["csv", "tsv", "txt", "json"].contains(outputExt) {
            let data = try Data(contentsOf: inputURL)
            try data.write(to: outputURL)
            return outputURL
        }

        throw ExtensionConversionRouterError.unsupported
    }

    private static func makeOutputURL(inputURL: URL, toFormat: String) -> URL {
        let folder = inputURL.deletingLastPathComponent()
        let base = inputURL.deletingPathExtension().lastPathComponent
        var outputURL = folder.appendingPathComponent("\(base).\(toFormat.lowercased())")

        if !FileManager.default.fileExists(atPath: outputURL.path) {
            return outputURL
        }

        var index = 1
        while FileManager.default.fileExists(atPath: outputURL.path) {
            outputURL = folder.appendingPathComponent("\(base)_converted_\(index).\(toFormat.lowercased())")
            index += 1
        }

        return outputURL
    }

    private static func toolPath(_ name: String) -> String {
        let candidates = ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)"]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? name
    }
}
