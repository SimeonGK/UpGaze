import SwiftUI

/// Animated side-profile scene of chair, sit-stand desk, monitor and figure for the setup wizard.
struct ErgonomicAnimationView: View {
    let userHeightCm: Double
    let activeStep: ErgonomicStep

    @Environment(\.colorScheme) private var colorScheme
    @Localized private var l10n
    @State private var standingOverride: Bool?
    @State private var rewound = true
    @State private var replayTask: Task<Void, Never>?

    private static let spring = Animation.spring(response: 0.65, dampingFraction: 0.8)

    private var isStanding: Bool {
        standingOverride ?? (activeStep == .standingDesk)
    }

    var body: some View {
        ErgonomicSceneCanvas(
            state: .target(step: activeStep, standing: isStanding, rewound: rewound, heightCm: userHeightCm),
            measurements: ErgonomicMeasurements(userHeightCm: userHeightCm),
            l10n: l10n,
            dark: colorScheme == .dark
        )
        .animation(Self.spring, value: activeStep)
        .accessibilityLabel(l10n.sceneAccessibility(l10n.stepTitle(activeStep)))
        .overlay(alignment: .bottom) { controls }
        .background(.quaternary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { play(after: .milliseconds(300)) }
        .onDisappear { replayTask?.cancel() }
        .onChange(of: activeStep) {
            replayTask?.cancel()
            withAnimation(Self.spring) {
                standingOverride = nil
                rewound = false
            }
        }
    }

    private var controls: some View {
        HStack {
            Button(action: replay) {
                Label(l10n.replayAnimation, systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(ScenePillStyle(active: false))

            Spacer(minLength: 4)

            Button(action: togglePosture) {
                Label(l10n.posturePreview, systemImage: isStanding ? "figure.stand" : "figure.seated.side")
            }
            .buttonStyle(ScenePillStyle(active: standingOverride != nil))
            .help(isStanding ? l10n.showSittingPosture : l10n.showStandingPosture)
        }
        .font(.system(size: 9.5, weight: .medium))
        .padding(6)
    }

    private func replay() {
        withAnimation(.easeInOut(duration: 0.3)) { rewound = true }
        play(after: .milliseconds(450))
    }

    private func play(after delay: Duration) {
        replayTask?.cancel()
        replayTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            withAnimation(Self.spring) { rewound = false }
        }
    }

    private func togglePosture() {
        replayTask?.cancel()
        let standing = !isStanding
        withAnimation(Self.spring) {
            rewound = false
            standingOverride = standing == (activeStep == .standingDesk) ? nil : standing
        }
    }
}

private struct ScenePillStyle: ButtonStyle {
    let active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .foregroundStyle(active ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
            .background(
                active ? AnyShapeStyle(Color.accentColor.opacity(0.18)) : AnyShapeStyle(.quaternary),
                in: Capsule()
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Capsule())
    }
}

/// Everything the scene animates, packed in one vector so a single spring drives all of it.
/// Lengths are in centimetres, the recline in degrees, weights run from 0 to 1.
struct ErgonomicSceneState: VectorArithmetic {
    private var v = SIMD16<Double>()

    var height: Double { get { v[0] } set { v[0] = newValue } }
    var sit: Double { get { v[1] } set { v[1] = newValue } }
    var recline: Double { get { v[2] } set { v[2] = newValue } }
    var deskHeight: Double { get { v[3] } set { v[3] = newValue } }
    var monitorTop: Double { get { v[4] } set { v[4] = newValue } }
    var chairSlide: Double { get { v[5] } set { v[5] = newValue } }
    var chairHighlight: Double { get { v[6] } set { v[6] = newValue } }
    var deskHighlight: Double { get { v[7] } set { v[7] = newValue } }
    var monitorHighlight: Double { get { v[8] } set { v[8] = newValue } }
    var chairCallouts: Double { get { v[9] } set { v[9] = newValue } }
    var sittingCallouts: Double { get { v[10] } set { v[10] = newValue } }
    var standingCallouts: Double { get { v[11] } set { v[11] = newValue } }
    var monitorCallouts: Double { get { v[12] } set { v[12] = newValue } }

    static var zero: Self { Self() }

    static func + (lhs: Self, rhs: Self) -> Self {
        var result = lhs
        result.v += rhs.v
        return result
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        var result = lhs
        result.v -= rhs.v
        return result
    }

    mutating func scale(by rhs: Double) {
        v *= rhs
    }

    var magnitudeSquared: Double {
        (v * v).sum()
    }

    /// `rewound` is the state each step animates from when it is replayed.
    static func target(step: ErgonomicStep, standing: Bool, rewound: Bool, heightCm h: Double) -> Self {
        let isStanding = standing && !(rewound && step == .standingDesk)
        let deskAdjusted = step != .chair && !(step == .sittingDesk && rewound)
        let monitorAligned = step == .monitor && !rewound

        var state = Self()
        state.height = h
        state.sit = isStanding ? 0 : 1
        state.recline = step == .chair && rewound ? 0 : 15
        state.deskHeight = isStanding ? 0.60 * h : 0.41 * h + (deskAdjusted ? 0 : 7)
        state.monitorTop = FigurePose(state: state).eye.y - (monitorAligned ? 0 : 10)
        state.chairSlide = isStanding ? 28 : 0
        state.chairHighlight = step == .chair ? 1 : 0
        state.deskHighlight = step == .sittingDesk || step == .standingDesk ? 1 : 0
        state.monitorHighlight = step == .monitor ? 1 : 0

        if !rewound {
            switch step {
            case .chair:
                state.chairCallouts = isStanding ? 0 : 1
            case .sittingDesk, .standingDesk:
                if isStanding {
                    state.standingCallouts = 1
                } else {
                    state.sittingCallouts = 1
                }
            case .monitor:
                state.monitorCallouts = 1
            }
        }
        return state
    }
}

/// Joint positions in centimetres; origin on the floor under the seated hip, x towards the desk.
struct FigurePose {
    let hip: CGPoint
    let knee: CGPoint
    let ankle: CGPoint
    let shoulder: CGPoint
    let elbow: CGPoint
    let hand: CGPoint
    let head: CGPoint
    let eye: CGPoint
    let headRadius: Double

    init(state: ErgonomicSceneState, breath: Double = 0) {
        let h = state.height
        let sit = state.sit
        let lean = sit * state.recline * 0.9 * .pi / 180
        let lift = breath * 0.7

        func mix(_ standing: Double, _ sitting: Double) -> Double {
            (standing + (sitting - standing) * sit) * h
        }

        hip = CGPoint(x: mix(-0.04, 0), y: mix(0.528, 0.305))
        ankle = CGPoint(x: mix(-0.03, 0.25), y: 0.04 * h)
        knee = Self.joint(from: hip, to: ankle, 0.245 * h, 0.245 * h, bend: 1).joint

        shoulder = CGPoint(x: hip.x - 0.29 * h * sin(lean), y: hip.y + 0.29 * h * cos(lean) + lift)
        let keyboard = CGPoint(x: 0.115 * h, y: state.deskHeight + 0.025 * h)
        let arm = Self.joint(from: shoulder, to: keyboard, 0.18 * h, 0.16 * h, bend: -1)
        elbow = arm.joint
        hand = arm.end

        head = CGPoint(x: shoulder.x + 0.012 * h, y: shoulder.y + 0.108 * h + lift * 0.3)
        eye = CGPoint(x: head.x + 0.036 * h, y: head.y + 0.008 * h)
        headRadius = 0.058 * h
    }

    /// Two-bone inverse kinematics; `end` is the target pulled back within reach.
    private static func joint(
        from a: CGPoint, to b: CGPoint, _ l1: Double, _ l2: Double, bend: Double
    ) -> (joint: CGPoint, end: CGPoint) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let distance = max(hypot(dx, dy), 0.001)
        let ux = dx / distance
        let uy = dy / distance
        let reach = min(distance, l1 + l2 - 0.001)
        let along = (l1 * l1 - l2 * l2 + reach * reach) / (2 * reach)
        let offset = (max(l1 * l1 - along * along, 0)).squareRoot() * bend
        return (
            CGPoint(x: a.x + ux * along - uy * offset, y: a.y + uy * along + ux * offset),
            CGPoint(x: a.x + ux * reach, y: a.y + uy * reach)
        )
    }
}

struct ErgonomicSceneCanvas: View, Animatable {
    var state: ErgonomicSceneState
    let measurements: ErgonomicMeasurements
    let l10n: L10n
    let dark: Bool

    nonisolated var animatableData: ErgonomicSceneState {
        get { state }
        set { state = newValue }
    }

    var body: some View {
        // The timeline only runs while standing, where it drives the breathing motion.
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: state.sit > 0.5)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let breath = sin(seconds * 2 * .pi / 4.2) * max(1 - state.sit, 0)
            Canvas { context, size in
                ScenePainter(
                    context: context,
                    size: size,
                    state: state,
                    pose: FigurePose(state: state, breath: breath),
                    measurements: measurements,
                    l10n: l10n,
                    dark: dark
                ).draw()
            }
        }
    }
}

// MARK: - Shapes

/// Arc around the rect's centre; angles are counter-clockwise from the positive x-axis.
private struct AngleArc: Shape {
    var start: Double
    var end: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let segments = max(Int(abs(end - start) / 4), 2)
        for index in 0...segments {
            let angle = (start + (end - start) * Double(index) / Double(segments)) * .pi / 180
            let point = CGPoint(x: rect.midX + radius * cos(angle), y: rect.midY - radius * sin(angle))
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

/// Line with an arrowhead at both ends, along the given axis of the rect.
private struct DimensionArrow: Shape {
    var axis: Axis
    var head: CGFloat = 4

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let vertical = axis == .vertical
        let a = vertical ? CGPoint(x: rect.midX, y: rect.minY) : CGPoint(x: rect.minX, y: rect.midY)
        let b = vertical ? CGPoint(x: rect.midX, y: rect.maxY) : CGPoint(x: rect.maxX, y: rect.midY)
        let size = min(head, hypot(b.x - a.x, b.y - a.y) / 3)

        path.move(to: a)
        path.addLine(to: b)
        for (tip, sign) in [(a, 1.0), (b, -1.0)] {
            if vertical {
                path.move(to: CGPoint(x: tip.x - size * 0.6, y: tip.y + sign * size))
                path.addLine(to: tip)
                path.addLine(to: CGPoint(x: tip.x + size * 0.6, y: tip.y + sign * size))
            } else {
                path.move(to: CGPoint(x: tip.x + sign * size, y: tip.y - size * 0.6))
                path.addLine(to: tip)
                path.addLine(to: CGPoint(x: tip.x + sign * size, y: tip.y + size * 0.6))
            }
        }
        return path
    }
}

/// Lumbar pad: flat against the rect's left edge, bulging to its right edge.
private struct LumbarCurve: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control1: CGPoint(x: rect.minX + rect.width * 1.35, y: rect.minY + rect.height * 0.2),
            control2: CGPoint(x: rect.minX + rect.width * 1.35, y: rect.minY + rect.height * 0.8)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Drawing

private struct ScenePainter {
    var context: GraphicsContext
    let size: CGSize
    let state: ErgonomicSceneState
    let pose: FigurePose
    let measurements: ErgonomicMeasurements
    let l10n: L10n

    private let scale: Double
    private let origin: CGPoint
    private let figure: Color
    private let furniture: Color
    private let detail: Color
    private let guide = Color.secondary.opacity(0.55)
    private let accent = Color.accentColor

    private var h: Double { state.height }
    private var chairX: Double { 0.03 * h - state.chairSlide }
    private var seatTop: Double { 0.265 * h }
    private var deskFront: Double { 0.07 * h }
    private var monitorX: Double { deskFront + 50 }

    private var backrestPivot: CGPoint { CGPoint(x: chairX - 0.13 * h, y: seatTop + 0.01 * h) }
    private var backrestDirection: CGPoint {
        let angle = state.recline * .pi / 180
        return CGPoint(x: -sin(angle), y: cos(angle))
    }

    init(
        context: GraphicsContext, size: CGSize, state: ErgonomicSceneState,
        pose: FigurePose, measurements: ErgonomicMeasurements, l10n: L10n, dark: Bool
    ) {
        self.context = context
        self.size = size
        self.state = state
        self.pose = pose
        self.measurements = measurements
        self.l10n = l10n
        // 240 cm of headroom fits a standing 215 cm figure plus the arm's-length callout above it.
        scale = min((size.height - 38) / 240, size.width / 225)
        origin = CGPoint(x: size.width * 0.45, y: size.height - 30)
        figure = dark ? Color(white: 0.9) : Color(white: 0.22)
        furniture = dark ? Color(white: 0.42) : Color(white: 0.68)
        detail = dark ? Color(white: 0.58) : Color(white: 0.52)
    }

    func draw() {
        drawFloor()
        drawDesk()
        drawChair()
        drawFigure()
        drawChairCallouts()
        drawDeskCallouts()
        drawMonitorCallouts()
    }

    // MARK: Geometry helpers

    private func point(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: origin.x + x * scale, y: origin.y - y * scale)
    }

    private func point(_ p: CGPoint) -> CGPoint {
        point(p.x, p.y)
    }

    private func box(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, radius: Double = 0) -> Path {
        let rect = CGRect(
            x: origin.x + x0 * scale, y: origin.y - y1 * scale,
            width: (x1 - x0) * scale, height: (y1 - y0) * scale
        )
        return Path(roundedRect: rect, cornerRadius: radius * scale)
    }

    private func polyline(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points.map { point($0) })
        return path
    }

    private func circle(_ center: CGPoint, radius: Double) -> Path {
        let c = point(center)
        let r = radius * scale
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    private func arc(center: CGPoint, radius: Double, from start: Double, to end: Double) -> Path {
        let c = point(center)
        let r = radius * scale
        return AngleArc(start: start, end: end)
            .path(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    private func degrees(from a: CGPoint, to b: CGPoint) -> Double {
        atan2(b.y - a.y, b.x - a.x) * 180 / .pi
    }

    private func fill(_ path: Path, _ color: Color, accent weight: Double = 0) {
        context.fill(path, with: .color(color))
        if weight > 0.001 {
            context.fill(path, with: .color(accent.opacity(min(weight, 1))))
        }
    }

    private func stroke(_ path: Path, _ color: Color, width: Double, accent weight: Double = 0) {
        let style = StrokeStyle(lineWidth: width * scale, lineCap: .round, lineJoin: .round)
        context.stroke(path, with: .color(color), style: style)
        if weight > 0.001 {
            context.stroke(path, with: .color(accent.opacity(min(weight, 1))), style: style)
        }
    }

    private func badge(_ text: String, at center: CGPoint, opacity: Double) {
        guard opacity > 0.01 else { return }
        var layer = context
        layer.opacity = min(opacity, 1)
        let label = layer.resolve(
            Text(text)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        )
        let textSize = label.measure(in: CGSize(width: 400, height: 40))
        let rect = CGRect(
            x: center.x - textSize.width / 2 - 5, y: center.y - textSize.height / 2 - 2,
            width: textSize.width + 10, height: textSize.height + 4
        )
        layer.fill(Capsule().path(in: rect), with: .color(accent))
        layer.draw(label, at: center)
    }

    private func dimension(from a: CGPoint, to b: CGPoint, axis: Axis, opacity: Double) {
        guard opacity > 0.01 else { return }
        var layer = context
        layer.opacity = min(opacity, 1)
        let p0 = point(a)
        let p1 = point(b)
        let rect = CGRect(
            x: min(p0.x, p1.x) - (axis == .vertical ? 4 : 0),
            y: min(p0.y, p1.y) - (axis == .vertical ? 0 : 4),
            width: abs(p1.x - p0.x) + (axis == .vertical ? 8 : 0),
            height: abs(p1.y - p0.y) + (axis == .vertical ? 0 : 8)
        )
        layer.stroke(
            DimensionArrow(axis: axis).path(in: rect), with: .color(accent),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
        )
    }

    private func thinLine(_ points: [CGPoint], opacity: Double, dash: [CGFloat] = []) {
        guard opacity > 0.01 else { return }
        var layer = context
        layer.opacity = min(opacity, 1)
        layer.stroke(
            polyline(points), with: .color(accent),
            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: dash)
        )
    }

    // MARK: Scene

    private func drawFloor() {
        var floor = Path()
        floor.move(to: CGPoint(x: 8, y: origin.y))
        floor.addLine(to: CGPoint(x: size.width - 8, y: origin.y))
        context.stroke(floor, with: .color(guide), lineWidth: 1)

        let rulerX = 12.0
        var ticks = Path()
        ticks.move(to: CGPoint(x: rulerX, y: origin.y))
        ticks.addLine(to: CGPoint(x: rulerX, y: origin.y - 220 * scale))
        for cm in stride(from: 10, through: 220, by: 10) {
            let y = origin.y - Double(cm) * scale
            let major = cm % 50 == 0
            ticks.move(to: CGPoint(x: rulerX, y: y))
            ticks.addLine(to: CGPoint(x: rulerX + (major ? 6 : 3), y: y))
            if major {
                context.draw(
                    Text("\(cm)").font(.system(size: 7)).foregroundStyle(.secondary),
                    at: CGPoint(x: rulerX + 9, y: y), anchor: .leading
                )
            }
        }
        context.stroke(ticks, with: .color(guide.opacity(0.6)), lineWidth: 0.75)
    }

    private func drawDesk() {
        let top = state.deskHeight
        let legX = deskFront + 46

        fill(box(legX - 2.5, 3, legX + 2.5, top - 3), detail)
        fill(box(legX - 4, 3, legX + 4, min(top - 3, 50), radius: 1), furniture)
        fill(box(legX - 26, 0, legX + 26, 3, radius: 1.2), furniture)

        let post = monitorX + 4.5
        fill(box(monitorX - 6, top, monitorX + 14, top + 1.5, radius: 0.7), detail)
        fill(box(post, top, post + 2.5, state.monitorTop - 8), detail)
        fill(box(monitorX + 3, state.monitorTop - 17, post + 1, state.monitorTop - 13), detail)
        fill(
            box(monitorX, state.monitorTop - 28, monitorX + 3.5, state.monitorTop, radius: 1.2),
            furniture, accent: state.monitorHighlight
        )

        fill(box(deskFront + 3, top, deskFront + 21, top + 1.5, radius: 0.6), detail)
        fill(box(deskFront + 25, top, deskFront + 31, top + 2.4, radius: 1.2), detail)
        fill(box(deskFront, top - 3, deskFront + 78, top, radius: 1), furniture, accent: state.deskHighlight)
    }

    private func drawChair() {
        let highlight = state.chairHighlight
        let pivot = backrestPivot
        let dir = backrestDirection
        let normal = CGPoint(x: dir.y, y: -dir.x)

        fill(circle(CGPoint(x: chairX - 25, y: 2.5), radius: 2.5), detail)
        fill(circle(CGPoint(x: chairX + 25, y: 2.5), radius: 2.5), detail)
        fill(box(chairX - 27, 4.5, chairX + 27, 7.5, radius: 1.5), furniture, accent: highlight)
        fill(box(chairX - 1.8, seatTop - 14, chairX + 1.8, seatTop - 5), detail)
        fill(box(chairX - 3.2, 7.5, chairX + 3.2, seatTop - 13, radius: 0.8), furniture, accent: highlight)

        let bracket = polyline([
            CGPoint(x: chairX - 0.10 * h, y: seatTop - 2.5),
            CGPoint(x: pivot.x, y: seatTop - 2.5),
            CGPoint(x: pivot.x + dir.x * 0.06 * h, y: pivot.y + dir.y * 0.06 * h),
        ])
        stroke(bracket, detail, width: 2.4)

        let backrest = polyline([
            CGPoint(x: pivot.x + dir.x * 0.05 * h, y: pivot.y + dir.y * 0.05 * h),
            CGPoint(x: pivot.x + dir.x * 0.34 * h, y: pivot.y + dir.y * 0.34 * h),
        ])
        stroke(backrest, furniture, width: 4.5, accent: highlight)
        fill(box(chairX - 0.135 * h, seatTop - 5, chairX + 0.135 * h, seatTop, radius: 2.5), furniture, accent: highlight)

        // Local x runs along the backrest normal, local y up the backrest, both in centimetres.
        let base = point(
            pivot.x + dir.x * 0.07 * h + normal.x * 1.6,
            pivot.y + dir.y * 0.07 * h + normal.y * 1.6
        )
        let transform = CGAffineTransform(
            a: scale * normal.x, b: -scale * normal.y,
            c: scale * dir.x, d: -scale * dir.y,
            tx: base.x, ty: base.y
        )
        let lumbar = LumbarCurve()
            .path(in: CGRect(x: 0, y: 0, width: 0.028 * h, height: 0.14 * h))
            .applying(transform)
        fill(lumbar, detail, accent: highlight)
    }

    private func drawFigure() {
        context.drawLayer { layer in
            var painter = self
            painter.context = layer
            painter.drawFigureParts()
        }
    }

    private mutating func drawFigureParts() {
        let torso = polyline([pose.hip, pose.shoulder])
        let arm = polyline([pose.shoulder, pose.elbow, pose.hand])
        let heel = CGPoint(x: pose.ankle.x - 0.02 * h, y: 0.02 * h)
        let toe = CGPoint(x: pose.ankle.x + 0.13 * h, y: 0.02 * h)

        stroke(polyline([heel, toe]), figure, width: 0.04 * h)
        stroke(polyline([pose.hip, pose.knee, pose.ankle]), figure, width: 0.075 * h)
        stroke(polyline([pose.shoulder, pose.head]), figure, width: 0.04 * h)
        stroke(torso, figure, width: 0.105 * h)
        fill(circle(pose.head, radius: pose.headRadius), figure)

        let lowerBackWeight = state.chairHighlight * state.sit
        if lowerBackWeight > 0.001 {
            let from = CGPoint(
                x: pose.hip.x + (pose.shoulder.x - pose.hip.x) * 0.1,
                y: pose.hip.y + (pose.shoulder.y - pose.hip.y) * 0.1
            )
            let to = CGPoint(
                x: pose.hip.x + (pose.shoulder.x - pose.hip.x) * 0.45,
                y: pose.hip.y + (pose.shoulder.y - pose.hip.y) * 0.45
            )
            stroke(polyline([from, to]), accent.opacity(min(lowerBackWeight, 1)), width: 0.105 * h)
        }

        // Cutting a gap around the arm keeps it readable against the torso of the same colour.
        context.blendMode = .destinationOut
        context.stroke(
            arm, with: .color(.black),
            style: StrokeStyle(lineWidth: 0.055 * h * scale + 2.4, lineCap: .round, lineJoin: .round)
        )
        context.fill(circle(pose.eye, radius: 0.011 * h), with: .color(.black))
        context.blendMode = .normal

        stroke(arm, figure, width: 0.055 * h, accent: state.deskHighlight)
        fill(circle(pose.hand, radius: 0.03 * h), figure, accent: state.deskHighlight)
        if state.monitorHighlight > 0.001 {
            fill(circle(pose.eye, radius: 0.011 * h), accent.opacity(min(state.monitorHighlight, 1)))
        }
    }

    // MARK: Callouts

    private func drawChairCallouts() {
        let weight = state.chairCallouts
        guard weight > 0.01 else { return }
        let pivot = backrestPivot

        let backrestArc = arc(center: pivot, radius: 0.1 * h, from: 0, to: 90 + state.recline)
        var glow = context
        glow.opacity = min(weight, 1) * 0.8
        glow.addFilter(.blur(radius: 3))
        glow.stroke(backrestArc, with: .color(accent), lineWidth: 4)
        var crisp = context
        crisp.opacity = min(weight, 1)
        crisp.stroke(backrestArc, with: .color(.white), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        let dir = backrestDirection
        let backrestEdge = point(pivot.x + dir.x * 0.19 * h - 2.25, pivot.y + dir.y * 0.19 * h)
        badge("100°–110°", at: CGPoint(x: backrestEdge.x - 34, y: backrestEdge.y), opacity: weight)

        let start = degrees(from: pose.knee, to: pose.hip)
        var end = degrees(from: pose.knee, to: pose.ankle)
        if end < start { end += 360 }
        let kneeArc = arc(center: pose.knee, radius: 0.085 * h, from: start, to: end)
        crisp.stroke(kneeArc, with: .color(accent), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        let kneeBadge = point(pose.knee.x - 0.2 * h, pose.knee.y - 0.14 * h)
        badge("90°–100°", at: kneeBadge, opacity: weight)

        // Badges have a fixed point size, so the gap between them is set in points, not centimetres.
        let x = (kneeBadge.x - 50 - origin.x) / scale
        thinLine([CGPoint(x: chairX - 0.135 * h, y: seatTop), CGPoint(x: x - 2, y: seatTop)], opacity: weight * 0.7)
        dimension(from: CGPoint(x: x, y: 0), to: CGPoint(x: x, y: seatTop), axis: .vertical, opacity: weight)
        badge(l10n.centimetres(measurements.seatHeight), at: point(x, seatTop / 2), opacity: weight)
    }

    private func drawDeskCallouts() {
        let weight = min(state.sittingCallouts + state.standingCallouts, 1)
        guard weight > 0.01 else { return }
        let value = state.standingCallouts > state.sittingCallouts
            ? measurements.standingDeskHeight
            : measurements.sittingDeskHeight

        func unit(_ target: CGPoint) -> CGPoint {
            let dx = target.x - pose.elbow.x
            let dy = target.y - pose.elbow.y
            let length = max(hypot(dx, dy), 0.001)
            return CGPoint(x: dx / length, y: dy / length)
        }
        let up = unit(pose.shoulder)
        let forward = unit(pose.hand)
        let side = 0.04 * h
        let corner = polyline([
            CGPoint(x: pose.elbow.x + up.x * side, y: pose.elbow.y + up.y * side),
            CGPoint(x: pose.elbow.x + (up.x + forward.x) * side, y: pose.elbow.y + (up.y + forward.y) * side),
            CGPoint(x: pose.elbow.x + forward.x * side, y: pose.elbow.y + forward.y * side),
        ])
        var marker = context
        marker.opacity = weight
        marker.stroke(corner, with: .color(.white), style: StrokeStyle(lineWidth: 1.3, lineJoin: .miter))
        badge("90°", at: point(pose.elbow.x - 0.01 * h, pose.elbow.y - 0.085 * h), opacity: weight)

        let x = deskFront + 84
        let top = state.deskHeight
        thinLine([CGPoint(x: deskFront + 78, y: top), CGPoint(x: x + 2, y: top)], opacity: weight * 0.7)
        dimension(from: CGPoint(x: x, y: 0), to: CGPoint(x: x, y: top), axis: .vertical, opacity: weight)
        badge(l10n.centimetres(value), at: point(x, top / 2), opacity: weight)
    }

    private func drawMonitorCallouts() {
        let weight = state.monitorCallouts
        guard weight > 0.01 else { return }
        let eye = pose.eye

        thinLine(
            [eye, CGPoint(x: monitorX + 16, y: eye.y)],
            opacity: weight, dash: [4, 3]
        )

        let y = eye.y + 0.085 * h
        dimension(from: CGPoint(x: eye.x, y: y), to: CGPoint(x: monitorX, y: y), axis: .horizontal, opacity: weight)
        let middle = point((eye.x + monitorX) / 2, y)
        badge(l10n.armsLength, at: CGPoint(x: middle.x, y: middle.y - 11), opacity: weight)
    }
}
