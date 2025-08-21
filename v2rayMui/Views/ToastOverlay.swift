import SwiftUI

struct ToastOverlay: View {
    @ObservedObject var manager = ToastManager.shared
    
    var body: some View {
        ZStack {
            if manager.isShowing {
                VStack {
                    Spacer()
                    HStack {
                        Text(manager.message)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .background(
                        Capsule().fill(manager.style.backgroundColor)
                    )
                    .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(999)
            }
        }
        .allowsHitTesting(false)
    }
}


