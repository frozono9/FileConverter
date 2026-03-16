import Foundation

enum ShellError: LocalizedError {
    case failed(code: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .failed(let code, let output):
            return "Process failed (\(code)): \(output)"
        }
    }
}

enum Shell {
    @discardableResult
    static func run(_ args: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw ShellError.failed(code: process.terminationStatus, output: output)
        }

        return output
    }
}
