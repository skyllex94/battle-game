import Darwin
import Foundation
import Metal
import UIKit

struct DebugMetricsSnapshot: Equatable {
    var fps: Double = 0
    var frameMs: Double = 0
    var peakMs: Double = 0
    var cpuMs: Double = 0
    var nodes: Int = 0
    var draws: Int = 0
    var offscreen: Int = 0
    var textures: Int = 0
    var shapes: Int = 0
    var projectiles: Int = 0
    var enemies: Int = 0
    var allies: Int = 0
    var hitches: Int = 0
    var memoryMB: Double = 0
    var thermal: String = "?"
    var lowPower: Bool = false
    var device: String = ""
    var os: String = ""
    var screen: String = ""
    var gpu: String = ""
    var ramGB: Double = 0
    var cores: Int = 0
    var maxHz: Int = 0
}

enum DebugDeviceInfo {
    static let identifier: String = {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }()

    static let device: String = {
        let names: [String: String] = [
            "iPhone14,2": "13 Pro", "iPhone14,3": "13 Pro Max",
            "iPhone14,4": "13 mini", "iPhone14,5": "13",
            "iPhone14,6": "SE 3", "iPhone14,7": "14", "iPhone14,8": "14 Plus",
            "iPhone15,2": "14 Pro", "iPhone15,3": "14 Pro Max",
            "iPhone15,4": "14", "iPhone15,5": "14 Plus",
            "iPhone16,1": "15 Pro", "iPhone16,2": "15 Pro Max",
            "iPhone16,3": "15", "iPhone16,4": "15 Plus",
            "iPhone17,1": "16 Pro", "iPhone17,2": "16 Pro Max",
            "iPhone17,3": "16", "iPhone17,4": "16 Plus", "iPhone17,5": "16e",
            "iPhone18,1": "17 Pro", "iPhone18,2": "17 Pro Max",
            "iPhone18,3": "17", "iPhone18,4": "17 Air",
        ]
        if let name = names[identifier] { return "iPhone \(name)" }
        return identifier
    }()

    static let os = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"

    static let screen: String = {
        let native = UIScreen.main.nativeBounds.size
        let scale = UIScreen.main.nativeScale
        return "\(Int(native.width))x\(Int(native.height)) @\(String(format: "%.1g", scale))x"
    }()

    static let maxHz = UIScreen.main.maximumFramesPerSecond

    static let gpu = MTLCreateSystemDefaultDevice()?.name ?? "?"

    static let ramGB = Double(ProcessInfo.processInfo.physicalMemory)
        / 1024 / 1024 / 1024

    static let cores = ProcessInfo.processInfo.activeProcessorCount

    static var thermal: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "NOMINAL"
        case .fair: return "FAIR"
        case .serious: return "SERIOUS"
        case .critical: return "CRITICAL"
        @unknown default: return "?"
        }
    }

    static var lowPower: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1024 / 1024
    }
}
