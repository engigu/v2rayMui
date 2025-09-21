import SwiftUI

struct StatusBarIconView: View {
    @StateObject private var vm = StatusViewModel()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image("StatusBarIcon")
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: 18, height: 18)

            Circle()
                .fill(vm.connected ? Color.green : Color.red)
                .frame(width: 7, height: 7)
                .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 1))
                .offset(x: -0.5, y: -0.5)
        }
    }
}


