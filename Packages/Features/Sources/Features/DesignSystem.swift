import Core
import AppKit
import SwiftUI

enum DesignSystem {
    static let cornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 14
    static let sectionSpacing: CGFloat = 14

    static let panelFill = dynamic(
        light: NSColor.black.withAlphaComponent(0.035),
        dark: NSColor.white.withAlphaComponent(0.075)
    )
    static let rowHoverFill = dynamic(
        light: NSColor.black.withAlphaComponent(0.05),
        dark: NSColor.white.withAlphaComponent(0.11)
    )
    static let rowSelectedFill = dynamic(
        light: NSColor.black.withAlphaComponent(0.075),
        dark: NSColor.white.withAlphaComponent(0.16)
    )
    static let border = dynamic(
        light: NSColor.black.withAlphaComponent(0.08),
        dark: NSColor.white.withAlphaComponent(0.16)
    )
    static let actionTrayFill = dynamic(
        light: NSColor.black.withAlphaComponent(0.03),
        dark: NSColor.white.withAlphaComponent(0.07)
    )
    static let actionButtonFill = dynamic(
        light: NSColor.black.withAlphaComponent(0.045),
        dark: NSColor.white.withAlphaComponent(0.10)
    )
    static let actionButtonHoverFill = dynamic(
        light: NSColor.black.withAlphaComponent(0.08),
        dark: NSColor.white.withAlphaComponent(0.17)
    )

    static let windowBackgroundTop = dynamic(
        light: NSColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1),
        dark: NSColor(red: 0.13, green: 0.14, blue: 0.16, alpha: 1)
    )
    static let windowBackgroundBottom = dynamic(
        light: NSColor(red: 0.91, green: 0.91, blue: 0.91, alpha: 1),
        dark: NSColor(red: 0.09, green: 0.10, blue: 0.12, alpha: 1)
    )
    static let windowGlow = dynamic(
        light: NSColor.white.withAlphaComponent(0.72),
        dark: NSColor.white.withAlphaComponent(0.16)
    )
    static let windowOverlayTop = dynamic(
        light: NSColor.white.withAlphaComponent(0.06),
        dark: NSColor.white.withAlphaComponent(0.03)
    )
    static let windowOverlayBottom = dynamic(
        light: NSColor.black.withAlphaComponent(0.10),
        dark: NSColor.black.withAlphaComponent(0.28)
    )

    static let stepProgressTrack = dynamic(
        light: NSColor.black.withAlphaComponent(0.08),
        dark: NSColor.white.withAlphaComponent(0.14)
    )

    static let chipFill = dynamic(
        light: NSColor.black.withAlphaComponent(0.06),
        dark: NSColor.white.withAlphaComponent(0.08)
    )
    static let chipHoverFill = dynamic(
        light: NSColor.black.withAlphaComponent(0.10),
        dark: NSColor.white.withAlphaComponent(0.16)
    )
    static let chipCloseFill = dynamic(
        light: NSColor.black.withAlphaComponent(0.06),
        dark: NSColor.white.withAlphaComponent(0.14)
    )
    static let chipCloseHoverFill = dynamic(
        light: NSColor.black.withAlphaComponent(0.12),
        dark: NSColor.white.withAlphaComponent(0.22)
    )
    static let chipBorder = dynamic(
        light: NSColor.black.withAlphaComponent(0.08),
        dark: NSColor.white.withAlphaComponent(0.16)
    )

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        let dynamicColor = NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
            case .darkAqua?:
                return dark
            default:
                return light
            }
        }
        return Color(nsColor: dynamicColor)
    }
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
