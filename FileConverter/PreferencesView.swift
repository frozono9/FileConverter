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
    @AppStorage(ConversionRouter.createCopyPreferenceKey, store: UserDefaults(suiteName: "group.me.Latorre.Alex.FileConverter")) 
    private var createCopyOnConversion = true

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
