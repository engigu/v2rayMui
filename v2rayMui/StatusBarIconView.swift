import SwiftUI
import AppKit

struct StatusBarIconView: View {
    @StateObject private var vm = StatusViewModel()
    @State private var statusImage: NSImage? = nil

    var body: some View {
        Image(nsImage: statusImage ?? NSImage(size: NSSize(width: 18, height: 18)))
            .renderingMode(.original)
            .interpolation(.high)
            .antialiased(true)
            .frame(width: 18, height: 18)
            .onAppear { statusImage = buildStatusImage(connected: vm.connected) }
            .onChange(of: vm.connected) { connected in
                statusImage = buildStatusImage(connected: connected)
            }
    }

    private func buildStatusImage(connected: Bool) -> NSImage? {
        let base = ZStack(alignment: .bottomTrailing) {
            Image("StatusBarIcon")
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .foregroundColor(.white)
                .frame(width: 18, height: 18)

            Circle()
                .fill(connected ? Color.green : Color.red)
                .frame(width: 6, height: 6)
                .overlay(Circle().stroke(Color.white.opacity(0.98), lineWidth: 1.0))
                .shadow(color: Color.black.opacity(0.25), radius: 0.4)
                .offset(x: -0.5, y: -0.5)
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            Text("DEV")
                .font(.system(size: 5, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal, 1)
                .padding(.vertical, 0.25)
                .background(Color.yellow.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 1.5, style: .continuous))
                .offset(x: -1, y: 1)
        }
        #endif

        let renderer = ImageRenderer(content: base.frame(width: 18, height: 18))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        if let img = renderer.nsImage {
            img.isTemplate = false
            return img
        }
        return nil
    }
}


