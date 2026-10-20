import SwiftUI

struct PerformanceOverlay: View {
    let scene: GameScene

    var body: some View {
        TimelineView(.periodic(from: Date(timeIntervalSinceReferenceDate: 0), by: 0.15)) { _ in
            panel(scene.perfSnapshot)
        }
    }

    private func panel(_ perf: DebugMetricsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                metricPair("FPS", String(format: "%.0f", perf.fps),
                           fpsColor(perf.fps, green: 55, yellow: 45, orange: 30))
                metricPair("FRAME", String(format: "%.1f", perf.frameMs) + "ms",
                           timeColor(perf.frameMs, green: 18, yellow: 22, orange: 34))
            }
            HStack(spacing: 10) {
                metricPair("WORST", String(format: "%.1f", perf.peakMs) + "ms",
                           timeColor(perf.peakMs, green: 20, yellow: 34, orange: 55))
                metricPair("CPU", String(format: "%.1f", perf.cpuMs) + "ms",
                           timeColor(perf.cpuMs, green: 4, yellow: 8, orange: 14))
            }
            HStack(spacing: 10) {
                metricPair("NODES", "\(perf.nodes)",
                           loadColor(perf.nodes, green: 550, yellow: 800, orange: 1200))
                metricPair("DRAWS", "\(perf.draws)",
                           loadColor(perf.draws, green: 180, yellow: 300, orange: 450))
            }
            HStack(spacing: 10) {
                metricPair("CULL", "\(perf.offscreen)", .white.opacity(0.7))
                metricPair("TEX", "\(perf.textures)",
                           loadColor(perf.textures, green: 40, yellow: 80, orange: 140))
            }
            HStack(spacing: 10) {
                metricPair("SHP", "\(perf.shapes)",
                           loadColor(perf.shapes, green: 150, yellow: 300, orange: 500))
                metricPair("PROJ", "\(perf.projectiles)",
                           loadColor(perf.projectiles, green: 25, yellow: 50, orange: 85))
            }
            HStack(spacing: 10) {
                metricPair("UNITS", "\(perf.enemies)/\(perf.allies)",
                           loadColor(perf.enemies + perf.allies,
                                     green: 20, yellow: 32, orange: 44))
                metricPair("HITCH", "\(perf.hitches)/s",
                           loadColor(perf.hitches, green: 0, yellow: 2, orange: 5))
            }
            HStack(spacing: 10) {
                metricPair("MEM", String(format: "%.0f", perf.memoryMB) + "MB",
                           valueColor(perf.memoryMB, green: 250, yellow: 400, orange: 600))
                metricPair("MAX", "\(perf.maxHz)Hz", .white.opacity(0.7))
            }
            Rectangle()
                .fill(.white.opacity(0.14))
                .frame(height: 1)
                .padding(.vertical, 1)
            Text("\(perf.device) · \(perf.os)")
            Text("\(perf.screen) · SCREEN \(perf.maxHz)Hz")
            Text("GPU \(perf.gpu) · \(String(format: "%.0f", perf.ramGB))GB/\(perf.cores)C")
            Text("THERM \(perf.thermal) · LPM \(perf.lowPower ? "ON" : "OFF")")
                .foregroundStyle(perf.lowPower ? .orange
                                 : (perf.thermal == "NOMINAL" ? .green
                                    : perf.thermal == "FAIR" ? .yellow : .red))
        }
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: 236, alignment: .leading)
        .background(.black.opacity(0.74))
        .clipShape(PixelPanelShape(cut: 4))
        .overlay(PixelPanelShape(cut: 4)
            .stroke(perf.fps < 30 ? .red.opacity(0.8) : .white.opacity(0.16),
                    lineWidth: 1))
    }

    private func metricPair(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .monospacedDigit()
                .foregroundStyle(color)
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
}
