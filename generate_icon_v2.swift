import SwiftUI
import AppKit

struct AppIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 160, style: .continuous)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.9), Color.gray.opacity(0.1)]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 160, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
            
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.white, Color.black.opacity(0.1))
                .padding(180)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 10)
        }
        .frame(width: 1024, height: 1024)
    }
}

let view = AppIconView()
let hosting = NSHostingView(rootView: view)
hosting.frame = CGRect(x: 0, y: 0, width: 1024, height: 1024)

let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)!
hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
let data = bitmap.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: "AppIcon_Generated.png"))
print("ICON_GENERATED")
