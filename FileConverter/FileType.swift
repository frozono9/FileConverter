import Foundation

enum FileType {
    static func outputFormats(for ext: String) -> [String] {
        switch ext.lowercased() {
        case "pdf": return ["md", "docx", "txt", "html"]
        case "docx": return ["pdf", "md", "txt", "html", "rtf"]
        case "doc": return ["pdf", "docx", "md", "txt"]
        case "md": return ["pdf", "html", "docx", "txt"]
        case "html": return ["pdf", "md", "docx", "txt"]
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

        case "jpg", "jpeg": return ["png", "webp", "pdf", "tiff", "bmp", "heic", "svg"]
        case "png": return ["jpg", "webp", "pdf", "tiff", "bmp", "heic", "svg"]
        case "webp": return ["jpg", "png", "tiff", "pdf", "svg"]
        case "heic": return ["jpg", "png", "webp", "tiff", "svg"]
        case "tiff": return ["jpg", "png", "webp", "pdf"]
        case "bmp": return ["jpg", "png", "webp"]
        case "gif": return ["mp4", "png", "webp"]
        case "svg": return ["png", "pdf", "jpg"]
        case "cr2", "nef", "arw": return ["jpg", "png", "tiff"]

        case "mp4": return ["mov", "gif", "mp3"]
        case "mov": return ["mp4", "gif", "mp3", "m4a"]
        case "mkv": return ["mp4", "mov", "mp3", "m4a"]
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
}
