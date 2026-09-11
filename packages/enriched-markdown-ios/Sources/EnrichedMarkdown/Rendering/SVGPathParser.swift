import CoreGraphics
import Foundation

/// Minimal SVG path `d` parser producing a CGPath, cut down from the React
/// Native package's ENRMSVGPath to the commands the admonition octicons use
/// (M/L/H/V/C/S/A/Z, absolute and relative). Elliptical arcs become cubic
/// beziers via the endpoint → center parameterization (SVG notes, F.6).
enum SVGPathParser {
    /// Nil for empty input; a malformed command ends parsing and returns
    /// what was built before it.
    static func path(from data: String) -> CGPath? {
        guard !data.isEmpty else { return nil }
        var builder = PathBuilder(data: data)
        builder.run()
        return builder.path
    }
}

private struct PathBuilder {
    let path = CGMutablePath()

    private let scalars: [Unicode.Scalar]
    private var index = 0
    private var current = CGPoint.zero
    private var subpathStart = CGPoint.zero
    private var lastCubicControl = CGPoint.zero
    private var lastCommand: Unicode.Scalar = " "
    private var command: Unicode.Scalar = " "

    init(data: String) {
        scalars = Array(data.unicodeScalars)
    }

    mutating func run() {
        while index < scalars.count {
            skipSeparators()
            guard index < scalars.count else { return }

            let scalar = scalars[index]
            if "MmLlHhVvCcSsAaZz".unicodeScalars.contains(scalar) {
                command = scalar
                index += 1
            } else if command == " " {
                return // data before any command
            } else if command == "M" {
                command = "L" // implicit lineto for repeated moveto pairs
            } else if command == "m" {
                command = "l"
            }

            guard apply(command) else { return }
            lastCommand = command
        }
    }

    /// False when the command's numbers are missing.
    private mutating func apply(_ command: Unicode.Scalar) -> Bool {
        let relative = command.properties.isLowercase
        switch command {
        case "M", "m":
            guard let point = readPoint(relative: relative) else { return false }
            current = point
            subpathStart = point
            path.move(to: point)
        case "L", "l":
            guard let point = readPoint(relative: relative) else { return false }
            addLine(to: point)
        case "H", "h":
            guard let value = readNumber() else { return false }
            addLine(to: CGPoint(x: relative ? current.x + value : value, y: current.y))
        case "V", "v":
            guard let value = readNumber() else { return false }
            addLine(to: CGPoint(x: current.x, y: relative ? current.y + value : value))
        case "C", "c":
            guard let control1 = readPoint(relative: relative),
                  let control2 = readPoint(relative: relative),
                  let end = readPoint(relative: relative) else { return false }
            addCurve(to: end, control1: control1, control2: control2)
        case "S", "s":
            guard let control2 = readPoint(relative: relative),
                  let end = readPoint(relative: relative) else { return false }
            let control1 = "CcSs".unicodeScalars.contains(lastCommand) ? reflected(lastCubicControl) : current
            addCurve(to: end, control1: control1, control2: control2)
        case "A", "a":
            guard let radiusX = readNumber(), let radiusY = readNumber(), let rotation = readNumber(),
                  let largeArc = readNumber(), let sweep = readNumber(),
                  let end = readPoint(relative: relative) else { return false }
            addArc(
                to: end,
                radiusX: radiusX,
                radiusY: radiusY,
                rotationDegrees: rotation,
                largeArc: largeArc != 0,
                sweep: sweep != 0
            )
            current = end
        case "Z", "z":
            path.closeSubpath()
            current = subpathStart
        default:
            return false
        }
        return true
    }

    // MARK: - Segments

    private mutating func addLine(to point: CGPoint) {
        path.addLine(to: point)
        current = point
    }

    private mutating func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {
        path.addCurve(to: end, control1: control1, control2: control2)
        lastCubicControl = control2
        current = end
    }

    /// `S` mirrors the previous control point through the current point.
    private func reflected(_ control: CGPoint) -> CGPoint {
        CGPoint(x: 2 * current.x - control.x, y: 2 * current.y - control.y)
    }

    /// Endpoint → center parameterization, then ≤90° bezier segments.
    private mutating func addArc(
        to end: CGPoint,
        radiusX: Double,
        radiusY: Double,
        rotationDegrees: Double,
        largeArc: Bool,
        sweep: Bool
    ) {
        guard radiusX != 0, radiusY != 0 else {
            path.addLine(to: end)
            return
        }

        var radiusX = abs(radiusX)
        var radiusY = abs(radiusY)
        let rotation = rotationDegrees * .pi / 180
        let cosRotation = cos(rotation)
        let sinRotation = sin(rotation)

        let halfDeltaX = (current.x - end.x) / 2
        let halfDeltaY = (current.y - end.y) / 2
        let primeX = cosRotation * halfDeltaX + sinRotation * halfDeltaY
        let primeY = -sinRotation * halfDeltaX + cosRotation * halfDeltaY

        // Scale up radii too small to span the endpoints.
        let lambda = (primeX * primeX) / (radiusX * radiusX) + (primeY * primeY) / (radiusY * radiusY)
        if lambda > 1 {
            let scale = sqrt(lambda)
            radiusX *= scale
            radiusY *= scale
        }

        let numerator = radiusX * radiusX * radiusY * radiusY
            - radiusX * radiusX * primeY * primeY
            - radiusY * radiusY * primeX * primeX
        let denominator = radiusX * radiusX * primeY * primeY + radiusY * radiusY * primeX * primeX
        var factor = denominator == 0 ? 0 : sqrt(max(0, numerator / denominator))
        if largeArc == sweep {
            factor = -factor
        }

        let centerPrimeX = factor * (radiusX * primeY / radiusY)
        let centerPrimeY = factor * (-radiusY * primeX / radiusX)
        let center = CGPoint(
            x: cosRotation * centerPrimeX - sinRotation * centerPrimeY + (current.x + end.x) / 2,
            y: sinRotation * centerPrimeX + cosRotation * centerPrimeY + (current.y + end.y) / 2
        )

        let startAngle = atan2((primeY - centerPrimeY) / radiusY, (primeX - centerPrimeX) / radiusX)
        let endAngle = atan2((-primeY - centerPrimeY) / radiusY, (-primeX - centerPrimeX) / radiusX)
        var delta = endAngle - startAngle
        if !sweep, delta > 0 {
            delta -= 2 * .pi
        } else if sweep, delta < 0 {
            delta += 2 * .pi
        }

        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let segmentDelta = delta / Double(segments)
        var angle = startAngle
        for _ in 0..<segments {
            addArcSegment(
                center: center,
                radiusX: radiusX,
                radiusY: radiusY,
                rotation: rotation,
                start: angle,
                delta: segmentDelta
            )
            angle += segmentDelta
        }
    }

    /// One arc segment (≤90°) approximated as a single cubic bezier.
    private func addArcSegment(
        center: CGPoint,
        radiusX: Double,
        radiusY: Double,
        rotation: Double,
        start: Double,
        delta: Double
    ) {
        let cosRotation = cos(rotation)
        let sinRotation = sin(rotation)
        let alpha = (4.0 / 3.0) * tan(delta / 4.0)

        let startCos = cos(start)
        let startSin = sin(start)
        let endCos = cos(start + delta)
        let endSin = sin(start + delta)

        let startPoint = CGPoint(
            x: center.x + radiusX * cosRotation * startCos - radiusY * sinRotation * startSin,
            y: center.y + radiusX * sinRotation * startCos + radiusY * cosRotation * startSin
        )
        let endPoint = CGPoint(
            x: center.x + radiusX * cosRotation * endCos - radiusY * sinRotation * endSin,
            y: center.y + radiusX * sinRotation * endCos + radiusY * cosRotation * endSin
        )
        let startTangent = CGPoint(
            x: -radiusX * cosRotation * startSin - radiusY * sinRotation * startCos,
            y: -radiusX * sinRotation * startSin + radiusY * cosRotation * startCos
        )
        let endTangent = CGPoint(
            x: -radiusX * cosRotation * endSin - radiusY * sinRotation * endCos,
            y: -radiusX * sinRotation * endSin + radiusY * cosRotation * endCos
        )

        path.addCurve(
            to: endPoint,
            control1: CGPoint(x: startPoint.x + alpha * startTangent.x, y: startPoint.y + alpha * startTangent.y),
            control2: CGPoint(x: endPoint.x - alpha * endTangent.x, y: endPoint.y - alpha * endTangent.y)
        )
    }

    // MARK: - Scanning

    private mutating func skipSeparators() {
        while index < scalars.count, Self.isSeparator(scalars[index]) {
            index += 1
        }
    }

    private static func isSeparator(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "," || scalar == "\t" || scalar == "\n" || scalar == "\r"
    }

    private mutating func readPoint(relative: Bool) -> CGPoint? {
        guard let first = readNumber(), let second = readNumber() else { return nil }
        return relative
            ? CGPoint(x: current.x + first, y: current.y + second)
            : CGPoint(x: first, y: second)
    }

    /// Numbers may run together ("1 1 0 1 1"); a sign or a dot starts a new
    /// one ("16 0Zm8-6.5"). Nil, with the cursor unmoved, when none follows.
    private mutating func readNumber() -> Double? {
        skipSeparators()
        let start = index
        var seenDigit = false
        var seenDot = false

        if index < scalars.count, scalars[index] == "+" || scalars[index] == "-" {
            index += 1
        }
        while index < scalars.count {
            let scalar = scalars[index]
            if ("0"..."9").contains(scalar) {
                seenDigit = true
            } else if scalar == ".", !seenDot {
                seenDot = true
            } else {
                break
            }
            index += 1
        }

        guard seenDigit else {
            index = start
            return nil
        }
        return Double(String(String.UnicodeScalarView(scalars[start..<index])))
    }
}
