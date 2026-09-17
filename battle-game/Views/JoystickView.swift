import SwiftUI

/// Virtual joystick for hero movement. Lives bottom-left; the stick base appears
/// wherever the thumb lands inside its zone (dynamic origin), and the knob reports:
/// - horizontal deflection -> run (-1...1, with a small deadzone)
/// - push up past threshold -> jump (held = auto-jump on landing)
///
/// Output streams through `moveX` / `jumpHeld` bindings every gesture change.
struct JoystickView: View {
    @Binding var moveX: CGFloat
    @Binding var jumpHeld: Bool

    private let radius: CGFloat = 60
    private let deadzone: CGFloat = 0.15
    private let jumpThreshold: CGFloat = -20 // points of upward deflection

    @State private var origin: CGPoint? = nil
    @State private var knob: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base ring at touch origin.
                if let origin {
                    Circle()
                        .stroke(.white.opacity(0.5), lineWidth: 3)
                        .frame(width: radius * 2, height: radius * 2)
                        .position(origin)
                    // Up-jump hint arrow.
                    Image(systemName: "chevron.up")
                        .foregroundStyle(jumpHeld ? .yellow : .white.opacity(0.4))
                        .position(x: origin.x, y: origin.y - radius - 18)
                    // Knob.
                    Circle()
                        .fill(.white.opacity(0.75))
                        .frame(width: 56, height: 56)
                        .position(x: origin.x + knob.width, y: origin.y + knob.height)
                } else {
                    // Idle hint so players find the stick.
                    Image(systemName: "circle.dotted")
                        .font(.system(size: 54))
                        .foregroundStyle(.white.opacity(0.35))
                        .position(x: 90, y: geo.size.height - 110)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .local)
                    .onChanged { value in
                        if origin == nil { origin = value.startLocation }
                        guard let origin else { return }
                        var dx = value.location.x - origin.x
                        var dy = value.location.y - origin.y
                        let len = max(1, hypot(dx, dy))
                        if len > radius { dx *= radius / len; dy *= radius / len }
                        knob = CGSize(width: dx, height: dy)

                        let rawX = dx / radius
                        // Eased response: rescale past the deadzone, then bend
                        // the curve (gentle near center, full throw at the edge)
                        // so small thumb moves don't slam the hero around.
                        let mag = min(1, abs(rawX))
                        let shaped: CGFloat
                        if mag <= deadzone {
                            shaped = 0
                        } else {
                            let t = (mag - deadzone) / (1 - deadzone)
                            shaped = pow(t, 1.6)
                        }
                        moveX = (rawX >= 0 ? 1 : -1) * shaped
                        jumpHeld = dy < jumpThreshold
                    }
                    .onEnded { _ in
                        origin = nil
                        knob = .zero
                        moveX = 0
                        jumpHeld = false
                    }
            )
        }
    }
}
