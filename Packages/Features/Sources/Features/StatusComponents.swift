import Core
import SwiftUI

extension DeploymentStage {
    var isInFlight: Bool {
        self == .building || self == .queued
    }
}

struct ErrorInlineBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.09), in: .rect(cornerRadius: DesignSystem.rowCornerRadius))
    }
}

struct StatusPill: View {
    let stage: DeploymentStage

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: stage.iconName)
                .font(.system(size: 8, weight: .bold))
                .symbolEffect(.pulse, isActive: stage.isInFlight)

            Text(stage.label)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(stage.tint)
        .background(stage.tint.opacity(0.14), in: .capsule)
    }
}

struct StatusDot: View {
    let stage: DeploymentStage

    var body: some View {
        Image(systemName: "circle.fill")
            .font(.system(size: 7))
            .foregroundStyle(stage.tint)
            .symbolEffect(.pulse, isActive: stage.isInFlight)
    }
}
