import SwiftUI
import ElementsCore
import ElementsDesign

/// The ambient composition.
///
/// Five element nodes on a ring anchored to the compass. Turning the wrist
/// moves the ring past the wearer, so the composition belongs to the world
/// rather than to the screen — that is what makes it read as spatial instead
/// of animated.
///
/// Drawn in a single `Canvas` rather than as a stack of shape views: one
/// drawing pass per heading update instead of dozens of view identities being
/// diffed, which matters on a watch receiving updates several times a second.
/// Nothing here runs on a timer; the composition only changes when the data
/// does.
struct ElementFieldView: View {
    let presentation: AlignmentPresentation
    let heading: Double
    let level: AlignmentLevel
    let dominantElement: Element

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let elements = Element.allCases

    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * Layout.orbitRadiusFraction
            let nodeDiameter = min(size.width, size.height) * Layout.nodeDiameterFraction

            let points = Self.elements.enumerated().map { index, _ in
                position(index: index, centre: centre, radius: radius)
            }

            drawLinks(in: &context, points: points)
            drawOrbit(in: &context, centre: centre, radius: radius)

            for (index, element) in Self.elements.enumerated() {
                drawNode(in: &context, at: points[index],
                         diameter: nodeDiameter, element: element)
            }
        }
        .drawingGroup()
        .animation(.elements(Motion.headingFollow, reduceMotion: reduceMotion),
                   value: heading)
        .animation(.elements(Motion.levelTransition, reduceMotion: reduceMotion),
                   value: level)
        .accessibilityHidden(true)
    }

    private func position(index: Int, centre: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = AlignmentPresentation.nodeAngle(
            index: index,
            count: Self.elements.count,
            heading: heading,
            convergence: presentation.convergence)

        // Scatter pushes nodes off the ring when the composition is dispersed.
        // The offset is deterministic per index rather than random, so the
        // composition is stable frame to frame instead of shimmering.
        let scatterPhase = Double(index) * 2.399963  // golden angle, radians
        let scatter = presentation.scatter * Double(radius)
        let radial = Double(radius) + scatter * cos(scatterPhase)
        let tangential = scatter * sin(scatterPhase) * 0.5

        // Screen coordinates: zero degrees is up, angles increase clockwise.
        let radians = Angle.degreesToRadians(angle)
        return CGPoint(
            x: centre.x + CGFloat(radial * sin(radians) + tangential * cos(radians)),
            y: centre.y - CGFloat(radial * cos(radians) - tangential * sin(radians)))
    }

    private func drawOrbit(in context: inout GraphicsContext,
                           centre: CGPoint, radius: CGFloat) {
        let rect = CGRect(x: centre.x - radius, y: centre.y - radius,
                          width: radius * 2, height: radius * 2)
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(Color(Palette.hairline.dark).opacity(0.35 + 0.4 * presentation.convergence)),
            lineWidth: 0.5)
    }

    private func drawLinks(in context: inout GraphicsContext, points: [CGPoint]) {
        guard presentation.linkOpacity > 0.01 else { return }
        // The generating cycle: each element feeds the next. The relationships
        // only become visible as things come together, which is the point.
        var path = Path()
        for (index, point) in points.enumerated() {
            let next = points[(index + 1) % points.count]
            path.move(to: point)
            path.addLine(to: next)
        }
        context.stroke(
            path,
            with: .color(Color(Palette.token(for: level).dark)
                .opacity(presentation.linkOpacity * 0.5)),
            lineWidth: 0.5)
    }

    private func drawNode(in context: inout GraphicsContext, at point: CGPoint,
                          diameter: CGFloat, element: Element) {
        let emphasised = element == dominantElement
        let size = diameter * (emphasised ? 1.45 : 1.0)
        let rect = CGRect(x: point.x - size / 2, y: point.y - size / 2,
                          width: size, height: size)
        let colour = Color(Palette.token(for: element).dark)

        if emphasised {
            // A soft ring rather than a glow: cheaper to draw and quieter.
            let halo = rect.insetBy(dx: -size * 0.35, dy: -size * 0.35)
            context.stroke(Path(ellipseIn: halo),
                           with: .color(colour.opacity(0.25 + 0.35 * presentation.convergence)),
                           lineWidth: 0.5)
        }
        context.fill(Path(ellipseIn: rect),
                     with: .color(colour.opacity(0.55 + 0.45 * presentation.convergence)))
    }
}
