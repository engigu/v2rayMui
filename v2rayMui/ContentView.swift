import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            MainView()
            ToastOverlay()
        }
            .frame(width: 1000, height: 750)
            .fixedSize()
    }
}

