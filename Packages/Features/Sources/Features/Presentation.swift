import Core
import SwiftUI

enum DesignSystem {
    static let cornerRadius: CGFloat = 12
    static let rowCornerRadius: CGFloat = 8
    static let cardPadding: CGFloat = 14

    static let panelFill = Color.primary.opacity(0.06)
    static let rowHoverFill = Color.primary.opacity(0.08)
    static let border = Color.white.opacity(0.08)
}

extension DeploymentStage {
    var label: String {
        switch self {
        case .queued: "Queued"
        case .building: "Building"
        case .ready: "Ready"
        case .failed: "Failed"
        case .canceled: "Canceled"
        case .unknown: "Unknown"
        }
    }

    var tint: Color {
        switch self {
        case .queued:
            Color(red: 0.42, green: 0.55, blue: 0.94)
        case .building:
            Color(red: 0.96, green: 0.65, blue: 0.14)
        case .ready:
            Color(red: 0.20, green: 0.78, blue: 0.48)
        case .failed:
            Color(red: 0.94, green: 0.32, blue: 0.28)
        case .canceled:
            Color(red: 0.56, green: 0.56, blue: 0.58)
        case .unknown:
            Color.secondary
        }
    }

    var iconName: String {
        switch self {
        case .queued: "clock.fill"
        case .building: "hammer.fill"
        case .ready: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .canceled: "minus.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}

extension AggregateStatus {
    var symbolName: String {
        switch self {
        case .healthy: "checkmark.circle.fill"
        case .building: "arrow.triangle.2.circlepath.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .healthy: Color(red: 0.20, green: 0.78, blue: 0.48)
        case .building: Color(red: 0.96, green: 0.65, blue: 0.14)
        case .failed: Color(red: 0.94, green: 0.32, blue: 0.28)
        case .unknown: Color.secondary
        }
    }

    var label: String {
        switch self {
        case .healthy: "Healthy"
        case .building: "Deploying"
        case .failed: "Failure"
        case .unknown: "Waiting"
        }
    }
}

struct FrostedPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DesignSystem.cardPadding)
            .background(.ultraThinMaterial.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius, style: .continuous)
                    .strokeBorder(DesignSystem.border, lineWidth: 0.5)
            )
    }
}

struct AppCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DesignSystem.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.panelFill)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius, style: .continuous)
                    .strokeBorder(DesignSystem.border, lineWidth: 0.5)
            )
    }
}

struct ProjectSelectionRow: View {
    let name: String
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.rowCornerRadius, style: .continuous)
                    .fill(isHovered ? DesignSystem.rowHoverFill : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 16)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ErrorInlineBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct StatusPill: View {
    let stage: DeploymentStage

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: stage.iconName)
                .font(.system(size: 8, weight: .bold))
                .symbolEffect(.pulse, isActive: stage == .building || stage == .queued)
            Text(stage.label)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(stage.tint.opacity(0.12))
        .foregroundStyle(stage.tint)
        .clipShape(Capsule(style: .continuous))
    }
}

struct StatusDot: View {
    let stage: DeploymentStage

    var body: some View {
        Image(systemName: "circle.fill")
            .font(.system(size: 7))
            .foregroundStyle(stage.tint)
            .symbolEffect(.pulse, isActive: stage == .building || stage == .queued)
    }
}

struct SubtleDivider: View {
    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(height: 0.5)
            .padding(.horizontal, 4)
    }
}
