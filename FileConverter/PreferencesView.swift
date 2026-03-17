import SwiftUI
import AppKit

struct PreferencesView: View {
    var body: some View {
        SettingsView()
            .frame(width: 420, height: 220)
    }
}

struct SettingsView: View {
    @State private var createCopyOnConversion = true

    private let createCopyKey = ConversionRouter.createCopyPreferenceKey
    private let extensionEnabledKey = "fc.extensionEnabled"
    private let sharedSuiteName = "group.me.Latorre.Alex.FileConverter"
    private let extensionSuiteName = "me.Latorre.Alex.FileConverter.FinderSync"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Create a copy (keep original file)", isOn: $createCopyOnConversion)
                .toggleStyle(.switch)

            Text(createCopyOnConversion
                ? "A converted file is created and the original is kept."
                : "The converted file replaces the original (original is deleted)."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()
            Divider()

            HStack {
                Spacer()
                Button("Quit convert.io", role: .destructive) {
                    NotificationCenter.default.post(name: .fileConverterQuitRequested, object: nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(16)
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
