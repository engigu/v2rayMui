//
//  ToastManager.swift
//  v2rayMui
//
//  Created by Assistant on 2025/8/21.
//

import Foundation
import SwiftUI

enum ToastStyle {
    case info
    case success
    case warning
    case error
    
    var backgroundColor: Color {
        switch self {
        case .info: return Color.black.opacity(0.8)
        case .success: return Color.green.opacity(0.85)
        case .warning: return Color.orange.opacity(0.9)
        case .error: return Color.red.opacity(0.9)
        }
    }
}

class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var isShowing: Bool = false
    @Published var message: String = ""
    @Published var style: ToastStyle = .info
    
    private var hideWorkItem: DispatchWorkItem?
    
    func show(_ message: String, style: ToastStyle = .info, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async {
            self.hideWorkItem?.cancel()
            self.message = message
            self.style = style
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9, blendDuration: 0.2)) {
                self.isShowing = true
            }
            let workItem = DispatchWorkItem { [weak self] in
                withAnimation(.easeOut(duration: 0.2)) {
                    self?.isShowing = false
                }
            }
            self.hideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
        }
    }
}


