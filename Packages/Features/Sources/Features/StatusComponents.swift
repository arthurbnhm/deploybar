import Core
import SwiftUI

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
        .clipShape(.rect(cornerRadius: 8))
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
