import SwiftUI

struct ThermalChartView: View {
    let samples: [ThermalSample]
    var height: CGFloat = 100
    var compact = false

    private var values: [Double] {
        samples.map(\.temperatureCelsius)
    }

    var body: some View {
        ZStack {
            if values.count < 2 {
                Text("Collecting samples…")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else {
                GeometryReader { geometry in
                    let range = valueRange
                    let points = points(in: geometry.size, range: range)
                    let color = HealthPalette.color(forTemperature: values.last ?? 0)

                    ZStack {
                        grid(in: geometry.size)

                        areaPath(points: points, size: geometry.size)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.25), color.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        linePath(points: points)
                            .stroke(
                                color,
                                style: StrokeStyle(
                                    lineWidth: compact ? 1.5 : 2,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )

                        if let last = points.last {
                            Circle()
                                .fill(color)
                                .frame(width: compact ? 4 : 5, height: compact ? 4 : 5)
                                .position(last)
                        }
                    }
                }
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Temperature history with \(values.count) samples")
    }

    private var valueRange: ClosedRange<Double> {
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 1
        let padding = max(1, (maximum - minimum) * 0.15)
        return (minimum - padding)...(maximum + padding)
    }

    private func points(in size: CGSize, range: ClosedRange<Double>) -> [CGPoint] {
        guard values.count > 1, size.width > 0, size.height > 0 else { return [] }

        let span = max(0.001, range.upperBound - range.lowerBound)

        return values.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
            let normalized = (value - range.lowerBound) / span
            let y = size.height - CGFloat(normalized) * size.height
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func areaPath(points: [CGPoint], size: CGSize) -> Path {
        var path = linePath(points: points)
        guard let first = points.first, let last = points.last else { return path }

        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.addLine(to: CGPoint(x: first.x, y: size.height))
        path.closeSubpath()
        return path
    }

    private func grid(in size: CGSize) -> some View {
        Path { path in
            for fraction in [0.25, 0.5, 0.75] {
                let y = size.height * fraction
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
    }
}
