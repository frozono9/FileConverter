//
//  ConversionXPCService.swift
//  FileConverter
//

import Foundation

class ConversionXPCService: NSObject, ConversionServiceProtocol {
    func convert(inputPath: String, toFormat: String, reply: @escaping (Bool, String) -> Void) {
        let inputURL = URL(fileURLWithPath: inputPath)
        
        Task {
            do {
                let result = try await ConversionRouter.shared.convert(inputURL: inputURL, toFormat: toFormat)
                reply(true, result)
            } catch {
                reply(false, error.localizedDescription)
            }
        }
    }
}

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: ConversionServiceProtocol.self)
        newConnection.exportedObject = ConversionXPCService()
        newConnection.resume()
        return true
    }
}
