import Foundation

enum ConversionRouterError: LocalizedError {
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported input/output format combination."
        }
    }
}

final class ConversionRouter {
    static let shared = ConversionRouter()
    static let createCopyPreferenceKey = "fc.createCopyOnConversion"
    static let suiteName = "group.me.Latorre.Alex.FileConverter"

    private init() {}

    func convert(inputURL: URL, toFormat: String) async throws -> URL {
        let sharedDefaults = UserDefaults(suiteName: Self.suiteName)
        let createCopy = (sharedDefaults?.object(forKey: Self.createCopyPreferenceKey) as? Bool)
            ?? (UserDefaults.standard.object(forKey: Self.createCopyPreferenceKey) as? Bool)
            ?? true
        let outputURL = makeOutputURL(inputURL: inputURL, toFormat: toFormat, createCopy: createCopy)
        let inputExt = inputURL.pathExtension.lowercased()
        let outputExt = toFormat.lowercased()

        if ["mp4", "mov", "avi", "mkv", "webm", "m4v", "mp3", "wav", "flac", "aac", "m4a", "ogg", "aiff"].contains(inputExt) {
            let ffmpeg = DependencyChecker.shared.toolPath("ffmpeg")
            _ = try await Shell.run([ffmpeg, "-y", "-i", inputURL.path, outputURL.path])
            return try finalizeOutput(inputURL: inputURL, outputURL: outputURL, createCopy: createCopy)
        }

        if ["jpg", "jpeg", "png", "webp", "heic", "tiff", "bmp", "gif", "svg", "cr2", "nef", "arw"].contains(inputExt) {
            let magick = DependencyChecker.shared.toolPath("magick")
            _ = try await Shell.run([magick, inputURL.path, outputURL.path])
            return try finalizeOutput(inputURL: inputURL, outputURL: outputURL, createCopy: createCopy)
        }

        if ["doc", "docx", "odt", "pptx", "pages", "xlsx", "xls", "ods", "numbers"].contains(inputExt) {
            let soffice = DependencyChecker.shared.toolPath("soffice")
            _ = try await Shell.run([soffice, "--headless", "--convert-to", outputExt, inputURL.path, "--outdir", outputURL.deletingLastPathComponent().path])
            let normalized = normalizeLibreOfficeOutput(expected: outputURL, inputURL: inputURL, outputExt: outputExt)
            return try finalizeOutput(inputURL: inputURL, outputURL: normalized, createCopy: createCopy)
        }

        if ["md", "html", "txt", "pdf", "epub", "rtf"].contains(inputExt) {
            let pandoc = DependencyChecker.shared.toolPath("pandoc")
            _ = try await Shell.run([pandoc, inputURL.path, "-o", outputURL.path])
            return try finalizeOutput(inputURL: inputURL, outputURL: outputURL, createCopy: createCopy)
        }

        if ["csv", "tsv", "json"].contains(inputExt) {
            let converted = try convertTabular(inputURL: inputURL, outputURL: outputURL)
            return try finalizeOutput(inputURL: inputURL, outputURL: converted, createCopy: createCopy)
        }

        throw ConversionRouterError.unsupportedFormat
    }

    private func convertTabular(inputURL: URL, outputURL: URL) throws -> URL {
        let inputData = try Data(contentsOf: inputURL)
        let inputText = String(decoding: inputData, as: UTF8.self)

        switch outputURL.pathExtension.lowercased() {
        case "txt", "csv", "tsv", "json":
            try inputText.write(to: outputURL, atomically: true, encoding: .utf8)
            return outputURL
        default:
            throw ConversionRouterError.unsupportedFormat
        }
    }

    private func makeOutputURL(inputURL: URL, toFormat: String, createCopy: Bool) -> URL {
        let directory = inputURL.deletingLastPathComponent()
        let base = inputURL.deletingPathExtension().lastPathComponent
        var candidate = directory.appendingPathComponent("\(base).\(toFormat.lowercased())")

        if !createCopy {
            return candidate
        }

        if !FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        var index = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base)_converted_\(index).\(toFormat.lowercased())")
            index += 1
        }
        return candidate
    }

    private func finalizeOutput(inputURL: URL, outputURL: URL, createCopy: Bool) throws -> URL {
        guard !createCopy else {
            return outputURL
        }

        let inputPath = inputURL.standardizedFileURL.path
        let outputPath = outputURL.standardizedFileURL.path
        guard inputPath != outputPath else {
            return outputURL
        }

        if FileManager.default.fileExists(atPath: inputURL.path) {
            try FileManager.default.removeItem(at: inputURL)
        }
        return outputURL
    }

    private func normalizeLibreOfficeOutput(expected: URL, inputURL: URL, outputExt: String) -> URL {
        if FileManager.default.fileExists(atPath: expected.path) {
            return expected
        }

        let directory = expected.deletingLastPathComponent()
        let loDefault = directory.appendingPathComponent("\(inputURL.deletingPathExtension().lastPathComponent).\(outputExt)")
        if FileManager.default.fileExists(atPath: loDefault.path) {
            return loDefault
        }
        return expected
    }
}
