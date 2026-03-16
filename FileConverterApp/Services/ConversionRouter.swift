//
//  ConversionRouter.swift
//  FileConverter
//

import Foundation

class ConversionRouter {
    static let shared = ConversionRouter()

    func convert(inputURL: URL, toFormat: String) async throws -> String {
        let inputExt = inputURL.pathExtension.lowercased()
        let outputURL = try getOutputURL(for: inputURL, toFormat: toFormat)
        
        switch inputExt {
        // Handle Video/Audio via FFmpeg
        case "mp4", "mov", "avi", "mkv", "webm", "m4v", "mp3", "wav", "flac", "aac", "m4a", "ogg", "aiff":
            return try await FFmpegConverter.convert(input: inputURL, output: outputURL)
            
        // Handle Images via ImageMagick
        case "jpg", "jpeg", "png", "webp", "heic", "tiff", "bmp", "gif", "svg", "cr2", "nef", "arw":
            return try await ImageMagickConverter.convert(input: inputURL, output: outputURL)
            
        // Handle Documents via Pandoc or LibreOffice
        case "md", "html", "txt", "docx", "pdf":
             // Simple Pandoc cases
             return try await PandocConverter.convert(input: inputURL, output: outputURL)
             
        case "doc", "pages", "odt", "epub", "pptx":
            return try await LibreOfficeConverter.convert(input: inputURL, output: outputURL)

        // Handle Spreadsheets
        case "xlsx", "xls", "csv", "tsv", "ods", "numbers", "json":
            if ["ods", "numbers"].contains(inputExt) {
                return try await LibreOfficeConverter.convert(input: inputURL, output: outputURL)
            } else {
                return try await SpreadsheetConverter.convert(input: inputURL, output: outputURL)
            }
            
        default:
            throw NSError(domain: "ConversionRouter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported format"])
        }
    }
    
    private func getOutputURL(for inputURL: URL, toFormat: String) throws -> URL {
        let folder = inputURL.deletingLastPathComponent()
        let fileName = inputURL.deletingPathExtension().lastPathComponent
        var outputURL = folder.appendingPathComponent("\(fileName).\(toFormat)")
        
        // Check for existing files and append _converted if needed
        var counter = 1
        while FileManager.default.fileExists(atPath: outputURL.path) {
            outputURL = folder.appendingPathComponent("\(fileName)_converted_\(counter).\(toFormat)")
            counter += 1
        }
        
        return outputURL
    }
}

struct FFmpegConverter {
    static func convert(input: URL, output: URL) async throws -> String {
        let ffmpeg = DependencyChecker.shared.toolPath(for: "ffmpeg")
        return try await Shell.run([ffmpeg, "-i", input.path, output.path])
    }
}

struct ImageMagickConverter {
    static func convert(input: URL, output: URL) async throws -> String {
        let magick = DependencyChecker.shared.toolPath(for: "magick")
        return try await Shell.run([magick, input.path, output.path])
    }
}

struct PandocConverter {
    static func convert(input: URL, output: URL) async throws -> String {
        let pandoc = DependencyChecker.shared.toolPath(for: "pandoc")
        return try await Shell.run([pandoc, input.path, "-o", output.path])
    }
}

struct LibreOfficeConverter {
    static func convert(input: URL, output: URL) async throws -> String {
        let loPath = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
        let outputFolder = output.deletingLastPathComponent().path
        return try await Shell.run([loPath, "--headless", "--convert-to", output.pathExtension, input.path, "--outdir", outputFolder])
    }
}

struct SpreadsheetConverter {
    static func convert(input: URL, output: URL) async throws -> String {
        let python = DependencyChecker.shared.toolPath(for: "python3")
        // This assumes a script exists to handle spreadsheets via pandas/openpyxl
        let scriptPath = Bundle.main.path(forResource: "spreadsheet_convert", ofType: "py") ?? "spreadsheet_convert.py"
        return try await Shell.run([python, scriptPath, input.path, output.path])
    }
}
