import DiskPulseCore
import SwiftUI

struct SectionCard<Content: View>: View {
    private let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.9)
                .foregroundColor(.secondary)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(valueColor)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }
}

struct GradeBadge: View {
    let grade: HealthGrade
    var compact = false

    var body: some View {
        Text(grade.rawValue)
            .font(.system(size: compact ? 8 : 9, weight: .bold))
            .tracking(0.4)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundColor(HealthPalette.color(for: grade))
            .background(
                Capsule().fill(HealthPalette.color(for: grade).opacity(0.16))
            )
    }
}
