//
//  AppEnvironment.swift
//  v2rayMui
//
//  Helpers to detect runtime environment (Xcode/debugger/preview)
//

import Foundation
import Darwin

struct AppEnvironment {
    /// Compile-time debug configuration
    static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Whether the current process is being debugged (e.g., via Xcode/LLDB)
    /// Based on Apple Technical Q&A: "Detecting the Debugger"
    static var isRunningInDebugger: Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let result = mib.withUnsafeMutableBufferPointer { ptr -> Int32 in
            sysctl(ptr.baseAddress, u_int(ptr.count), &info, &size, nil, 0)
        }
        if result != 0 { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    /// True when running a debug build attached to Xcode
    static var isRunningInXcode: Bool {
        return isDebugBuild && isRunningInDebugger
    }

    /// SwiftUI preview canvas
    static var isSwiftUIPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}


