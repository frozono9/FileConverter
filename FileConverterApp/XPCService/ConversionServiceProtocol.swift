//
//  ConversionServiceProtocol.swift
//  FileConverter
//

import Foundation

@objc protocol ConversionServiceProtocol {
    func convert(inputPath: String, toFormat: String, reply: @escaping (Bool, String) -> Void)
}
