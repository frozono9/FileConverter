import SwiftUI
import AppKit

struct OnboardingView: View {
    @State private var currentStep = 0
    let onFinish: () -> Void

    private let extensionSettingsURL = URL(string: "x-apple.systempreferences:com.apple.ExtensionsSettings.ExtensionPickerIsUpdating")
    private let fullDiskAccessURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")

    var body: some View {
        VStack(spacing: 20) {
            if currentStep == 0 {
                StepView(
                    title: "Install in Applications",
                    description: "If you opened FileConverter from a DMG, drag it manually to Applications first. Finder integration only works correctly from /Applications.",
                    imageName: "folder.badge.gearshape",
                    buttonTitle: "Continue"
                ) {
                    withAnimation { currentStep = 1 }
                }
            } else if currentStep == 1 {
                StepView(
                    title: "How It Works",
                    description: "Right-click a supported file in Finder, choose 'Convert to...', and select the output format you want.",
                    imageName: "cursorarrow.click",
                    buttonTitle: "Enable Finder Extension"
                ) {
                    if let extensionSettingsURL {
                        NSWorkspace.shared.open(extensionSettingsURL)
                    }
                    withAnimation { currentStep = 2 }
                }
            } else if currentStep == 2 {
                StepView(
                    title: "Permissions",
                    description: "Enable the FileConverter extension in System Settings > Privacy & Security > Extensions > Finder. If conversion fails in protected folders, grant Full Disk Access.",
                    imageName: "lock.shield",
                    buttonTitle: "Open Privacy Settings"
                ) {
                    if let fullDiskAccessURL {
                        NSWorkspace.shared.open(fullDiskAccessURL)
                    }
                    withAnimation { currentStep = 3 }
                }
            } else {
                StepView(
                    title: "Apply Changes",
                    description: "FileConverter will now restart Finder and relaunch itself so the extension state is refreshed.",
                    imageName: "arrow.clockwise.circle.fill",
                    buttonTitle: "Restart Finder and App"
                ) {
                    onFinish()
                }
            }
        }
        .padding(30)
        .frame(width: 450, height: 350)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea())
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
