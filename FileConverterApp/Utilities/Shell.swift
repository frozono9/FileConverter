//
//  Shell.swift
//  FileConverter
//

import Foundation

enum ShellError: Error {
    case processFailed(String)
}

struct Shell {
    @discardableResult
    static func run(_ args: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
        } catch {
            throw ShellError.processFailed("Failed to start process: \(error.localizedDescription)")
        }
        
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        guard process.terminationStatus == 0 else {
            throw ShellError.processFailed(output)
        }
        
        return output
    }
}
