import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            if currentStep == 0 {
                StepView(
                    title: "Welcome to convert.io",
                    description: "The simplest way to convert files directly from Finder.",
                    imageName: "arrow.triangle.2.circlepath",
                    buttonTitle: "Continue"
                ) {
                    withAnimation { currentStep = 1 }
                }
            } else if currentStep == 1 {
                StepView(
                    title: "Enable Extension",
                    description: "To use the right-click menu, you need to enable the Finder extension in System Settings.",
                    imageName: "switch.2",
                    buttonTitle: "Open System Settings"
                ) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.ExtensionsSettings.ExtensionPickerIsUpdating")!)
                    withAnimation { currentStep = 2 }
                }
            } else {
                StepView(
                    title: "You're All Set!",
                    description: "Right-click any file in Finder and look for 'Convert to...' to start converting.",
                    imageName: "checkmark.circle.fill",
                    buttonTitle: "Start Using convert.io"
                ) {
                    UserDefaults.standard.set(true, forKey: "fc.hasSeenOnboarding")
                    isPresented = false
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
