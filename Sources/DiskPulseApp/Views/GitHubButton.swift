import AppKit
import SwiftUI

struct GitHubMark: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let offsetX = rect.minX + (rect.width - 24.0 * scale) / 2.0
        let offsetY = rect.minY + (rect.height - 24.0 * scale) / 2.0

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
        }

        var path = Path()
        path.move(to: pt(12, 0.297))
        path.addCurve(to: pt(0, 12.297), control1: pt(5.37, 0.297), control2: pt(0, 5.67))
        path.addCurve(to: pt(8.205, 23.682), control1: pt(0, 17.6), control2: pt(3.438, 22.097))
        path.addCurve(to: pt(9.025, 23.105), control1: pt(8.805, 23.795), control2: pt(9.025, 23.424))
        path.addCurve(to: pt(9.01, 21.065), control1: pt(9.025, 22.82), control2: pt(9.015, 22.065))
        path.addCurve(to: pt(4.968, 19.455), control1: pt(5.672, 21.789), control2: pt(4.968, 19.455))
        path.addCurve(to: pt(3.633, 17.7), control1: pt(4.422, 18.07), control2: pt(3.633, 17.7))
        path.addCurve(to: pt(3.717, 16.971), control1: pt(2.546, 16.956), control2: pt(3.717, 16.971))
        path.addCurve(to: pt(5.555, 18.207), control1: pt(4.922, 17.055), control2: pt(5.555, 18.207))
        path.addCurve(to: pt(9.05, 19.205), control1: pt(6.625, 20.042), control2: pt(8.364, 19.512))
        path.addCurve(to: pt(9.81, 17.6), control1: pt(9.158, 18.429), control2: pt(9.467, 17.9))
        path.addCurve(to: pt(4.344, 11.67), control1: pt(7.145, 17.3), control2: pt(4.344, 16.268))
        path.addCurve(to: pt(5.579, 8.45), control1: pt(4.344, 10.36), control2: pt(4.809, 9.29))
        path.addCurve(to: pt(5.684, 5.274), control1: pt(5.444, 8.147), control2: pt(5.039, 6.927))
        path.addCurve(to: pt(8.984, 6.504), control1: pt(5.684, 5.274), control2: pt(6.689, 4.952))
        path.addCurve(to: pt(11.984, 6.099), control1: pt(9.944, 6.237), control2: pt(10.964, 6.105))
        path.addCurve(to: pt(14.984, 6.504), control1: pt(13.004, 6.105), control2: pt(14.024, 6.237))
        path.addCurve(to: pt(18.269, 5.274), control1: pt(17.264, 4.952), control2: pt(18.269, 5.274))
        path.addCurve(to: pt(18.389, 8.45), control1: pt(18.914, 6.927), control2: pt(18.509, 8.147))
        path.addCurve(to: pt(19.619, 11.67), control1: pt(19.154, 9.29), control2: pt(19.619, 10.36))
        path.addCurve(to: pt(14.144, 17.59), control1: pt(19.619, 16.28), control2: pt(16.814, 17.295))
        path.addCurve(to: pt(14.954, 19.81), control1: pt(14.564, 17.95), control2: pt(14.954, 18.686))
        path.addCurve(to: pt(14.939, 23.096), control1: pt(14.954, 21.416), control2: pt(14.939, 22.706))
        path.addCurve(to: pt(15.764, 23.666), control1: pt(14.939, 23.411), control2: pt(15.149, 23.786))
        path.addCurve(to: pt(24, 12.297), control1: pt(20.565, 22.092), control2: pt(24, 17.592))
        path.addCurve(to: pt(12, 0.297), control1: pt(24, 5.67), control2: pt(18.627, 0.297))
        return path
    }
}

struct GitHubButton: View {
    var size: CGFloat = 14

    private static let repositoryURL = URL(string: "https://github.com/andyburhannudien/disk-pulse")!

    var body: some View {
        Button {
            NSWorkspace.shared.open(Self.repositoryURL)
        } label: {
            GitHubMark()
                .fill(Color.primary)
                .frame(width: size, height: size)
                .padding(3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("github.com/andyburhannudien/disk-pulse")
        .accessibilityLabel("Open the DiskPulse repository on GitHub")
    }
}
