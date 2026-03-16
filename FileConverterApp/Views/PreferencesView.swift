//
//  PreferencesView.swift
//  FileConverter
//

import SwiftUI

struct PreferencesView: View {
    @State private var dependencyStatus: [String: Bool] = [:]
    
    var body: some View {
        VStack {
            Text("Dependencies")
                .font(.headline)
                .padding(.top)

            List {
                ForEach(dependencyStatus.sorted(by: <), id: \.key) { name, isInstalled in
                    HStack {
                        Image(systemName: isInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isInstalled ? .green : .red)
                        Text(name)
                        Spacer()
                        if !isInstalled {
                            Button("Copy Install Cmd") {
                                // Logic for copy to clipboard
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .frame(minWidth: 400, minHeight: 300)

            Button("Check Again") {
                dependencyStatus = DependencyChecker.shared.checkAll()
            }
            .padding()
        }
        .onAppear {
            dependencyStatus = DependencyChecker.shared.checkAll()
        }
        .padding()
    }
}
