import SwiftUI

struct PreferencesView: View {
    private let status = DependencyChecker.shared.checkAll()
    @AppStorage(ConversionRouter.createCopyPreferenceKey) private var createCopyOnConversion = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Conversion Behavior")
                    .font(.title3)
                    .bold()
                Toggle("Create a copy (keep original file)", isOn: $createCopyOnConversion)
                Text(createCopyOnConversion ? "A converted file is created and the original is kept." : "The converted file replaces the original (no copy kept).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Dependencies")
                .font(.title2)
                .bold()

            ForEach(status.keys.sorted(), id: \.self) { tool in
                let ok = status[tool] == true
                HStack {
                    Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(ok ? .green : .red)
                    Text(tool)
                    Spacer()
                    if !ok {
                        Text(DependencyChecker.shared.installHint(for: tool))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 300)
    }
}
