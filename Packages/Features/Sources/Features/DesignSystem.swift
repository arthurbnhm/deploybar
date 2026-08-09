import Core
import SwiftUI

/// Layout metrics shared across DeployBar surfaces.
///
/// Colors and fills intentionally come from the system palette
/// (`.quaternary`, `.quinary`, semantic `Color`s) so every surface adapts to
/// appearance, vibrancy, and accessibility settings for free.
enum DesignSystem {
    static let popoverWidth: CGFloat = 380
    static let projectListMaximumHeight: CGFloat = 360
    static let projectRowEstimatedHeight: CGFloat = 54
    static let projectRowSpacing: CGFloat = 4
    static let projectListVerticalPadding: CGFloat = 8
    static let cornerRadius: CGFloat = 10
    static let rowCornerRadius: CGFloat = 8
    static let sectionSpacing: CGFloat = 14
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
        case .queued: .indigo
        case .building: .orange
        case .ready: .green
        case .failed: .red
        case .canceled: .gray
        case .unknown: .secondary
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
        case .healthy: .green
        case .building: .orange
        case .failed: .red
        case .unknown: .gray
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
