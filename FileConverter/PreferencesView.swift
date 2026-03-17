import SwiftUI

struct PreferencesView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(0)
            
            TutorialView()
                .tabItem {
                    Label("Tutorial", systemImage: "book")
                }
                .tag(1)
        }
        .padding(16)
        .frame(width: 450, height: 300)
    }
}

struct SettingsView: View {
    @State private var createCopyOnConversion = true

    private let createCopyKey = ConversionRouter.createCopyPreferenceKey
    private let extensionEnabledKey = "fc.extensionEnabled"
    private let sharedSuiteName = "group.me.Latorre.Alex.FileConverter"
    private let extensionSuiteName = "me.Latorre.Alex.FileConverter.FinderSync"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Create a copy (keep original file)", isOn: $createCopyOnConversion)
                
                Text(createCopyOnConversion 
                    ? "A converted file is created and the original is kept." 
                    : "The converted file replaces the original (original is deleted).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 4)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("System Dependencies")
                    .font(.subheadline)
                    .bold()
                
                DependencyListView()
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            createCopyOnConversion = loadCreateCopyPreference()
            setExtensionEnabled(true)
        }
        .onChange(of: createCopyOnConversion) { _, newValue in
            saveCreateCopyPreference(newValue)
        }
    }

    private func loadCreateCopyPreference() -> Bool {
        if let shared = UserDefaults(suiteName: sharedSuiteName)?.object(forKey: createCopyKey) as? Bool {
            return shared
        }
        if let domain = extensionDomainValue(forKey: createCopyKey) {
            return domain
        }
        if let ext = UserDefaults(suiteName: extensionSuiteName)?.object(forKey: createCopyKey) as? Bool {
            return ext
        }
        if let local = UserDefaults.standard.object(forKey: createCopyKey) as? Bool {
            return local
        }
        return true
    }

    private func saveCreateCopyPreference(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: createCopyKey)
        UserDefaults.standard.synchronize()

        let sharedDefaults = UserDefaults(suiteName: sharedSuiteName)
        sharedDefaults?.set(value, forKey: createCopyKey)
        sharedDefaults?.synchronize()

        let extensionDefaults = UserDefaults(suiteName: extensionSuiteName)
        extensionDefaults?.set(value, forKey: createCopyKey)
        extensionDefaults?.synchronize()

        let appID = extensionSuiteName as CFString
        CFPreferencesSetAppValue(createCopyKey as CFString, value as CFPropertyList, appID)
        CFPreferencesAppSynchronize(appID)
    }

    private func setExtensionEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: extensionEnabledKey)
        UserDefaults(suiteName: sharedSuiteName)?.set(enabled, forKey: extensionEnabledKey)
        UserDefaults(suiteName: extensionSuiteName)?.set(enabled, forKey: extensionEnabledKey)
        let appID = extensionSuiteName as CFString
        CFPreferencesSetAppValue(extensionEnabledKey as CFString, enabled as CFPropertyList, appID)
        CFPreferencesAppSynchronize(appID)
    }

    private func extensionDomainValue(forKey key: String) -> Bool? {
        let appID = extensionSuiteName as CFString
        return CFPreferencesCopyAppValue(key as CFString, appID) as? Bool
    }
}

struct TutorialView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("How to use File Converter")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                TutorialStep(icon: "mouse", text: "1. Right-click any file in Finder.")
                TutorialStep(icon: "arrow.right.circle", text: "2. Select 'File Converter' from the menu.")
                TutorialStep(icon: "doc.on.doc", text: "3. Choose your desired output format.")
                TutorialStep(icon: "checkmark.seal", text: "4. Done! Your file is converted instantly.")
            }
            
            Spacer()
            
            Text("Tip: You can change if you want to keep the original file in the Settings tab.")
                .font(.caption)
                .italic()
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct TutorialStep: View {
    let icon: String
    let text: String
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 25)
            Text(text)
        }
    }
}

struct DependencyListView: View {
    private let status = DependencyChecker.shared.checkAll()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(status.keys.sorted(), id: \.self) { tool in
                    let ok = status[tool] == true
                    HStack {
                        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(ok ? .green : .red)
                            .imageScale(.small)
                        Text(tool)
                            .font(.system(.caption, design: .monospaced))
                        Spacer()
                    }
                }
            }
        }
        .frame(height: 80)
    }
}
