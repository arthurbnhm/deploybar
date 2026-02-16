import Core
import SwiftUI

enum DesignSystem {
    static let cornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 14
    static let sectionSpacing: CGFloat = 14

    static let panelFill = Color.black.opacity(0.035)
    static let rowHoverFill = Color.black.opacity(0.05)
    static let border = Color.black.opacity(0.08)

    static let windowLightTop = Color(red: 0.96, green: 0.96, blue: 0.96)
    static let windowLightBottom = Color(red: 0.91, green: 0.91, blue: 0.91)
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
