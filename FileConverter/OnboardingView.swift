import SwiftUI
import AppKit

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var isInstallingDeps = false
    @State private var installMessage = ""
    let onFinish: () -> Void

    private let extensionSettingsURL = URL(string: "x-apple.systempreferences:com.apple.ExtensionsSettings.ExtensionPickerIsUpdating")
    private let fullDiskAccessURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")

    var body: some View {
        VStack(spacing: 20) {
            if currentStep == 0 {
                StepView(
                    title: "Install in Applications",
                    description: "Drag FileConverter to your Applications folder. This ensures Finder integration works reliably.",
                    imageName: "folder.badge.gearshape",
                    buttonTitle: "Continue"
                ) {
                    withAnimation { currentStep = 1 }
                }
            } else if currentStep == 1 {
                if isInstallingDeps {
                    VStack(spacing: 15) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Setting up conversion tools...")
                            .font(.headline)
                        Text(installMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .padding(30)
                } else {
                    StepView(
                        title: "Install Conversion Tools",
                        description: "FileConverter needs a few tools (ffmpeg, pandoc, ImageMagick). One click and we handle it automatically.",
                        imageName: "gearshape",
                        buttonTitle: "Install Now"
                    ) {
                        isInstallingDeps = true
                        Task {
                            await installConversionTools { message in
                                installMessage = message
                            }
                            withAnimation { currentStep = 2 }
                        }
                    }
                }
            } else if currentStep == 2 {
                StepView(
                    title: "Enable Finder Extension",
                    description: "Right-click any file in Finder and choose 'Convert to...' to start converting.",
                    imageName: "cursorarrow.click",
                    buttonTitle: "Open Settings"
                ) {
                    if let extensionSettingsURL {
                        NSWorkspace.shared.open(extensionSettingsURL)
                    }
                    withAnimation { currentStep = 3 }
                }
            } else if currentStep == 3 {
                StepView(
                    title: "Grant Permissions",
                    description: "Enable the FileConverter extension in System Settings. If conversions fail in protected folders, grant Full Disk Access.",
                    imageName: "lock.shield",
                    buttonTitle: "Open Privacy Settings"
                ) {
                    if let fullDiskAccessURL {
                        NSWorkspace.shared.open(fullDiskAccessURL)
                    }
                    withAnimation { currentStep = 4 }
                }
            } else {
                StepView(
                    title: "All Set",
                    description: "FileConverter will restart Finder to enable the extension.",
                    imageName: "arrow.clockwise.circle.fill",
                    buttonTitle: "Complete Setup"
                ) {
                    onFinish()
                }
            }
        }
        .padding(30)
        .frame(width: 450, height: 350)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea())
    }

    private func installConversionTools(statusUpdate: @escaping (String) -> Void) async {
        let tools = ["ffmpeg", "pandoc", "imagemagick", "tesseract", "poppler", "potrace"]
        
        for tool in tools {
            statusUpdate("Installing \(tool)...")
            do {
                _ = try await Shell.run(["brew", "install", tool])
                statusUpdate("\(tool) ✓")
            } catch {
                statusUpdate("\(tool) ✗ (continuing...)")
            }
        }
        
        statusUpdate("Installing LibreOffice...")
        do {
            _ = try await Shell.run(["brew", "install", "--cask", "libreoffice"])
        } catch {
            statusUpdate("LibreOffice install had issues (continuing...)")
        }
        
        statusUpdate("Installing Python packages...")
        do {
            _ = try await Shell.run(["pip3", "install", "pandas", "openpyxl", "pyarrow"])
        } catch {
            statusUpdate("Python packages (some may be missing)")
        }
        
        statusUpdate("Setup complete!")
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
}

struct StepView: View {
    let title: String
    let description: String
    let imageName: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: imageName)
                .font(.system(size: 60))
                .foregroundStyle(.blue)
                .padding(.bottom, 10)

            Text(title)
                .font(.title)
                .fontWeight(.bold)

            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()

            Button(action: action) {
                Text(buttonTitle)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
