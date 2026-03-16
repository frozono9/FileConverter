//
//  FileConverterApp.swift
//  FileConverter
//
//  Created by Alex Latorre on 16/3/26.
//

import SwiftUI

@main
struct FileConverterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
