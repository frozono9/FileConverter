import Cocoa
import FinderSync
import os
import CoreGraphics
import ImageIO
import PDFKit

class FinderSync: FIFinderSync {
    private let logger = Logger(subsystem: "me.Latorre.Alex.FileConverter.FinderSync", category: "menu")
    private enum BadgeState { case converting, done, failed, clear }
    private let extensionEnabledKey = "fc.extensionEnabled"
    private let sharedSuiteName = "group.me.Latorre.Alex.FileConverter"
    private lazy var ffmpegAvailableInExtension = checkFFmpegAvailability()

    override init() {
        super.init()

        // Keep the extension active in any Finder location.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        FIFinderSyncController.default().setBadgeImage(
            NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Converting")!,
            label: "Converting",
            forBadgeIdentifier: "converting"
        )
        FIFinderSyncController.default().setBadgeImage(
            NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Done")!,
            label: "Done",
            forBadgeIdentifier: "done"
        )
        FIFinderSyncController.default().setBadgeImage(
            NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Failed")!,
            label: "Failed",
            forBadgeIdentifier: "failed"
        )
        logger.log("FinderSync init")
        NSLog("[FileConverter FinderSync] init")
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard isExtensionEnabled() else {
            return nil
        }

        guard menuKind == .contextualMenuForItems,
              let selected = FIFinderSyncController.default().selectedItemURLs(),
              let first = selected.first else {
            return nil
        }

        let parent = first.deletingLastPathComponent()
        FIFinderSyncController.default().directoryURLs = [parent]
        writeActionTrace("menu shown file=\(first.path) ext=\(first.pathExtension.lowercased())")

        logger.log("Menu callback kind=\(menuKind.rawValue)")
        NSLog("[FileConverter FinderSync] menu kind=%ld", menuKind.rawValue)

        logger.log("Menu requested kind=\(menuKind.rawValue) selected=\(selected.count)")
        NSLog("[FileConverter FinderSync] selected count=%ld", selected.count)

        let root = NSMenu(title: "FileConverter")
        let ext = first.pathExtension.lowercased()
        let formats = outputFormats(for: ext)

        guard !formats.isEmpty else {
            let none = NSMenuItem(title: "No conversion available for .\(ext)", action: nil, keyEquivalent: "")
            none.isEnabled = false
            root.addItem(none)
            return root
        }

        let convertItem = NSMenuItem(title: "File Converter", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Formats")

        for format in formats {
            let item = NSMenuItem(title: format.uppercased(), action: #selector(performConversion(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ["url": first as Any, "format": format]
            submenu.addItem(item)
        }

        convertItem.submenu = submenu
        root.addItem(convertItem)

        return root
    }

    private func isExtensionEnabled() -> Bool {
        if let shared = UserDefaults(suiteName: sharedSuiteName)?.object(forKey: extensionEnabledKey) as? Bool {
            return shared
        }
        if let local = UserDefaults.standard.object(forKey: extensionEnabledKey) as? Bool {
            return local
        }
        return true
    }

    @objc func performConversion(_ sender: Any?) {
        guard let item = sender as? NSMenuItem else {
            logger.error("Action failed: sender is not NSMenuItem")
            writeActionTrace("failure invalid sender type")
            return
        }

        let payload = item.representedObject as? [String: Any]
        let payloadURL = payload?["url"] as? URL
        let fallbackURL = FIFinderSyncController.default().selectedItemURLs()?.first
        guard let selected = payloadURL ?? fallbackURL else {
            logger.error("Action failed: no selected file URL")
            writeActionTrace("failure no selected URL")
            return
        }

        let payloadFormat = payload?["format"] as? String
        let fallbackFormat = item.title.lowercased()
        let format = (payloadFormat?.isEmpty == false ? payloadFormat! : fallbackFormat)

        logger.log("Action fired format=\(format, privacy: .public) file=\(selected.path, privacy: .public)")
        NSLog("[FileConverter FinderSync] performConversion format=%@ file=%@", format, selected.path)
        writeActionTrace("clicked format=\(format) input=\(selected.path)")

        DispatchQueue.main.async { [weak self] in
            self?.setBadge(for: selected, state: .converting)
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                guard let self else { return }
                let outputURL = try self.convert(inputURL: selected, toFormat: format)
                self.logger.log("Conversion succeeded output=\(outputURL.path, privacy: .public)")
                NSLog("[FileConverter FinderSync] conversion output=%@", outputURL.path)
                self.writeActionTrace("success output=\(outputURL.path)")
                DispatchQueue.main.async { [weak self] in
                    self?.setBadge(for: selected, state: .done)
                }
            } catch {
                self?.logger.error("Conversion failed: \(error.localizedDescription, privacy: .public)")
                NSLog("[FileConverter FinderSync] conversion error=%@", error.localizedDescription)
                self?.writeActionTrace("failure error=\(error.localizedDescription)")
                self?.writeErrorReport(for: selected, format: format, error: error)
                DispatchQueue.main.async { [weak self] in
                    self?.setBadge(for: selected, state: .failed)
                }
            }
        }
    }

    private func setBadge(for url: URL, state: BadgeState) {
        let id: String
        switch state {
        case .converting: id = "converting"
        case .done: id = "done"
        case .failed: id = "failed"
        case .clear: id = ""
        }
        FIFinderSyncController.default().setBadgeIdentifier(id, for: url)

        let clearDelay: TimeInterval?
        switch state {
        case .done:
            clearDelay = 2
        case .failed:
            clearDelay = 5
        case .converting, .clear:
            clearDelay = nil
        }

        if let delay = clearDelay {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                FIFinderSyncController.default().setBadgeIdentifier("", for: url)
            }
        }
    }

    private func writeErrorReport(for inputURL: URL, format: String, error: Error) {
        let folder = inputURL.deletingLastPathComponent()
        let base = inputURL.deletingPathExtension().lastPathComponent
        let reportURL = folder.appendingPathComponent("\(base)_conversion_error_\(format).txt")
        let body = "Conversion failed\ninput=\(inputURL.path)\nformat=\(format)\nerror=\(error.localizedDescription)\n"
        try? body.write(to: reportURL, atomically: true, encoding: .utf8)
    }

    private func writeActionTrace(_ line: String) {
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
        let traceURL = downloads.appendingPathComponent("FileConverter_findersync_trace.log")
        let stamp = ISO8601DateFormatter().string(from: Date())
        let row = "[\(stamp)] \(line)\n"
        guard let data = row.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: traceURL.path),
           let handle = try? FileHandle(forWritingTo: traceURL) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: traceURL, options: .atomic)
        }
    }

    private func outputFormats(for ext: String) -> [String] {
        switch ext {
        case "pdf": return ["md", "docx", "txt", "html"]
        case "docx": return ["pdf", "md", "txt", "html", "rtf"]
        case "doc": return ["pdf", "docx", "md", "txt"]
        case "md": return ["pdf", "html", "docx", "txt"]
        case "html", "htm": return ["pdf", "md", "docx", "txt"]
        case "rtf": return ["pdf", "docx", "txt"]
        case "txt": return ["pdf", "md", "docx", "html"]
        case "pages": return ["pdf", "docx"]
        case "odt": return ["pdf", "docx", "txt"]
        case "epub": return ["pdf", "md", "txt"]
        case "pptx": return ["pdf"]

        case "xlsx": return ["csv", "json", "ods", "pdf", "html", "tsv"]
        case "xls": return ["xlsx", "csv", "ods", "pdf"]
        case "csv": return ["xlsx", "json", "ods", "html", "tsv"]
        case "tsv": return ["csv", "xlsx", "json"]
        case "ods": return ["xlsx", "csv", "pdf"]
        case "numbers": return ["xlsx", "csv", "pdf"]
        case "json": return ["csv", "xlsx"]

        case "jpg", "jpeg": return ["png", "webp", "pdf", "tiff", "bmp", "heic"]
        case "png": return ["jpg", "webp", "pdf", "tiff", "bmp", "heic"]
        case "webp": return ["jpg", "png", "tiff", "pdf"]
        case "heic": return ["jpg", "png", "webp", "tiff"]
        case "tiff", "tif": return ["jpg", "png", "webp", "pdf"]
        case "bmp": return ["jpg", "png", "webp"]
        case "gif":
            return ffmpegAvailableInExtension ? ["mp4", "png", "webp"] : ["png", "webp"]
        case "svg": return ["png", "pdf", "jpg"]
        case "cr2", "nef", "arw": return ["jpg", "png", "tiff"]

        case "mp4", "mov", "avi", "mkv", "webm",
             "mp3", "wav", "flac", "aac", "m4a", "ogg", "aiff":
            return ffmpegAvailableInExtension ? mediaFormats(for: ext) : []

        default: return []
        }
    }

    private func mediaFormats(for ext: String) -> [String] {
        switch ext {
        case "mp4": return ["mov", "avi", "mkv", "gif", "mp3", "m4a", "webm"]
        case "mov": return ["mp4", "avi", "mkv", "gif", "mp3", "m4a"]
        case "avi": return ["mp4", "mov", "mkv", "mp3"]
        case "mkv": return ["mp4", "mov", "avi", "mp3", "m4a"]
        case "webm": return ["mp4", "gif", "mp3"]
        case "mp3": return ["wav", "aac", "flac", "ogg", "m4a", "aiff"]
        case "wav": return ["mp3", "aac", "flac", "ogg", "m4a", "aiff"]
        case "flac": return ["mp3", "wav", "aac", "m4a", "aiff"]
        case "aac", "m4a": return ["mp3", "wav", "flac", "ogg"]
        case "ogg": return ["mp3", "wav", "flac", "aac"]
        case "aiff": return ["mp3", "wav", "flac", "aac"]
        default: return []
        }
    }

    private func convert(inputURL: URL, toFormat: String) throws -> URL {
        let parentURL = inputURL.deletingLastPathComponent()
        let accessingInput = inputURL.startAccessingSecurityScopedResource()
        let accessingParent = parentURL.startAccessingSecurityScopedResource()
        defer {
            if accessingInput {
                inputURL.stopAccessingSecurityScopedResource()
            }
            if accessingParent {
                parentURL.stopAccessingSecurityScopedResource()
            }
        }

        let inputExt = inputURL.pathExtension.lowercased()
        let createCopy = createCopyPreference()
        let outputURL = outputURL(for: inputURL, toFormat: toFormat, createCopy: createCopy)

        if isImageExt(inputExt) {
            try convertImageLike(inputURL: inputURL, outputURL: outputURL, toFormat: toFormat)
            return try finalizeOutput(inputURL: inputURL, outputURL: outputURL, createCopy: createCopy)
        }

        if isDocumentExt(inputExt) {
            try convertDocument(inputURL: inputURL, outputURL: outputURL, toFormat: toFormat)
            return try finalizeOutput(inputURL: inputURL, outputURL: outputURL, createCopy: createCopy)
        }

        if isSpreadsheetExt(inputExt) {
            try convertSpreadsheet(inputURL: inputURL, outputURL: outputURL, toFormat: toFormat)
            return try finalizeOutput(inputURL: inputURL, outputURL: outputURL, createCopy: createCopy)
        }

        if isMediaExt(inputExt) {
            try convertMedia(inputURL: inputURL, outputURL: outputURL)
            return try finalizeOutput(inputURL: inputURL, outputURL: outputURL, createCopy: createCopy)
        }

        throw NSError(domain: "FileConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported conversion."])
    }

    private func convertImage(inputURL: URL, outputURL: URL, toFormat: String) throws {
        let bitmap: NSBitmapImageRep
        if let src = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
           let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            bitmap = NSBitmapImageRep(cgImage: cg)
        } else if let data = try? Data(contentsOf: inputURL),
                  let rep = NSBitmapImageRep(data: data) {
            bitmap = rep
        } else if let image = NSImage(contentsOf: inputURL),
                  let tiffData = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiffData) {
            bitmap = rep
        } else {
            throw NSError(
                domain: "FileConverter",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "Cannot read image at \(inputURL.path)"]
            )
        }

        let format = toFormat.lowercased()
        if format == "pdf" {
            guard let cg = bitmap.cgImage else {
                throw NSError(domain: "FileConverter", code: 11, userInfo: [NSLocalizedDescriptionKey: "Cannot render image as PDF."])
            }
            var mediaBox = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
            let data = NSMutableData()
            guard let consumer = CGDataConsumer(data: data),
                  let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
                throw NSError(domain: "FileConverter", code: 12, userInfo: [NSLocalizedDescriptionKey: "Cannot create PDF context."])
            }
            context.beginPDFPage(nil)
            context.draw(cg, in: mediaBox)
            context.endPDFPage()
            context.closePDF()
            try (data as Data).write(to: outputURL)
            return
        }

        let fileType: NSBitmapImageRep.FileType
        let props: [NSBitmapImageRep.PropertyKey: Any]
        switch format {
        case "jpg", "jpeg":
            fileType = .jpeg
            props = [.compressionFactor: 0.9]
        case "png":
            fileType = .png
            props = [:]
        case "tiff", "tif":
            fileType = .tiff
            props = [:]
        default:
            throw NSError(domain: "FileConverter", code: 13, userInfo: [NSLocalizedDescriptionKey: "Unsupported image output format: \(format)"])
        }

        guard let outData = bitmap.representation(using: fileType, properties: props) else {
            throw NSError(domain: "FileConverter", code: 14, userInfo: [NSLocalizedDescriptionKey: "Cannot encode output image."])
        }
        try outData.write(to: outputURL)
    }

    private func convertImageLike(inputURL: URL, outputURL: URL, toFormat: String) throws {
        let inputExt = inputURL.pathExtension.lowercased()
        let format = toFormat.lowercased()

        if inputExt == "gif" && format == "mp4" {
            try convertMedia(inputURL: inputURL, outputURL: outputURL)
            return
        }

        if ["jpg", "jpeg", "png", "tiff", "tif", "pdf"].contains(format) {
            do {
                try convertImage(inputURL: inputURL, outputURL: outputURL, toFormat: format)
                return
            } catch {
                // Fall through to magick for formats that NSBitmapImageRep cannot decode/encode.
            }
        }

        try convertWithMagick(inputURL: inputURL, outputURL: outputURL, toFormat: format)
    }

    private func convertTextLike(inputURL: URL, inputExt: String, outputURL: URL, toFormat: String) throws {
        let sourceText = try readText(from: inputURL, ext: inputExt)
        let format = toFormat.lowercased()

        if format == "txt" || format == "md" {
            try sourceText.write(to: outputURL, atomically: true, encoding: .utf8)
            return
        }

        if format == "html" {
            let escaped = escapeHTML(sourceText)
            let html = "<html><body><pre>\(escaped)</pre></body></html>"
            try html.write(to: outputURL, atomically: true, encoding: .utf8)
            return
        }

        let attributed = NSAttributedString(string: sourceText)
        if format == "pdf" {
            let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 595, height: 842))
            textView.isRichText = false
            textView.textStorage?.setAttributedString(attributed)
            let data = textView.dataWithPDF(inside: textView.bounds)
            try data.write(to: outputURL)
            return
        }

        if format == "rtf" {
            let data = try attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            try data.write(to: outputURL)
            return
        }

        throw NSError(domain: "FileConverter", code: 15, userInfo: [NSLocalizedDescriptionKey: "Unsupported text output format: \(format)"])
    }

    private func convertDocument(inputURL: URL, outputURL: URL, toFormat: String) throws {
        let inputExt = inputURL.pathExtension.lowercased()
        let format = toFormat.lowercased()

        if ["txt", "md", "html", "htm", "rtf", "pdf"].contains(inputExt) {
            if ["txt", "md", "html", "pdf", "rtf"].contains(format) {
                try convertTextLike(inputURL: inputURL, inputExt: inputExt, outputURL: outputURL, toFormat: format)
                return
            }
            if ["docx"].contains(format) {
                try convertWithPandoc(inputURL: inputURL, outputURL: outputURL)
                return
            }
        }

        if ["docx", "doc", "odt", "pages", "epub", "pptx"].contains(inputExt) {
            if ["pdf", "docx", "txt", "html", "rtf", "md"].contains(format) {
                if format == "md" {
                    let tempDocx = temporaryURL(fileExtension: "docx")
                    try convertWithLibreOffice(inputURL: inputURL, outputURL: tempDocx, toFormat: "docx")
                    try convertWithPandoc(inputURL: tempDocx, outputURL: outputURL)
                    try? FileManager.default.removeItem(at: tempDocx)
                    return
                }
                try convertWithLibreOffice(inputURL: inputURL, outputURL: outputURL, toFormat: format)
                return
            }
        }

        throw NSError(domain: "FileConverter", code: 17, userInfo: [NSLocalizedDescriptionKey: "Unsupported document conversion: \(inputExt) -> \(format)"])
    }

    private func convertSpreadsheet(inputURL: URL, outputURL: URL, toFormat: String) throws {
        let inputExt = inputURL.pathExtension.lowercased()
        let format = toFormat.lowercased()

        if ["xlsx", "xls", "csv", "tsv", "json"].contains(inputExt),
           ["xlsx", "csv", "tsv", "json", "html", "ods"].contains(format) {
            try convertSpreadsheetWithPython(inputURL: inputURL, outputURL: outputURL, toFormat: format)
            return
        }

        if ["ods", "numbers", "xlsx", "xls", "csv", "tsv"].contains(inputExt),
           ["pdf", "csv", "xlsx", "ods", "html"].contains(format) {
            try convertWithLibreOffice(inputURL: inputURL, outputURL: outputURL, toFormat: format)
            return
        }

        throw NSError(domain: "FileConverter", code: 18, userInfo: [NSLocalizedDescriptionKey: "Unsupported spreadsheet conversion: \(inputExt) -> \(format)"])
    }

    private func convertMedia(inputURL: URL, outputURL: URL) throws {
        guard ffmpegAvailableInExtension, let ffmpeg = toolPath("ffmpeg") else {
            throw NSError(domain: "FileConverter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Media conversion is unavailable from Finder extension on this system. Use the File Converter app menu for media conversion."])
        }
        try runCommand(executablePath: ffmpeg, args: ["-y", "-i", inputURL.path, outputURL.path])
    }

    private func checkFFmpegAvailability() -> Bool {
        guard let ffmpeg = toolPath("ffmpeg") else {
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = ["-version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func convertWithMagick(inputURL: URL, outputURL: URL, toFormat: String) throws {
        guard let magick = toolPath("magick") else {
            throw NSError(domain: "FileConverter", code: 19, userInfo: [NSLocalizedDescriptionKey: "Install ImageMagick: brew install imagemagick"])
        }
        let sourceArg = inputURL.pathExtension.lowercased() == "gif" && toFormat == "png"
            ? "\(inputURL.path)[0]"
            : inputURL.path
        try runCommand(executablePath: magick, args: [sourceArg, outputURL.path])
    }

    private func convertWithPandoc(inputURL: URL, outputURL: URL) throws {
        guard let pandoc = toolPath("pandoc") else {
            throw NSError(domain: "FileConverter", code: 20, userInfo: [NSLocalizedDescriptionKey: "Install pandoc: brew install pandoc"])
        }
        try runCommand(executablePath: pandoc, args: [inputURL.path, "-o", outputURL.path])
    }

    private func convertWithLibreOffice(inputURL: URL, outputURL: URL, toFormat: String) throws {
        guard let soffice = libreOfficePath() else {
            throw NSError(domain: "FileConverter", code: 21, userInfo: [NSLocalizedDescriptionKey: "Install LibreOffice in /Applications."])
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try runCommand(executablePath: soffice, args: ["--headless", "--convert-to", toFormat, inputURL.path, "--outdir", tempDir.path])

        let base = inputURL.deletingPathExtension().lastPathComponent
        let produced = tempDir.appendingPathComponent("\(base).\(toFormat)")
        guard FileManager.default.fileExists(atPath: produced.path) else {
            throw NSError(domain: "FileConverter", code: 22, userInfo: [NSLocalizedDescriptionKey: "LibreOffice did not produce output for format \(toFormat)."])
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        try FileManager.default.moveItem(at: produced, to: outputURL)
    }

    private func convertSpreadsheetWithPython(inputURL: URL, outputURL: URL, toFormat: String) throws {
        guard let python = toolPath("python3") else {
            throw NSError(domain: "FileConverter", code: 23, userInfo: [NSLocalizedDescriptionKey: "Install python3 and pandas/openpyxl."])
        }

        let script = """
import sys
import pandas as pd

inp, out, fmt = sys.argv[1], sys.argv[2], sys.argv[3].lower()
ext = inp.rsplit('.', 1)[-1].lower()

if ext in ('xlsx', 'xls'):
    df = pd.read_excel(inp)
elif ext == 'csv':
    df = pd.read_csv(inp)
elif ext == 'tsv':
    df = pd.read_csv(inp, sep='\\t')
elif ext == 'json':
    df = pd.read_json(inp)
else:
    raise RuntimeError(f'Unsupported spreadsheet input: {ext}')

if fmt == 'csv':
    df.to_csv(out, index=False)
elif fmt == 'tsv':
    df.to_csv(out, sep='\\t', index=False)
elif fmt == 'json':
    df.to_json(out, orient='records', indent=2)
elif fmt == 'xlsx':
    df.to_excel(out, index=False)
elif fmt == 'html':
    df.to_html(out, index=False)
elif fmt == 'ods':
    df.to_excel(out, index=False, engine='odf')
else:
    raise RuntimeError(f'Unsupported spreadsheet output: {fmt}')
"""

        try runCommand(executablePath: python, args: ["-c", script, inputURL.path, outputURL.path, toFormat])
    }

    private func readText(from url: URL, ext: String) throws -> String {
        if ext == "html" || ext == "htm" {
            let data = try Data(contentsOf: url)
            if let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil
            ) {
                return attr.string
            }
        }

        if ext == "rtf" {
            let data = try Data(contentsOf: url)
            if let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) {
                return attr.string
            }
        }

        if ext == "pdf", let pdf = PDFDocument(url: url) {
            return pdf.string ?? ""
        }

        let data = try Data(contentsOf: url)
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let latin1 = String(data: data, encoding: .isoLatin1) {
            return latin1
        }
        throw NSError(domain: "FileConverter", code: 16, userInfo: [NSLocalizedDescriptionKey: "Cannot decode text file."])
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func uniqueOutputURL(for inputURL: URL, toFormat: String) -> URL {
        let folder = inputURL.deletingLastPathComponent()
        let base = inputURL.deletingPathExtension().lastPathComponent
        let ext = toFormat.lowercased()
        var candidate = folder.appendingPathComponent("\(base).\(ext)")

        if !FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        var index = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base)_converted_\(index).\(ext)")
            index += 1
        }
        return candidate
    }

    private func createCopyPreference() -> Bool {
        let key = "fc.createCopyOnConversion"
        if let shared = UserDefaults(suiteName: "group.me.Latorre.Alex.FileConverter")?.object(forKey: key) as? Bool {
            return shared
        }
        if let local = UserDefaults.standard.object(forKey: key) as? Bool {
            return local
        }
        return true
    }

    private func outputURL(for inputURL: URL, toFormat: String, createCopy: Bool) -> URL {
        guard createCopy else {
            let folder = inputURL.deletingLastPathComponent()
            let base = inputURL.deletingPathExtension().lastPathComponent
            let ext = toFormat.lowercased()
            return folder.appendingPathComponent("\(base).\(ext)")
        }
        return uniqueOutputURL(for: inputURL, toFormat: toFormat)
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

    private func isImageExt(_ ext: String) -> Bool {
        ["jpg", "jpeg", "png", "webp", "heic", "tiff", "tif", "bmp", "gif", "svg", "cr2", "nef", "arw"].contains(ext)
    }

    private func isMediaExt(_ ext: String) -> Bool {
        ["mp4", "mov", "mkv", "avi", "webm", "m4v", "mp3", "wav", "flac", "aac", "m4a", "ogg", "aiff"].contains(ext)
    }

    private func isSpreadsheetExt(_ ext: String) -> Bool {
        ["xlsx", "xls", "csv", "tsv", "json", "ods", "numbers"].contains(ext)
    }

    private func isDocumentExt(_ ext: String) -> Bool {
        ["pdf", "docx", "doc", "md", "html", "htm", "rtf", "txt", "pages", "odt", "epub", "pptx"].contains(ext)
    }

    private func temporaryURL(fileExtension: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("fc_\(UUID().uuidString).\(fileExtension)")
    }

    private func libreOfficePath() -> String? {
        let appPath = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
        if FileManager.default.fileExists(atPath: appPath) {
            return appPath
        }
        return toolPath("soffice")
    }

    private func toolPath(_ tool: String) -> String? {
        let paths = ["/opt/homebrew/bin/\(tool)", "/usr/local/bin/\(tool)", "/usr/bin/\(tool)"]
        if let found = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            return found
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [tool]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let out, !out.isEmpty {
                return out
            }
        } catch {
            return nil
        }
        return nil
    }

    private func runCommand(executablePath: String, args: [String]) throws {
        func execute(_ launchPath: String, _ launchArgs: [String]) throws -> String {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = launchArgs
            process.environment = [
                "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            ]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
            } catch {
                throw NSError(
                    domain: "FileConverter",
                    code: 31,
                    userInfo: [NSLocalizedDescriptionKey: "Cannot launch command \(launchPath): \(error.localizedDescription)"]
                )
            }

            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus != 0 {
                throw NSError(
                    domain: "FileConverter",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "Conversion command failed." : output]
                )
            }
            return output
        }

        if FileManager.default.fileExists(atPath: executablePath) {
            do {
                _ = try execute(executablePath, args)
                return
            } catch {
                // Retry via /usr/bin/env when direct launch is denied by runtime policy.
            }
        }

        let toolName = URL(fileURLWithPath: executablePath).lastPathComponent
        do {
            _ = try execute("/usr/bin/env", [toolName] + args)
        } catch {
            throw NSError(
                domain: "FileConverter",
                code: 32,
                userInfo: [NSLocalizedDescriptionKey: "Cannot execute \(toolName). If installed via Homebrew, ensure Finder extension can access it or route conversion through host app/XPC."]
            )
        }
    }
}
