import Combine
import QuartzCore
import SwiftUI

struct PerformanceOverlay: View {
    let scene: GameScene
    var onClose: (() -> Void)? = nil
    @StateObject private var display = DisplayRefreshProbe()

    var body: some View {
        TimelineView(.periodic(from: Date(timeIntervalSinceReferenceDate: 0), by: 0.15)) { _ in
            panel(scene.perfSnapshot)
        }
    }

    private func panel(_ perf: DebugMetricsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("DIAGNOSTICS")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.cyan.opacity(0.85))
                Spacer(minLength: 4)
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 26, height: 18)
                            .background(.white.opacity(0.08))
                            .clipShape(PixelPanelShape(cut: 3))
                            .overlay(PixelPanelShape(cut: 3)
                                .stroke(.white.opacity(0.14), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                metricPair("FPS", String(format: "%.0f", perf.fps),
                           fpsColor(perf.fps, green: 55, yellow: 45, orange: 30))
                metricPair("FRAME", String(format: "%.1f", perf.frameMs) + "ms",
                           timeColor(perf.frameMs, green: 18, yellow: 22, orange: 34))
                metricPair("WORST", String(format: "%.1f", perf.peakMs) + "ms",
                           timeColor(perf.peakMs, green: 20, yellow: 34, orange: 55))
                metricPair("CPU", String(format: "%.1f", perf.cpuMs) + "ms",
                           timeColor(perf.cpuMs, green: 4, yellow: 8, orange: 14))
                metricPair("DISP", "\(Int(display.fps))/\(perf.maxHz)",
                           fpsColor(display.fps, green: 55, yellow: 45, orange: 30))
                metricPair("DMAX", String(format: "%.0f", display.worstMs) + "ms",
                           timeColor(display.worstMs, green: 20, yellow: 34, orange: 55))
                metricPair("MEM", String(format: "%.0f", perf.memoryMB) + "MB",
                           valueColor(perf.memoryMB, green: 250, yellow: 400, orange: 600))
                metricPair("HITCH", "\(perf.hitches)/s",
                           loadColor(perf.hitches, green: 0, yellow: 2, orange: 5))
            }

            HStack(spacing: 8) {
                metricPair("NODES", "\(perf.nodes)",
                           loadColor(perf.nodes, green: 550, yellow: 800, orange: 1200))
                metricPair("DRAWS", "\(perf.draws)",
                           loadColor(perf.draws, green: 180, yellow: 300, orange: 450))
                metricPair("CULL", "\(perf.offscreen)", .white.opacity(0.7))
                metricPair("TEX", "\(perf.textures)",
                           loadColor(perf.textures, green: 40, yellow: 80, orange: 140))
                metricPair("SHP", "\(perf.shapes)",
                           loadColor(perf.shapes, green: 150, yellow: 300, orange: 500))
                metricPair("PROJ", "\(perf.projectiles)",
                           loadColor(perf.projectiles, green: 25, yellow: 50, orange: 85))
                metricPair("UNITS", "\(perf.enemies)/\(perf.allies)",
                           loadColor(perf.enemies + perf.allies,
                                     green: 20, yellow: 32, orange: 44))
                metricPair("THRM", perf.thermal, thermalColor(perf.thermal))
            }

            if perf.peakMs > 25 {
                Rectangle()
                    .fill(.orange.opacity(0.28))
                    .frame(height: 1)
                HStack(spacing: 8) {
                    metricPair("WCPU", String(format: "%.1f", perf.worstCPUms) + "ms",
                               timeColor(perf.worstCPUms, green: 4, yellow: 8, orange: 14))
                    metricPair("WDRAW", "\(perf.worstDraws)",
                               loadColor(perf.worstDraws, green: 180, yellow: 300, orange: 450))
                    metricPair("WNODE", "\(perf.worstNodes)",
                               loadColor(perf.worstNodes, green: 550, yellow: 800, orange: 1200))
                    metricPair("WUNIT", "\(perf.worstEnemies)/\(perf.worstAllies)",
                               loadColor(perf.worstEnemies + perf.worstAllies,
                                         green: 20, yellow: 32, orange: 44))
                    metricPair("WPROJ", "\(perf.worstProjectiles)",
                               loadColor(perf.worstProjectiles, green: 25, yellow: 50, orange: 85))
                    metricPair("WTEX", "\(perf.worstTextures)",
                               loadColor(perf.worstTextures, green: 40, yellow: 80, orange: 140))
                    metricPair("WSHP", "\(perf.worstShapes)",
                               loadColor(perf.worstShapes, green: 150, yellow: 300, orange: 500))
                }
            }

            HStack(spacing: 5) {
                Text("\(perf.device) · \(perf.os) · \(perf.screen) · \(perf.maxHz)Hz · GPU \(perf.gpu) · \(String(format: "%.0f", perf.ramGB))GB/\(perf.cores)C")
                    .foregroundStyle(.white.opacity(0.4))
                Text("THERM \(perf.thermal)")
                    .foregroundStyle(thermalColor(perf.thermal))
                Text("LPM \(perf.lowPower ? "ON" : "OFF")")
                    .foregroundStyle(perf.lowPower ? .orange : .white.opacity(0.4))
            }
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
        }
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.86))
        .clipShape(PixelPanelShape(cut: 5))
        .overlay(PixelPanelShape(cut: 5)
            .stroke(perf.fps < 30 ? .red.opacity(0.8) : .cyan.opacity(0.28),
                    lineWidth: 1))
    }

    private func metricPair(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fpsColor(_ fps: Double,
                          green: Double, yellow: Double, orange: Double) -> Color {
        if fps >= green { return .green }
        if fps >= yellow { return .yellow }
        if fps >= orange { return .orange }
        return .red
    }

    private func timeColor(_ ms: Double,
                           green: Double, yellow: Double, orange: Double) -> Color {
        if ms <= green { return .green }
        if ms <= yellow { return .yellow }
        if ms <= orange { return .orange }
        return .red
    }

    private func loadColor(_ value: Int, green: Int, yellow: Int, orange: Int) -> Color {
        if value <= green { return .green }
        if value <= yellow { return .yellow }
        if value <= orange { return .orange }
        return .red
    }

    private func valueColor(_ value: Double,
                            green: Double, yellow: Double, orange: Double) -> Color {
        if value <= green { return .green }
        if value <= yellow { return .yellow }
        if value <= orange { return .orange }
        return .red
    }

    private func thermalColor(_ thermal: String) -> Color {
        if thermal == "NOMINAL" { return .green }
        if thermal == "FAIR" { return .yellow }
        return .red
    }
}

private final class DisplayLinkTarget: NSObject {
    weak var probe: DisplayRefreshProbe?
    @objc func tick(_ link: CADisplayLink) { probe?.tick(link) }
}

private final class DisplayRefreshProbe: ObservableObject {
    @Published private(set) var fps: Double = 0
    @Published private(set) var worstMs: Double = 0
    private var link: CADisplayLink?
    private let target = DisplayLinkTarget()
    private var lastTimestamp: CFTimeInterval = 0
    private var accumulated: CFTimeInterval = 0
    private var frames = 0
    private var worstGap: CFTimeInterval = 0
    private var worstWindow: CFTimeInterval = 0

    init() {
        target.probe = self
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    deinit { link?.invalidate() }

    fileprivate func tick(_ link: CADisplayLink) {
        if lastTimestamp > 0 {
            let dt = link.timestamp - lastTimestamp
            accumulated += dt
            frames += 1
            if dt > worstGap { worstGap = dt }
            worstWindow += dt
            if accumulated >= 0.25 {
                fps = Double(frames) / accumulated
                accumulated = 0
                frames = 0
            }
            if worstWindow >= 5 {
                worstMs = worstGap * 1000
                worstGap = 0
                worstWindow = 0
            }
        }
        lastTimestamp = link.timestamp
    }
}
